import XCTest
@testable import AgentUsageCore

final class FormattingAndJSONRPCTests: XCTestCase {
    func testTokenFormatting() {
        XCTAssertEqual(UsageFormatting.tokenCount(nil), "Unavailable")
        XCTAssertEqual(UsageFormatting.tokenCount(999), "999")
        XCTAssertEqual(UsageFormatting.tokenCount(12_300), "12K")
        XCTAssertEqual(UsageFormatting.tokenCount(1_250_000), "1.2M")
    }

    func testCreditFormatting() {
        XCTAssertEqual(UsageFormatting.credits(nil), "Unavailable")
        XCTAssertEqual(UsageFormatting.credits(CreditsInfo(hasCredits: true, unlimited: true, balance: nil)), "Unlimited")
        XCTAssertEqual(UsageFormatting.credits(CreditsInfo(hasCredits: true, unlimited: false, balance: "$4.20")), "$4.20")
        XCTAssertEqual(UsageFormatting.credits(CreditsInfo(hasCredits: false, unlimited: false, balance: nil)), "No credits")
    }

    func testRemainingPercentFormatting() {
        XCTAssertEqual(UsageFormatting.remainingPercent(fromUsedPercent: nil), "Unavailable")
        XCTAssertEqual(UsageFormatting.remainingPercent(fromUsedPercent: 0), "100%")
        XCTAssertEqual(UsageFormatting.remainingPercent(fromUsedPercent: 42), "58%")
        XCTAssertEqual(UsageFormatting.remainingPercent(fromUsedPercent: 120), "0%")
    }

    func testAdaptiveResetTimeUsesTimeWithin24Hours() {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_781_510_400)
        let reset = Date(timeIntervalSince1970: 1_781_535_600)

        XCTAssertEqual(UsageFormatting.adaptiveResetTime(reset, now: now, timeZone: timeZone), "15:00")
    }

    func testAdaptiveResetTimeMarksTomorrowWithin24Hours() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 23, minute: 30))!
        let reset = calendar.date(from: DateComponents(year: 2026, month: 6, day: 16, hour: 1, minute: 15))!

        XCTAssertEqual(UsageFormatting.adaptiveResetTime(reset, now: now, timeZone: calendar.timeZone), "01:15(+1)")
    }

    func testAdaptiveResetTimeUsesMonthAndDayAfter24Hours() {
        let timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_781_510_400)
        let reset = Date(timeIntervalSince1970: 1_781_683_200)

        XCTAssertEqual(UsageFormatting.adaptiveResetTime(reset, now: now, timeZone: timeZone), "6/17")
    }

    func testAdaptiveResetTimePadsDayOnlyAfter24Hours() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 4, hour: 8))!
        let reset = calendar.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 8))!

        XCTAssertEqual(UsageFormatting.adaptiveResetTime(reset, now: now, timeZone: calendar.timeZone), "3/06")
    }

    func testJSONRPCResultParsing() throws {
        let response = try JSONRPCResponseParser.parseResultLine(Data("""
        {"id": 2, "result": {"ok": true}}
        """.utf8))

        XCTAssertEqual(response?.id, 2)
        let object = try JSONSerialization.jsonObject(with: response!.payload) as? [String: Bool]
        XCTAssertEqual(object?["ok"], true)
    }

    func testJSONRPCNotificationIsIgnored() throws {
        let response = try JSONRPCResponseParser.parseResultLine(Data("""
        {"method": "account/rateLimits/updated", "params": {}}
        """.utf8))

        XCTAssertNil(response)
    }

    func testJSONRPCErrorParsing() {
        XCTAssertThrowsError(try JSONRPCResponseParser.parseResultLine(Data("""
        {"id": 3, "error": {"code": -32000, "message": "failed"}}
        """.utf8))) { error in
            XCTAssertEqual(error as? UsageProviderError, .rpc(code: -32000, message: "failed"))
        }
    }
}
