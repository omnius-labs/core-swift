import Dispatch
import NIO
import Semaphore

final class AsyncQueue<T>: @unchecked Sendable {
    private var queue = CircularBuffer<T>()
    private let semaphore = AsyncSemaphore(value: 0)
    private let dispatchQueue = DispatchQueue(label: "AsyncQueue")

    func enqueue(_ element: T) {
        self.dispatchQueue.sync {
            self.queue.append(element)
            self.semaphore.signal()
        }
    }

    func dequeue() async throws -> T {
        try await self.semaphore.waitUnlessCancelled()

        return self.dispatchQueue.sync {
            return self.queue.removeFirst()
        }
    }

    func peek() async throws -> T {
        try await self.semaphore.waitUnlessCancelled()

        let result = self.dispatchQueue.sync {
            return self.queue.first!
        }

        self.semaphore.signal()

        return result
    }

    func count() -> Int {
        return self.dispatchQueue.sync {
            return self.queue.count
        }
    }
}
