import Foundation

public final class ManualResetSignal: @unchecked Sendable {
    private let lock = NSLock()
    private var state: Bool
    private var waiters: [UInt64: CheckedContinuation<Void, Error>] = [:]
    private var nextId: UInt64 = 0

    public init(initialState: Bool = false) {
        self.state = initialState
    }

    public func wait() async throws {
        try Task.checkCancellation()

        let id = self.genId()

        try await withTaskCancellationHandler(
            operation: {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    var resumeImmediately: Result<Void, Error>? = nil

                    lock.lock()
                    if state {
                        resumeImmediately = .success(())
                    } else {
                        // Register first, then re-check cancellation while still under the lock.
                        // This avoids a race where cancellation happens "just before" registration.
                        waiters[id] = continuation
                        if Task.isCancelled {
                            waiters.removeValue(forKey: id)
                            resumeImmediately = .failure(CancellationError())
                        }
                    }
                    lock.unlock()

                    // Resume outside the lock.
                    if let result = resumeImmediately {
                        switch result {
                        case .success:
                            continuation.resume(returning: ())
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                }
            },
            onCancel: {
                self.lock.lock()
                let v = self.waiters.removeValue(forKey: id)
                self.lock.unlock()
                v?.resume(throwing: CancellationError())
            })
    }

    private func genId() -> UInt64 {
        self.lock.lock()
        defer { self.lock.unlock() }

        let id = self.nextId
        self.nextId += 1
        return id
    }

    public func set() {
        var continuations: [CheckedContinuation<Void, Error>] = []

        lock.lock()
        if !state {
            state = true
            continuations = Array(waiters.values)
            waiters.removeAll()
        }
        lock.unlock()

        for v in continuations {
            v.resume(returning: ())
        }
    }

    public func reset() {
        lock.lock()
        if state { state = false }
        lock.unlock()
    }
}
