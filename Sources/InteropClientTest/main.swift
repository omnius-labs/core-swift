import ArgumentParser
import Base
import Foundation
import NIO
import Omnikit

@main
struct InteropClientTest: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "interop-client-test",
        abstract: "OmniusCore の接続系テストをまとめた CLI ツール",
        subcommands: [SecureEcho.self],
        defaultSubcommand: SecureEcho.self
    )
}

/// リモートの Secure 接続を使った往復検証
struct SecureEcho: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "secure-echo",
        abstract: "指定ホストへ接続し、16進ペイロードを送信して応答を検証します")

    @Option(name: [.customShort("H"), .long], help: "接続先ホスト")
    var host: String = "127.0.0.1"

    @Option(name: [.customShort("p"), .long], help: "接続先ポート")
    var port: Int

    @Option(name: .customLong("send-hex"), help: "送信する16進文字列 (空白なし)")
    var sendHex: String

    @Option(name: .customLong("expect-hex"), help: "期待する16進応答 (空白なし)")
    var expectHex: String

    @Option(name: .customLong("max-frame"), help: "フレーム最大長 (バイト)")
    var maxFrameLength: Int = 1024 * 64

    @Flag(name: .shortAndLong, help: "詳細ログを出力")
    var verbose: Bool = false

    func validate() throws {
        try Hex.requireEvenLength(sendHex, label: "--send-hex")
        try Hex.requireEvenLength(expectHex, label: "--expect-hex")
        guard port > 0 else { throw ValidationError("--port は正の数で指定してください") }
        guard maxFrameLength > 0 else { throw ValidationError("--max-frame は正の数で指定してください") }
    }

    mutating func run() async throws {
        let sendBytes = try Hex.bytes(from: sendHex)
        let expectBytes = try Hex.bytes(from: expectHex)
        let allocator = ByteBufferAllocator()

        let connector = TcpConnector()
        let tcpStream = try await connector.connect(host: host, port: port)

        let secure = try await OmniSecureStream(
            type: .connected,
            stream: tcpStream,
            signer: nil,
            randomBytesProvider: RandomBytesProviderImpl(),
            clock: SystemClock(),
            allocator: allocator,
            maxFrameLength: maxFrameLength
        )

        let sender = FramedSender(
            secure,
            maxFrameLength: maxFrameLength,
            allocator: allocator
        )
        let receiver = FramedReceiver(
            secure,
            maxFrameLength: maxFrameLength,
            allocator: allocator
        )

        var sendBuffer = allocator.buffer(capacity: sendBytes.count)
        sendBuffer.writeBytes(sendBytes)
        try await sender.send(sendBuffer)

        let received = try await receiver.receive()
        let receivedBytes = Array(received.readableBytesView)

        guard receivedBytes == expectBytes else {
            throw RuntimeError("unexpected response (got: \(Hex.string(from: receivedBytes)))")
        }

        if verbose {
            let sign = await secure.sign ?? "-"
            print("sign: \(sign)")
        }
        print("ok")
    }
}

private enum Hex {
    static func requireEvenLength(_ text: String, label: String) throws {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).count % 2 != 0 {
            throw ValidationError("\(label) は偶数長の16進文字列で指定してください")
        }
    }

    static func bytes(from text: String) throws -> [UInt8] {
        let stripped = text.trimmingCharacters(in: .whitespacesAndNewlines)
        try requireEvenLength(stripped, label: "value")
        var bytes: [UInt8] = []
        var index = stripped.startIndex
        while index < stripped.endIndex {
            let next = stripped.index(index, offsetBy: 2)
            let chunk = stripped[index..<next]
            guard let value = UInt8(chunk, radix: 16) else {
                throw ValidationError("invalid hex: \(chunk)")
            }
            bytes.append(value)
            index = next
        }
        return bytes
    }

    static func string(from bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}

private enum RandomBytes {
    static func generate(count: Int) -> [UInt8] {
        (0..<count).map { _ in UInt8.random(in: UInt8.min...UInt8.max) }
    }
}

private struct RuntimeError: Error, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { message }
}
