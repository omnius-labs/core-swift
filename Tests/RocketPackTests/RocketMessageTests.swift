import Foundation
import NIO
import Semaphore
import Testing

@testable import RocketPack

@Test
func RocketMessageTest() async throws {
    let data = RocketMessageTestData(text: "test")
    var bytes = try data.export()
    let data2 = try RocketMessageTestData.import(&bytes)
    #expect(data == data2)
}

struct RocketMessageTestData: RocketMessage, Equatable {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public static func pack(_ bytes: inout ByteBuffer, value: RocketMessageTestData, depth: UInt32)
        throws
    {
        RocketMessageWriter.putString(value.text, &bytes)
    }

    public static func unpack(_ bytes: inout ByteBuffer, depth: UInt32) throws
        -> RocketMessageTestData
    {
        let text = try RocketMessageReader.getString(&bytes, 1024)
        return RocketMessageTestData(text: text)
    }
}
