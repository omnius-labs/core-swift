import Foundation
import NIO
import OmniusCoreBase

internal enum YamuxStreamState {
    case open
    case sendClosed
    case recvClosed
    case closed
}

internal enum YamuxPendingFlag {
    case none
    case syn
    case ack
}

public actor YamuxStream: AsyncReadable, AsyncWritable, Sendable {
    public nonisolated let id: UInt32
    internal nonisolated let isOutbound: Bool

    private let connection: YamuxConnection
    private let config: YamuxConfig
    private let allocator: ByteBufferAllocator

    private var sendWindow: UInt32
    private var receiveWindow: UInt32
    private let incomingBytes = IncomingBytes()
    private var state: YamuxStreamState = .open
    private let maxReceiveWindow: UInt32
    private var pendingFlag: YamuxPendingFlag
    private var awaitingRemoteAck: Bool
    private var bufferedBytes: Int64 = 0
    private var connectionClosed = false
    private let sendWindowSignal = ManualResetSignal(initialState: false)

    private init(
        connection: YamuxConnection,
        config: YamuxConfig,
        streamId: UInt32,
        outbound: Bool,
        sendWindow: UInt32,
        receiveWindow: UInt32,
        pendingFlag: YamuxPendingFlag,
        allocator: ByteBufferAllocator
    ) {
        self.connection = connection
        self.config = config
        self.id = streamId
        self.isOutbound = outbound
        self.sendWindow = sendWindow
        self.receiveWindow = receiveWindow
        self.maxReceiveWindow = YamuxConstants.defaultCredit
        self.pendingFlag = pendingFlag
        self.awaitingRemoteAck = outbound
        self.allocator = allocator
    }

    internal static func createInbound(
        _ connection: YamuxConnection,
        config: YamuxConfig,
        streamId: UInt32,
        initialSendWindow: UInt32,
        allocator: ByteBufferAllocator
    ) -> YamuxStream {
        YamuxStream(
            connection: connection,
            config: config,
            streamId: streamId,
            outbound: false,
            sendWindow: initialSendWindow,
            receiveWindow: YamuxConstants.defaultCredit,
            pendingFlag: .ack,
            allocator: allocator
        )
    }

    internal static func createOutbound(
        _ connection: YamuxConnection,
        config: YamuxConfig,
        streamId: UInt32,
        allocator: ByteBufferAllocator
    ) -> YamuxStream {
        YamuxStream(
            connection: connection,
            config: config,
            streamId: streamId,
            outbound: true,
            sendWindow: YamuxConstants.defaultCredit,
            receiveWindow: YamuxConstants.defaultCredit,
            pendingFlag: .syn,
            allocator: allocator
        )
    }

    internal func isPendingAck() -> Bool {
        self.awaitingRemoteAck
    }

    internal func markAcknowledgedByRemote() -> Bool {
        if !self.awaitingRemoteAck { return false }
        self.awaitingRemoteAck = false
        return true
    }

    internal func receiveData(_ data: ByteBuffer, fin: Bool) async throws {
        let dataLength = data.readableBytes
        var closeRead = false
        var notify = false

        if self.state == .closed {
            return
        }

        if UInt32(dataLength) > self.receiveWindow {
            throw YamuxError.protocolError("Stream \(self.id): frame exceeds receive window.")
        }

        self.receiveWindow -= UInt32(dataLength)
        self.bufferedBytes += Int64(dataLength)

        if fin {
            closeRead = true
            notify = self.transitionToRecvClosedLocked()
        }

        if dataLength > 0 {
            let written = await self.incomingBytes.tryWrite(data)
            if !written {
                self.receiveWindow += UInt32(dataLength)
                self.bufferedBytes -= Int64(dataLength)
                if self.bufferedBytes < 0 { self.bufferedBytes = 0 }
            }
        }

        if closeRead {
            await self.incomingBytes.complete()
        }

        if notify {
            await self.connection.notifyStreamClosed(streamId: self.id, stream: self)
        }
    }

    internal func receiveWindowUpdate(_ credit: UInt32, fin: Bool) async throws {
        var notify = false

        let (nextWindow, overflow) = self.sendWindow.addingReportingOverflow(credit)
        if overflow {
            throw YamuxError.protocolError("Stream \(self.id): send window overflow.")
        }
        self.sendWindow = nextWindow

        if fin {
            notify = self.transitionToRecvClosedLocked()
        }

        if self.sendWindow > 0 {
            self.sendWindowSignal.set()
        }

        if notify {
            await self.connection.notifyStreamClosed(streamId: self.id, stream: self)
        }
    }

    internal func receiveReset() async {
        if self.state == .closed { return }
        self.state = .closed

        await self.incomingBytes.completeAndDrain()
        self.sendWindowSignal.set()
        await self.connection.notifyStreamClosed(streamId: self.id, stream: self)
    }

    internal func markConnectionClosed() async {
        self.connectionClosed = true
        self.state = .closed
        if self.config.readAfterClose {
            await self.incomingBytes.complete()
        } else {
            await self.incomingBytes.completeAndDrain()
        }
        self.sendWindowSignal.set()
    }

    public func read(length: Int) async throws -> ByteBuffer {
        if length <= 0 { return ByteBuffer() }

        if !self.config.readAfterClose && self.connectionClosed {
            return ByteBuffer()
        }

        let result = try await self.incomingBytes.read(length: length)
        if result.readableBytes > 0 {
            try await self.onBytesConsumed(result.readableBytes)
        }
        return result
    }

    public func write(buffer: ByteBuffer) async throws {
        if buffer.readableBytes == 0 { return }

        var source = buffer

        while source.readableBytes > 0 {
            if !self.canWriteLocked() || self.connectionClosed {
                throw YamuxError.connectionClosed
            }

            try await self.waitForSendWindow()

            if !self.canWriteLocked() || self.connectionClosed {
                throw YamuxError.connectionClosed
            }

            if self.sendWindow == 0 {
                continue
            }

            let remaining = source.readableBytes
            let windowAllowed = min(self.sendWindow, UInt32(remaining))
            let splitAllowed = min(windowAllowed, UInt32(self.config.splitSendSize))
            let allowed = Int(splitAllowed)
            self.sendWindow -= splitAllowed

            if self.sendWindow == 0 {
                self.sendWindowSignal.reset()
            }

            let flags = self.applyPendingFlagLocked([])
            guard let chunk = source.readSlice(length: allowed) else { continue }
            let frame = try Frame.data(streamId: self.id, body: chunk, flags: flags, allocator: self.allocator)
            try await self.connection.enqueueFrame(frame)
        }
    }

    public func close() async throws {
        if self.state == .closed || self.state == .sendClosed {
            return
        }

        let flags = self.applyPendingFlagLocked([.fin])
        self.state = self.state == .recvClosed ? .closed : .sendClosed
        let notify = self.state == .closed

        let empty = self.allocator.buffer(capacity: 0)
        let frame = try Frame.data(streamId: self.id, body: empty, flags: flags, allocator: self.allocator)
        try await self.connection.enqueueFrame(frame)

        if notify {
            await self.connection.notifyStreamClosed(streamId: self.id, stream: self)
        }
    }

    private func onBytesConsumed(_ bytes: Int) async throws {
        self.bufferedBytes -= Int64(bytes)
        if self.bufferedBytes < 0 { self.bufferedBytes = 0 }

        if !self.canReadLocked() {
            return
        }

        let bytesReceived = Int64(self.maxReceiveWindow) - Int64(self.receiveWindow)
        let pending = bytesReceived - self.bufferedBytes
        if pending < Int64(self.maxReceiveWindow / 2) {
            return
        }

        let credit = UInt32(min(pending, Int64(UInt32.max)))
        self.receiveWindow += credit

        let flags = self.applyPendingFlagLocked([])
        let update = Frame.windowUpdate(streamId: self.id, credit: credit, flags: flags)
        try await self.connection.enqueueFrame(update)
    }

    private func canReadLocked() -> Bool {
        self.state != .recvClosed && self.state != .closed
    }

    private func canWriteLocked() -> Bool {
        self.state != .sendClosed && self.state != .closed
    }

    private func applyPendingFlagLocked(_ flags: FrameFlags) -> FrameFlags {
        switch self.pendingFlag {
        case .syn:
            self.pendingFlag = .none
            return flags.union(.syn)
        case .ack:
            self.pendingFlag = .none
            return flags.union(.ack)
        case .none:
            return flags
        }
    }

    private func transitionToRecvClosedLocked() -> Bool {
        if self.state == .closed { return false }

        self.state = self.state == .sendClosed ? .closed : .recvClosed
        return self.state == .closed
    }

    private func waitForSendWindow() async throws {
        if self.sendWindow > 0 { return }
        try await self.sendWindowSignal.wait()
    }
}
