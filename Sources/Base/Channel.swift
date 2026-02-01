import NIO

public enum BoundedChannelFullMode: Sendable {
    case wait
    case dropNewest
    case dropOldest
    case dropWrite
}

public struct BoundedChannelOptions: Sendable {
    public let capacity: Int
    public let fullMode: BoundedChannelFullMode

    public init(capacity: Int, fullMode: BoundedChannelFullMode = .wait) {
        precondition(capacity > 0, "capacity must be greater than 0")
        self.capacity = capacity
        self.fullMode = fullMode
    }
}

public struct UnboundedChannelOptions: Sendable {
    public init() {}
}

public enum ChannelClosedError: Error, Sendable {
    case closed
}

public final class Channel<Element: Sendable>: Sendable {
    public let reader: ChannelReader<Element>
    public let writer: ChannelWriter<Element>
    public let completion: Task<Void, Never>

    private let core: ChannelCore<Element>

    private init(core: ChannelCore<Element>) {
        self.core = core
        self.completion = Task { await core.waitForCompletion() }
        self.reader = ChannelReader(core: core, completion: completion)
        self.writer = ChannelWriter(core: core, completion: completion)
    }

    public static func createUnbounded(_ options: UnboundedChannelOptions = UnboundedChannelOptions()) -> Channel<Element> {
        Channel(core: ChannelCore(capacity: nil, fullMode: .wait))
    }

    public static func createBounded(_ options: BoundedChannelOptions) -> Channel<Element> {
        Channel(core: ChannelCore(capacity: options.capacity, fullMode: options.fullMode))
    }
}

public struct ChannelReader<Element: Sendable>: Sendable {
    fileprivate let core: ChannelCore<Element>
    public let completion: Task<Void, Never>

    fileprivate init(core: ChannelCore<Element>, completion: Task<Void, Never>) {
        self.core = core
        self.completion = completion
    }

    public func read() async throws -> Element {
        try await core.read()
    }

    public func tryRead() async -> Element? {
        await core.tryRead()
    }

    public func waitToRead() async throws -> Bool {
        try await core.waitToRead()
    }
}

public struct ChannelWriter<Element: Sendable>: Sendable {
    fileprivate let core: ChannelCore<Element>
    public let completion: Task<Void, Never>

    fileprivate init(core: ChannelCore<Element>, completion: Task<Void, Never>) {
        self.core = core
        self.completion = completion
    }

    public func write(_ element: Element) async throws {
        try await core.write(element)
    }

    public func tryWrite(_ element: Element) async -> Bool {
        await core.tryWrite(element)
    }

    public func waitToWrite() async throws -> Bool {
        try await core.waitToWrite()
    }

    public func complete() async {
        await core.complete()
    }
}

