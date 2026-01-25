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
    private struct ReaderWaiter {
        let id: Int
        let continuation: CheckedContinuation<Element, Error>
    }

    private struct WriterWaiter {
        let id: Int
        let element: Element
        let continuation: CheckedContinuation<Void, Error>
    }

    private struct BoolWaiter {
        let id: Int
        let continuation: CheckedContinuation<Bool, Error>
    }

    // TODO CircularBuffer<Element>を使う
    private var buffer: [Element] = []
    private let capacity: Int?
    private let fullMode: BoundedChannelFullMode
    private var isCompleted = false

    private var waitingReaders: [ReaderWaiter] = []
    private var waitingWriters: [WriterWaiter] = []
    private var waitingToRead: [BoolWaiter] = []
    private var waitingToWrite: [BoolWaiter] = []

    private var completionContinuations: [CheckedContinuation<Void, Never>] = []
    private var completionSignaled = false
    private var nextId = 0

    init(capacity: Int?, fullMode: BoundedChannelFullMode) {
        self.capacity = capacity
        self.fullMode = fullMode
        if let capacity, capacity > 0 {
            buffer.reserveCapacity(capacity)
        }
    }

    func read() async throws -> Element {
        try Task.checkCancellation()
        if let element = takeNextElementForReader() {
            return element
        }
        if isCompleted {
            throw ChannelClosedError.closed
        }

        let id = nextWaiterId()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waitingReaders.append(ReaderWaiter(id: id, continuation: continuation))
            }
        } onCancel: {
            Task { await cancelReader(id: id) }
        }
    }

    func tryRead() -> Element? {
        takeNextElementForReader()
    }

    func waitToRead() async throws -> Bool {
        try Task.checkCancellation()
        if canReadImmediately() {
            return true
        }
        if isCompleted {
            return false
        }

        let id = nextWaiterId()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waitingToRead.append(BoolWaiter(id: id, continuation: continuation))
            }
        } onCancel: {
            Task { await cancelWaitToRead(id: id) }
        }
    }

    func write(_ element: Element) async throws {
        try Task.checkCancellation()
        if isCompleted {
            throw ChannelClosedError.closed
        }

        if let reader = popWaitingReader() {
            reader.continuation.resume(returning: element)
            signalReadAvailability()
            return
        }

        if capacity == nil {
            buffer.append(element)
            signalReadAvailability()
            return
        }

        if let capacity, buffer.count < capacity {
            buffer.append(element)
            signalReadAvailability()
            return
        }

        switch fullMode {
        case .wait:
            try await waitForWrite(element)
        case .dropWrite:
            signalReadAvailability()
            return
        case .dropOldest:
            if !buffer.isEmpty {
                buffer.removeFirst()
            }
            buffer.append(element)
            signalReadAvailability()
        case .dropNewest:
            if !buffer.isEmpty {
                buffer.removeLast()
            }
            buffer.append(element)
            signalReadAvailability()
        }
    }

    func tryWrite(_ element: Element) -> Bool {
        if isCompleted {
            return false
        }

        if let reader = popWaitingReader() {
            reader.continuation.resume(returning: element)
            signalReadAvailability()
            return true
        }

        if capacity == nil {
            buffer.append(element)
            signalReadAvailability()
            return true
        }

        if let capacity, buffer.count < capacity {
            buffer.append(element)
            signalReadAvailability()
            return true
        }

        switch fullMode {
        case .wait:
            return false
        case .dropWrite:
            signalReadAvailability()
            return true
        case .dropOldest:
            if !buffer.isEmpty {
                buffer.removeFirst()
            }
            buffer.append(element)
            signalReadAvailability()
            return true
        case .dropNewest:
            if !buffer.isEmpty {
                buffer.removeLast()
            }
            buffer.append(element)
            signalReadAvailability()
            return true
        }
    }

    func waitToWrite() async throws -> Bool {
        try Task.checkCancellation()
        if isCompleted {
            return false
        }
        if canWriteImmediately() {
            return true
        }

        let id = nextWaiterId()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waitingToWrite.append(BoolWaiter(id: id, continuation: continuation))
            }
        } onCancel: {
            Task { await cancelWaitToWrite(id: id) }
        }
    }

    func complete() {
        if isCompleted {
            return
        }
        isCompleted = true

        let writers = waitingWriters
        waitingWriters.removeAll()
        for writer in writers {
            writer.continuation.resume(throwing: ChannelClosedError.closed)
        }

        resumeWaitToWriteAll(false)

        if buffer.isEmpty {
            let readers = waitingReaders
            waitingReaders.removeAll()
            for reader in readers {
                reader.continuation.resume(throwing: ChannelClosedError.closed)
            }
            resumeWaitToReadAll(false)
        } else {
            resumeWaitToReadAll(true)
        }

        finishIfPossible()
    }

    func waitForCompletion() async {
        if isCompletionSatisfied() {
            return
        }
        await withCheckedContinuation { continuation in
            completionContinuations.append(continuation)
        }
    }

    private func waitForWrite(_ element: Element) async throws {
        let id = nextWaiterId()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waitingWriters.append(WriterWaiter(id: id, element: element, continuation: continuation))
            }
        } onCancel: {
            Task { await cancelWriter(id: id) }
        }
    }

    private func takeNextElementForReader() -> Element? {
        if !buffer.isEmpty {
            let element = buffer.removeFirst()
            if let writer = dequeueWriterIfPossible() {
                buffer.append(writer.element)
                writer.continuation.resume()
                signalReadAvailability()
            }
            signalWriteAvailability()
            finishIfPossible()
            return element
        }

        if let writer = popWaitingWriter() {
            writer.continuation.resume()
            signalWriteAvailability()
            finishIfPossible()
            return writer.element
        }

        return nil
    }

    private func dequeueWriterIfPossible() -> WriterWaiter? {
        guard let capacity else { return nil }
        guard buffer.count < capacity else { return nil }
        return popWaitingWriter()
    }

    private func popWaitingReader() -> ReaderWaiter? {
        if waitingReaders.isEmpty {
            return nil
        }
        return waitingReaders.removeFirst()
    }

    private func popWaitingWriter() -> WriterWaiter? {
        if waitingWriters.isEmpty {
            return nil
        }
        return waitingWriters.removeFirst()
    }

    private func canReadImmediately() -> Bool {
        if !buffer.isEmpty {
            return true
        }
        if !waitingWriters.isEmpty {
            return true
        }
        return false
    }

    private func canWriteImmediately() -> Bool {
        if isCompleted {
            return false
        }
        if !waitingReaders.isEmpty {
            return true
        }
        if capacity == nil {
            return true
        }
        if let capacity, buffer.count < capacity {
            return true
        }
        return fullMode != .wait
    }

    private func signalReadAvailability() {
        if waitingToRead.isEmpty {
            return
        }
        if isCompleted && buffer.isEmpty {
            resumeWaitToReadAll(false)
            return
        }
        if !buffer.isEmpty || !waitingWriters.isEmpty {
            resumeWaitToReadAll(true)
        }
    }

    private func signalWriteAvailability() {
        if waitingToWrite.isEmpty {
            return
        }
        if isCompleted {
            resumeWaitToWriteAll(false)
            return
        }
        if canWriteImmediately() {
            resumeWaitToWriteAll(true)
        }
    }

    private func resumeWaitToReadAll(_ value: Bool) {
        let waiters = waitingToRead
        waitingToRead.removeAll()
        for waiter in waiters {
            waiter.continuation.resume(returning: value)
        }
    }

    private func resumeWaitToWriteAll(_ value: Bool) {
        let waiters = waitingToWrite
        waitingToWrite.removeAll()
        for waiter in waiters {
            waiter.continuation.resume(returning: value)
        }
    }

    private func finishIfPossible() {
        guard isCompleted else { return }

        if buffer.isEmpty {
            if !waitingReaders.isEmpty {
                let readers = waitingReaders
                waitingReaders.removeAll()
                for reader in readers {
                    reader.continuation.resume(throwing: ChannelClosedError.closed)
                }
            }
            if !waitingToRead.isEmpty {
                resumeWaitToReadAll(false)
            }
        }

        if isCompletionSatisfied() {
            signalCompletion()
        }
    }

    private func isCompletionSatisfied() -> Bool {
        isCompleted && buffer.isEmpty && waitingReaders.isEmpty && waitingWriters.isEmpty
    }

    private func signalCompletion() {
        if completionSignaled {
            return
        }
        completionSignaled = true
        let continuations = completionContinuations
        completionContinuations.removeAll()
        for continuation in continuations {
            continuation.resume()
        }
    }

    private func nextWaiterId() -> Int {
        nextId += 1
        return nextId
    }

    private func cancelReader(id: Int) {
        guard let index = waitingReaders.firstIndex(where: { $0.id == id }) else { return }
        let waiter = waitingReaders.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }

    private func cancelWriter(id: Int) {
        guard let index = waitingWriters.firstIndex(where: { $0.id == id }) else { return }
        let waiter = waitingWriters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }

    private func cancelWaitToRead(id: Int) {
        guard let index = waitingToRead.firstIndex(where: { $0.id == id }) else { return }
        let waiter = waitingToRead.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }

    private func cancelWaitToWrite(id: Int) {
        guard let index = waitingToWrite.firstIndex(where: { $0.id == id }) else { return }
        let waiter = waitingToWrite.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }
}
