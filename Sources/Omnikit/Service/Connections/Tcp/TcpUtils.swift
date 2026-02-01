import Foundation
import NIO
import OmniusCoreBase

enum TcpUtils {
    public final class AsyncQueue<T: Sendable>: @unchecked Sendable {
        private var buffer = CircularBuffer<T>()
        private let ready = ManualResetSignal()
        private let lock = NSLock()

        func enqueue(_ element: T) {
            self.lock.withLock {
                let wasEmpty = self.buffer.isEmpty
                self.buffer.append(element)
                if wasEmpty { self.ready.set() }
            }
        }

        func dequeue() async throws -> T {
            while true {
                var result: T? = nil
                self.lock.withLock {
                    if !self.buffer.isEmpty {
                        result = self.buffer.removeFirst()
                        if self.buffer.isEmpty { self.ready.reset() }
                    } else {
                        self.ready.reset()
                    }
                }

                if let element = result { return element }
                try await ready.wait()
            }
        }

        func count() -> Int {
            self.lock.withLock {
                self.buffer.count
            }
        }
    }
}