private actor ChannelCore<Element: Sendable> {
    private var buffer = CircularBuffer<Element>()
    private let capacity: Int?
    private let fullMode: BoundedChannelFullMode
    private var isCompleted = false

    private let readReady = ManualResetSignal(initialState: false)
    private let writeReady = ManualResetSignal(initialState: true)
    private let readWait = AutoResetSignal()
    private let writeWait = AutoResetSignal()
    private let completionSignal = ManualResetSignal()

    private var waitingReadersCount = 0
    private var waitingWritersCount = 0

    init(capacity: Int?, fullMode: BoundedChannelFullMode) {
        self.capacity = capacity
        self.fullMode = fullMode
        if let capacity, capacity > 0 {
            buffer.reserveCapacity(capacity)
        }
    }

    func read() async throws -> Element {
        while true {
            try Task.checkCancellation()
            if let element = takeNextElementForReader() {
                return element
            }
            if isCompleted {
                throw ChannelClosedError.closed
            }
            try await waitForRead()
        }
    }

    func tryRead() -> Element? {
        takeNextElementForReader()
    }

    func waitToRead() async throws -> Bool {
        while true {
            try Task.checkCancellation()
            if canReadImmediately() {
                return true
            }
            if isCompleted {
                return false
            }
            try await readReady.wait()
        }
    }

    func write(_ element: Element) async throws {
        while true {
            try Task.checkCancellation()
            if isCompleted {
                throw ChannelClosedError.closed
            }
            if let capacity, buffer.count >= capacity {
                switch fullMode {
                case .wait:
                    try await waitForWrite()
                    continue
                case .dropWrite:
                    updateReadReady()
                    updateWriteReady()
                    return
                case .dropOldest:
                    if !buffer.isEmpty {
                        buffer.removeFirst()
                    }
                case .dropNewest:
                    if !buffer.isEmpty {
                        buffer.removeLast()
                    }
                }
            }

            buffer.append(element)
            updateReadReady()
            updateWriteReady()
            if waitingReadersCount > 0 {
                readWait.set()
            }
            return
        }
    }

    func tryWrite(_ element: Element) -> Bool {
        if isCompleted {
            return false
        }

        if let capacity, buffer.count >= capacity {
            switch fullMode {
            case .wait:
                return false
            case .dropWrite:
                updateReadReady()
                updateWriteReady()
                return true
            case .dropOldest:
                if !buffer.isEmpty {
                    buffer.removeFirst()
                }
            case .dropNewest:
                if !buffer.isEmpty {
                    buffer.removeLast()
                }
            }
        }

        buffer.append(element)
        updateReadReady()
        updateWriteReady()
        if waitingReadersCount > 0 {
            readWait.set()
        }
        return true
    }

    func waitToWrite() async throws -> Bool {
        while true {
            try Task.checkCancellation()
            if isCompleted {
                return false
            }
            if canWriteImmediately() {
                return true
            }
            try await writeReady.wait()
        }
    }

    func complete() {
        if isCompleted {
            return
        }
        isCompleted = true

        let readersToWake = waitingReadersCount
        let writersToWake = waitingWritersCount
        if readersToWake > 0 {
            for _ in 0..<readersToWake {
                readWait.set()
            }
        }
        if writersToWake > 0 {
            for _ in 0..<writersToWake {
                writeWait.set()
            }
        }

        updateReadReady()
        updateWriteReady()
        finishIfPossible()
    }

    func waitForCompletion() async {
        if isCompletionSatisfied() {
            return
        }
        do {
            try await completionSignal.wait()
        } catch {
            // Ignore cancellation: completion is best-effort.
        }
    }

    private func takeNextElementForReader() -> Element? {
        guard !buffer.isEmpty else { return nil }
        let element = buffer.removeFirst()
        updateReadReady()
        updateWriteReady()
        if waitingWritersCount > 0 {
            writeWait.set()
        }
        finishIfPossible()
        return element
    }

    private func waitForRead() async throws {
        waitingReadersCount += 1
        defer {
            waitingReadersCount -= 1
            finishIfPossible()
        }
        try await readWait.wait()
    }

    private func waitForWrite() async throws {
        waitingWritersCount += 1
        defer {
            waitingWritersCount -= 1
            finishIfPossible()
        }
        try await writeWait.wait()
    }

    private func finishIfPossible() {
        guard isCompleted else { return }

        if isCompletionSatisfied() {
            completionSignal.set()
        }
    }

    private func isCompletionSatisfied() -> Bool {
        isCompleted && buffer.isEmpty && waitingReadersCount == 0 && waitingWritersCount == 0
    }

    private func updateReadReady() {
        if isCompleted {
            readReady.set()
            return
        }
        if self.canReadImmediately() {
            readReady.set()
        } else {
            readReady.reset()
        }
    }

    private func updateWriteReady() {
        if isCompleted {
            writeReady.set()
            return
        }
        if self.canWriteImmediately() {
            writeReady.set()
        } else {
            writeReady.reset()
        }
    }

    private func canReadImmediately() -> Bool {
        !buffer.isEmpty
    }

    private func canWriteImmediately() -> Bool {
        if isCompleted {
            return false
        }
        if capacity == nil {
            return true
        }
        if let capacity, buffer.count < capacity {
            return true
        }
        return fullMode != .wait
    }
}
