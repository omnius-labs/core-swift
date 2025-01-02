import Dispatch
import NIO

final class TcpClientManager: @unchecked Sendable {
    private let dispatchQueue = DispatchQueue(label: "TcpClientManager")
    private var tcpClientMap = Map<ObjectIdentifier, TcpClient>()

    func get(_ channel: Channel) -> TcpClient {
        let id = ObjectIdentifier(channel)
        return self.dispatchQueue.sync {
            return self.tcpClientMap.getOrDefault(key: id) {
                TcpClient(channel: channel)
            }
        }
    }
}
