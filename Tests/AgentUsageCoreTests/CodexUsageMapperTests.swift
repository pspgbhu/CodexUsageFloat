import XCTest
@testable import AgentUsageCore

final class CodexUsageMapperTests: XCTestCase {
    private let provider = UsageProviderDescriptor(id: "codex", displayName: "Codex")

    func testSelectsCodexBucketOverFallback() throws {
        let rateLimits = try decodeRateLimits("""
        {
          "rateLimits": {
            "limitId": "fallback",
            "limitName": "Fallback",
            "credits": {"hasCredits": false, "unlimited": false, "balance": null},
            "primary": {"usedPercent": 10}
          },
          "rateLimitsByLimitId": {
            "codex": {
              "limitId": "codex",
              "limitName": "Codex",
              "planType": "pro",
              "credits": {"hasCredits": true, "unlimited": false, "balance": "$12.34"},
              "primary": {"usedPercent": 42, "resetsAt": 1781530000, "windowDurationMins": 300}
            }
          }
        }
        """)

        let usage = try decodeUsage("""
        {
          "summary": {"lifetimeTokens": 1200000, "peakDailyTokens": 45000},
          "dailyUsageBuckets": [{"startDate": "2026-06-15", "tokens": 12345}]
        }
        """)
        let account = GetAccountResponse(account: .chatgpt(planType: "pro"), requiresOpenaiAuth: true)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let date = Date(timeIntervalSince1970: 1_781_529_600)
        let snapshot = CodexUsageMapper.makeSnapshot(
            rateLimits: rateLimits,
            tokenUsage: usage,
            account: account,
            provider: provider,
            refreshedAt: date,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.status, .fresh)
        XCTAssertEqual(snapshot.provider, provider)
        XCTAssertEqual(snapshot.credits?.balance, "$12.34")
        XCTAssertEqual(snapshot.credits?.hasCredits, true)
        XCTAssertEqual(snapshot.limits?.limitID, "codex")
        XCTAssertEqual(snapshot.limits?.primary?.usedPercent, 42)
        XCTAssertEqual(snapshot.limits?.primary?.remainingPercent, 58)
        XCTAssertEqual(snapshot.account?.kind, "chatgpt")
        XCTAssertEqual(snapshot.tokenUsage?.lifetimeTokens, 1_200_000)
    }

    func testFallsBackWhenCodexBucketIsMissing() throws {
        let rateLimits = try decodeRateLimits("""
        {
          "rateLimits": {
            "limitId": "fallback",
            "limitName": "Fallback",
            "credits": {"hasCredits": true, "unlimited": true, "balance": null},
            "primary": {"usedPercent": 4}
          },
          "rateLimitsByLimitId": {}
        }
        """)

        XCTAssertEqual(CodexUsageMapper.selectedRateLimit(from: rateLimits).limitId, "fallback")
    }

    func testAuthRequiredWhenAccountIsMissing() throws {
        let rateLimits = try decodeRateLimits("""
        {
          "rateLimits": {
            "limitId": "codex",
            "credits": {"hasCredits": false, "unlimited": false, "balance": null}
          }
        }
        """)
        let usage = try decodeUsage("""
        {"summary": {}, "dailyUsageBuckets": null}
        """)

        let snapshot = CodexUsageMapper.makeSnapshot(
            rateLimits: rateLimits,
            tokenUsage: usage,
            account: GetAccountResponse(account: nil, requiresOpenaiAuth: true),
            provider: provider
        )

        XCTAssertEqual(snapshot.status, .authRequired)
    }

    private func decodeRateLimits(_ json: String) throws -> GetAccountRateLimitsResponse {
        try JSONDecoder().decode(GetAccountRateLimitsResponse.self, from: Data(json.utf8))
    }

    private func decodeUsage(_ json: String) throws -> GetAccountTokenUsageResponse {
        try JSONDecoder().decode(GetAccountTokenUsageResponse.self, from: Data(json.utf8))
    }
}
