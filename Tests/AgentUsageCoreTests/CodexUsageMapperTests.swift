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
        XCTAssertEqual(snapshot.tokenUsage?.todayTokens, 12_345)
    }

    func testUsesLatestDailyBucketWhenLocalTodayIsMissing() throws {
        let rateLimits = try decodeRateLimits("""
        {
          "rateLimits": {
            "limitId": "codex",
            "credits": {"hasCredits": true, "unlimited": false, "balance": null},
            "primary": {"usedPercent": 3}
          }
        }
        """)
        let usage = try decodeUsage("""
        {
          "summary": {"lifetimeTokens": 1200000, "peakDailyTokens": 45000},
          "dailyUsageBuckets": [
            {"startDate": "2026-06-14", "tokens": 100},
            {"startDate": "2026-06-15", "tokens": 200}
          ]
        }
        """)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let june16 = Date(timeIntervalSince1970: 1_781_577_600)

        let snapshot = CodexUsageMapper.makeSnapshot(
            rateLimits: rateLimits,
            tokenUsage: usage,
            account: GetAccountResponse(account: .chatgpt(planType: "pro"), requiresOpenaiAuth: false),
            provider: provider,
            refreshedAt: june16,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.tokenUsage?.todayTokens, 200)
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

    func testDailyHistoryIncludes30CalendarDaysAcrossDST() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 12))!
        let usage = try decodeUsage("""
        {
          "summary": {},
          "dailyUsageBuckets": [
            {"startDate": "2026-03-16", "tokens": 999},
            {"startDate": "2026-03-14T00:00:00Z", "tokens": 0},
            {"startDate": "2026-02-13", "tokens": 999},
            {"startDate": "2026-02-14", "tokens": 100},
            {"startDate": "2026-03-08", "tokens": 200}
          ]
        }
        """)
        let snapshot = CodexUsageMapper.makeSnapshot(
            rateLimits: try decodeRateLimits("{\"rateLimits\": {}}"),
            tokenUsage: usage,
            account: GetAccountResponse(account: nil, requiresOpenaiAuth: false),
            provider: provider,
            refreshedAt: now,
            calendar: calendar
        )
        let days = try XCTUnwrap(snapshot.tokenUsage?.dailyUsage)
        XCTAssertEqual(days.count, 30)
        XCTAssertEqual(Set(days.map(\.date)).count, 30)
        XCTAssertEqual(days.map(\.date), days.map(\.date).sorted())
        XCTAssertTrue(days.allSatisfy { calendar.component(.hour, from: $0.date) == 0 })
        XCTAssertEqual(days.first?.date, calendar.date(from: DateComponents(year: 2026, month: 2, day: 14)))
        XCTAssertEqual(days.last?.date, calendar.startOfDay(for: now))
        XCTAssertEqual(days.first?.tokens, 100)
        XCTAssertEqual(days[28].tokens, 0)
        XCTAssertNil(days.last?.tokens)
        XCTAssertEqual(days.compactMap(\.tokens).reduce(0, +), 300)
    }

    func testDailyHistoryPreservesUnavailableData() throws {
        for buckets in ["null", "[]"] {
            let usage = try decodeUsage("{\"summary\": {}, \"dailyUsageBuckets\": \(buckets)}")
            let snapshot = CodexUsageMapper.makeSnapshot(
                rateLimits: try decodeRateLimits("{\"rateLimits\": {}}"),
                tokenUsage: usage,
                account: GetAccountResponse(account: nil, requiresOpenaiAuth: false),
                provider: provider
            )
            if buckets == "null" {
                XCTAssertNil(snapshot.tokenUsage?.dailyUsage)
            } else {
                let days = try XCTUnwrap(snapshot.tokenUsage?.dailyUsage)
                XCTAssertEqual(days.count, 30)
                XCTAssertTrue(days.allSatisfy { $0.tokens == nil })
            }
        }
    }

    func testPlusShowsBothQuotaPeriodsRegardlessOfPayloadOrder() throws {
        let snapshot = try quotaSnapshot(plan: "plus", primaryMinutes: 10_080, secondaryMinutes: 300)
        XCTAssertEqual(snapshot.subscription?.displayName, "Plus")
        XCTAssertEqual(snapshot.visibleQuotaPeriods, [.fiveHours, .week])
        XCTAssertEqual(snapshot.limits?.quotaWindows[.week]?.remainingPercent, 80)
        XCTAssertEqual(snapshot.limits?.quotaWindows[.fiveHours]?.remainingPercent, 30)
        XCTAssertEqual(snapshot.limits?.quotaWindows[.week]?.resetsAt, Date(timeIntervalSince1970: 1_800_000_000))
    }

    func testProFamilyShowsOnlyWeeklyQuotaEvenWhenFiveHourWindowExists() throws {
        for plan in ["pro", "prolite"] {
            let snapshot = try quotaSnapshot(plan: plan, primaryMinutes: 10_080, secondaryMinutes: 300)
            XCTAssertEqual(snapshot.subscription?.displayName, "Pro")
            XCTAssertEqual(snapshot.visibleQuotaPeriods, [.week])
            XCTAssertEqual(snapshot.limits?.quotaWindows[.week]?.remainingPercent, 80)
            XCTAssertEqual(snapshot.markingStale("Offline").subscription, snapshot.subscription)
        }
    }

    func testMissingWeeklyQuotaDoesNotReuseFiveHourOrSpendLimit() throws {
        let snapshot = try quotaSnapshot(plan: "plus", primaryMinutes: 300, secondaryMinutes: 60)
        XCTAssertEqual(snapshot.visibleQuotaPeriods, [.fiveHours, .week])
        XCTAssertEqual(snapshot.limits?.quotaWindows[.fiveHours]?.remainingPercent, 80)
        XCTAssertNil(snapshot.limits?.quotaWindows[.week])
    }

    func testSubscriptionFallsBackToRateLimitPlan() throws {
        let snapshot = CodexUsageMapper.makeSnapshot(
            rateLimits: try decodeRateLimits("{\"rateLimits\": {\"planType\": \"prolite\", \"primary\": {\"usedPercent\": 20, \"windowDurationMins\": 10080}}}"),
            tokenUsage: try decodeUsage("{\"summary\": {}}"),
            account: GetAccountResponse(account: .chatgpt(planType: "unknown"), requiresOpenaiAuth: false),
            provider: provider
        )
        XCTAssertEqual(snapshot.subscription?.displayName, "Pro")
        XCTAssertEqual(snapshot.visibleQuotaPeriods, [.week])
    }

    private func quotaSnapshot(plan: String, primaryMinutes: Int, secondaryMinutes: Int) throws -> UsageSnapshot {
        CodexUsageMapper.makeSnapshot(
            rateLimits: try decodeRateLimits("""
            {"rateLimits": {
              "primary": {"usedPercent": 20, "windowDurationMins": \(primaryMinutes), "resetsAt": 1800000000},
              "secondary": {"usedPercent": 70, "windowDurationMins": \(secondaryMinutes), "resetsAt": 1799990000},
              "individualLimit": {"limit": "100", "used": "99", "remainingPercent": 1, "resetsAt": 1800010000}
            }}
            """),
            tokenUsage: try decodeUsage("{\"summary\": {}}"),
            account: GetAccountResponse(account: .chatgpt(planType: plan), requiresOpenaiAuth: false),
            provider: provider
        )
    }

    private func decodeRateLimits(_ json: String) throws -> GetAccountRateLimitsResponse {
        try JSONDecoder().decode(GetAccountRateLimitsResponse.self, from: Data(json.utf8))
    }

    private func decodeUsage(_ json: String) throws -> GetAccountTokenUsageResponse {
        try JSONDecoder().decode(GetAccountTokenUsageResponse.self, from: Data(json.utf8))
    }
}
