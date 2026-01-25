import Dispatch
import NIO
import Semaphore

enum TcpUtils {
    public final class AsyncQueue<T: Sendable>: @unchecked Sendable {
        private var queue = CircularBuffer<T>()
        private let semaphore = AsyncSemaphore(value: 0)
        private let dispatchQueue = DispatchQueue(label: "OmniusCoreOmnikit.AsyncQueue")

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

    public struct Map<TKey: Hashable & Sendable, TValue: Sendable>: Sendable {
        private var map: [TKey: TValue] = [:]

        func get(key: TKey) -> TValue? {
            return self.map[key]
        }

        mutating func getOrDefault(key: TKey, _ create: () -> TValue) -> TValue {
            if let value = self.map[key] {
                return value
            }
            let value = create()
            self.map[key] = value
            return value
        }

        mutating func set(key: TKey, value: TValue) {
            self.map[key] = value
        }

        mutating func remove(key: TKey) {
            self.map.removeValue(forKey: key)
        }
    }
}
