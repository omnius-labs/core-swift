import Foundation
import NIO
import OmniusCoreBase

final class TcpStreamManager: @unchecked Sendable {
    private let lock = NSLock()
    private var tcpStreamMap = Map<ObjectIdentifier, TcpStream>()

    func get(_ channel: NIO.Channel) -> TcpStream {
        let id = ObjectIdentifier(channel)
        return self.lock.withLock {
            if let existing = self.tcpStreamMap.get(key: id) {
                return existing
            }

            let client = TcpStream(channel: channel)
            channel.closeFuture.whenComplete { [weak self] _ in
                self?.removeClient(for: id)
            }
            self.tcpStreamMap.set(key: id, value: client)
            return client
        }
    }

    private func removeClient(for id: ObjectIdentifier) {
        self.lock.withLock({
            self.tcpStreamMap.remove(key: id)
        })
    }
}
