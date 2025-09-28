import Dispatch
import NIO

final class TcpStreamManager: @unchecked Sendable {
    private let dispatchQueue = DispatchQueue(label: "TcpStreamManager")
    private var tcpStreamMap = Map<ObjectIdentifier, TcpStream>()

    func get(_ channel: Channel) -> TcpStream {
        let id = ObjectIdentifier(channel)
        return self.dispatchQueue.sync {
            if let existing = self.tcpStreamMap.get(key: id) {
                return existing
            }

            let client = TcpStream(channel: channel)
            self.tcpStreamMap.set(key: id, value: client)

            channel.closeFuture.whenComplete { [weak self] _ in
                self?.removeClient(for: id)
            }

            return client
        }
    }

    private func removeClient(for id: ObjectIdentifier) {
        self.dispatchQueue.async {
            self.tcpStreamMap.remove(key: id)
        }
    }
}
