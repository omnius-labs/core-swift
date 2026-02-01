import Foundation
import NIO
import OmniusCoreBase

public enum YamuxMode: Sendable {
    case client
    case server
}

public actor YamuxConnection: Sendable {
    private let transport: any AsyncReadable & AsyncWritable & Sendable
    private let config: YamuxConfig
    private let allocator: ByteBufferAllocator

    private var nextStreamId: UInt32

    private let outgoing: OmniusCoreBase.Channel<Frame>
    private let inbound: OmniusCoreBase.Channel<YamuxStream>
    private var streams: [UInt32: YamuxStream] = [:]

    private var readTask: Task<Void, Never>? = nil
    private var writeTask: Task<Void, Never>? = nil

    private let connectStreamSignal = ManualResetSignal(initialState: false)
    private var pendingAckCount = 0

    private var closed = false

    public nonisolated let mode: YamuxMode

    public init(
        transport: any AsyncReadable & AsyncWritable & Sendable,
        config: YamuxConfig? = nil,
        mode: YamuxMode,
        allocator: ByteBufferAllocator = .init()
    ) throws {
        self.transport = transport
        self.config = config ?? YamuxConfig()
        try self.config.ensureWindowLimits()
        self.allocator = allocator

        self.mode = mode
        self.nextStreamId = mode == .client ? 1 : 2

        self.outgoing = OmniusCoreBase.Channel<Frame>.createUnbounded()
        self.inbound = OmniusCoreBase.Channel<YamuxStream>.createUnbounded()

        Task { [weak self] in
            await self?.startLoops()
        }
    }

    private func startLoops() {
        if self.readTask != nil || self.writeTask != nil {
            return
        }

        self.readTask = Task { [weak self] in
            guard let self else { return }
            await self.readLoop()
        }

        self.writeTask = Task { [weak self] in
            guard let self else { return }
            await self.writeLoop()
        }
    }

    public var streamCount: Int {
        self.streams.count
    }

    public func acceptStream() async -> YamuxStream? {
        do {
            return try await self.inbound.reader.read()
        } catch ChannelClosedError.closed {
            return nil
        } catch {
            return nil
        }
    }

    public func connectStream() async throws -> YamuxStream {
        while true {
            try Task.checkCancellation()

            if self.closed {
                throw YamuxError.connectionClosed
            }

            if self.streams.count < self.config.maxNumStreams
                && self.pendingAckCount < YamuxConstants.maxAckBacklog
            {
                let id = self.nextStreamId
                if id == 0 || id > UInt32.max - 2 {
                    throw YamuxError.protocolError("No more stream IDs available.")
                }

                self.nextStreamId += 2
                let stream = YamuxStream.createOutbound(self, config: self.config, streamId: id, allocator: self.allocator)
                self.streams[id] = stream
                self.pendingAckCount += 1

                return stream
            }

            self.connectStreamSignal.reset()
            try await self.connectStreamSignal.wait()
        }
    }

    public func close() async {
        if !self.beginClose() { return }

        let goAway = Frame.goAway(code: .normal)
        _ = await self.outgoing.writer.tryWrite(goAway)
        await self.outgoing.writer.complete()

        if let writeTask = self.writeTask {
            _ = await writeTask.value
        }

        self.readTask?.cancel()
        if let readTask = self.readTask {
            _ = await readTask.value
        }

        self.readTask = nil
        self.writeTask = nil

        await self.closeAllStreams()
    }

    internal func enqueueFrame(_ frame: Frame) async throws {
        let wrote = await self.outgoing.writer.tryWrite(frame)
        if !wrote {
            throw YamuxError.connectionClosed
        }
    }

    internal func notifyStreamClosed(streamId: UInt32, stream: YamuxStream) async {
        if self.streams.removeValue(forKey: streamId) != nil {
            if stream.isOutbound {
                let pending = await stream.isPendingAck()
                if pending && self.pendingAckCount > 0 {
                    self.pendingAckCount -= 1
                }
            }

            self.connectStreamSignal.set()
        }
    }

    private func readLoop() async {
        do {
            while !Task.isCancelled && !self.closed {
                guard let frame = try await FrameCodec.read(from: self.transport, allocator: self.allocator) else {
                    break
                }

                try await self.handleFrame(frame)
            }
        } catch is CancellationError {
        } catch let error as YamuxError {
            switch error {
            case .protocolError, .invalidFormat, .frameTooLarge:
                await self.terminate(code: .protocolError)
            default:
                await self.terminate(code: .internalError)
            }
        } catch {
            await self.terminate(code: .internalError)
        }

        self.closed = true
        await self.inbound.writer.complete()
        await self.outgoing.writer.complete()
        await self.closeAllStreams()
    }

    private func writeLoop() async {
        while true {
            do {
                let frame = try await self.outgoing.reader.read()
                try await FrameCodec.write(to: self.transport, frame: frame, allocator: self.allocator)
            } catch is ChannelClosedError {
                break
            } catch is CancellationError {
                break
            } catch {
                break
            }
        }
    }

    private func handleFrame(_ frame: Frame) async throws {
        let header = frame.header

        if header.flags.contains(.ack) && (header.tag == .data || header.tag == .windowUpdate) {
            if let ackStream = self.streams[header.streamId] {
                if await ackStream.markAcknowledgedByRemote() {
                    if self.pendingAckCount > 0 {
                        self.pendingAckCount -= 1
                    }
                    self.connectStreamSignal.set()
                }
            }
        }

        switch header.tag {
        case .data:
            try await self.handleData(frame)
        case .windowUpdate:
            try await self.handleWindowUpdate(frame)
        case .ping:
            await self.handlePing(frame)
        case .goAway:
            _ = self.beginClose()
        }
    }

    private func handleData(_ frame: Frame) async throws {
        let header = frame.header
        let flags = header.flags
        let streamId = header.streamId

        if flags.contains(.rst) {
            if let rstStream = self.streams[streamId] {
                await rstStream.receiveReset()
            }
            return
        }

        let fin = flags.contains(.fin)
        let syn = flags.contains(.syn)

        if syn {
            if !self.isValidRemoteId(streamId, tag: .data) {
                await self.terminate(code: .protocolError)
                return
            }

            if frame.body.readableBytes > Int(YamuxConstants.defaultCredit) {
                await self.terminate(code: .protocolError)
                return
            }

            if self.streams[streamId] != nil {
                throw YamuxError.protocolError("Stream already exists.")
            }

            if self.streams.count >= self.config.maxNumStreams {
                await self.terminate(code: .internalError)
                return
            }

            let stream = YamuxStream.createInbound(
                self,
                config: self.config,
                streamId: streamId,
                initialSendWindow: YamuxConstants.defaultCredit,
                allocator: self.allocator
            )
            self.streams[streamId] = stream

            try await stream.receiveData(frame.body, fin: fin)
            _ = await self.inbound.writer.tryWrite(stream)
            return
        }

        if let target = self.streams[streamId] {
            try await target.receiveData(frame.body, fin: fin)
        }
    }

    private func handleWindowUpdate(_ frame: Frame) async throws {
        let header = frame.header
        let flags = header.flags
        let streamId = header.streamId

        if flags.contains(.rst) {
            if let rstStream = self.streams[streamId] {
                await rstStream.receiveReset()
            }
            return
        }

        let fin = flags.contains(.fin)
        let syn = flags.contains(.syn)

        if syn {
            if !self.isValidRemoteId(streamId, tag: .windowUpdate) {
                await self.terminate(code: .protocolError)
                return
            }

            if self.streams[streamId] != nil {
                throw YamuxError.protocolError("Stream already exists.")
            }

            if self.streams.count >= self.config.maxNumStreams {
                await self.terminate(code: .internalError)
                return
            }

            let (initialSendWindow, overflow) = YamuxConstants.defaultCredit.addingReportingOverflow(header.length)
            if overflow {
                throw YamuxError.protocolError("Stream initial send window overflow.")
            }

            let stream = YamuxStream.createInbound(
                self,
                config: self.config,
                streamId: streamId,
                initialSendWindow: initialSendWindow,
                allocator: self.allocator
            )
            self.streams[streamId] = stream

            if fin {
                try await stream.receiveWindowUpdate(0, fin: fin)
            }

            _ = await self.inbound.writer.tryWrite(stream)
            return
        }

        if let target = self.streams[streamId] {
            try await target.receiveWindowUpdate(header.length, fin: fin)
        }
    }

    private func handlePing(_ frame: Frame) async {
        let header = frame.header
        if header.flags.contains(.ack) { return }

        let pong = Frame.ping(nonce: header.length, flags: [.ack])
        _ = await self.outgoing.writer.tryWrite(pong)
    }

    private func terminate(code: GoAwayCode) async {
        if self.beginClose() {
            let goAway = Frame.goAway(code: code)
            _ = await self.outgoing.writer.tryWrite(goAway)
            await self.outgoing.writer.complete()
            self.readTask?.cancel()
        }
    }

    private func isValidRemoteId(_ streamId: UInt32, tag: FrameTag) -> Bool {
        if tag == .ping || tag == .goAway {
            return streamId == 0
        }

        return self.mode == .client ? streamId % 2 == 0 : streamId % 2 == 1
    }

    private func beginClose() -> Bool {
        if self.closed { return false }
        self.closed = true
        self.connectStreamSignal.set()
        return true
    }

    private func closeAllStreams() async {
        let current = Array(self.streams.values)
        self.streams.removeAll()
        self.pendingAckCount = 0

        for stream in current {
            await stream.markConnectionClosed()
        }
    }
}
