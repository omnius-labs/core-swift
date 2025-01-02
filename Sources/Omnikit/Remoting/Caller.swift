// import Foundation
// import NIO
// import RocketPack
// import Socket

// public class OmniRemotingCaller {
//     private let socket: Socket
//     private let sender: FramedSender
//     private let receiver: FramedReceiver

//     public let functionId: UInt32

//     public init(
//         socket: Socket, functionId: UInt32, maxFrameLength: Int, allocator: ByteBufferAllocator
//     ) {
//         self.socket = socket
//         self.functionId = functionId
//         self.sender = FramedSender(socket: socket, allocator: allocator)
//         self.receiver = FramedReceiver(
//             socket: socket, maxFrameLength: maxFrameLength, allocator: allocator)
//     }

//     public func close() async throws {
//         await self.socket.close()
//         try await self.sender.close()
//         try await self.receiver.close()
//     }

//     public func handshake() async throws {
//         let helloMessage = HelloMessage(version: .v1, functionId: self.functionId)
//         var exportedHelloMessage = try helloMessage.export()
//         try await self.sender.send(&exportedHelloMessage)
//     }
// }
