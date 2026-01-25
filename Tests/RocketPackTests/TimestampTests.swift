import Foundation
import OmniusCoreBase
import Testing

@testable import OmniusCoreRocketPack

@Test func Timestamp64Test() throws {
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime]
    let date = dateFormatter.date(from: "2000-01-01T00:00:00Z")!

    let ts1 = Timestamp64(seconds: 946_684_800)
    #expect(ts1.seconds == 946_684_800)
    #expect(ts1.toDate() == date)

    let ts2 = Timestamp64(date: date)
    #expect(ts2.seconds == 946_684_800)
    #expect(ts2.toDate() == date)
}

@Test func Timestamp96Test() throws {
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let date = dateFormatter.date(from: "2000-01-01T00:00:00.000000000Z")!

    let ts1 = Timestamp96(seconds: 946_684_800, nanos: 0)
    #expect(ts1.seconds == 946_684_800)
    #expect(ts1.nanos == 0)
    #expect(ts1.toDate() == date)

    let ts2 = Timestamp96(date: date)
    #expect(ts2.seconds == 946_684_800)
    #expect(ts2.nanos == 0)
    #expect(ts2.toDate() == date)
}
