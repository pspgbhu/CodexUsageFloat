import Foundation

public enum CodexUsageMapper {
    public static func selectedRateLimit(from response: GetAccountRateLimitsResponse) -> RateLimitSnapshot {
        response.rateLimitsByLimitId?["codex"] ?? response.rateLimits
    }

    public static func makeSnapshot(
        rateLimits: GetAccountRateLimitsResponse,
        tokenUsage: GetAccountTokenUsageResponse,
        account: GetAccountResponse,
        provider: UsageProviderDescriptor,
        refreshedAt: Date = Date(),
        calendar: Calendar = .current
    ) -> UsageSnapshot {
        let selected = selectedRateLimit(from: rateLimits)
        let mappedAccount = mapAccount(account.account)
        let limits = mapLimits(selected)
        let status: UsageStatus

        if let reachedType = selected.rateLimitReachedType, !reachedType.isEmpty {
            status = .rateLimited(reachedType)
        } else if account.account == nil && account.requiresOpenaiAuth {
            status = .authRequired
        } else {
            status = .fresh
        }

        return UsageSnapshot(
            provider: provider,
            refreshedAt: refreshedAt,
            account: mappedAccount,
            credits: mapCredits(selected.credits),
            limits: limits,
            tokenUsage: mapTokenUsage(tokenUsage, refreshedAt: refreshedAt, calendar: calendar),
            status: status,
            subscription: mapSubscription(account: mappedAccount, limits: limits)
        )
    }

    private static func mapAccount(_ account: AccountPayload?) -> AccountInfo? {
        guard let account else {
            return nil
        }

        switch account {
        case .apiKey:
            return AccountInfo(kind: "apiKey", planType: nil)
        case .chatgpt(let planType):
            return AccountInfo(kind: "chatgpt", planType: planType)
        case .amazonBedrock:
            return AccountInfo(kind: "amazonBedrock", planType: nil)
        case .unknown(let type):
            return AccountInfo(kind: type, planType: nil)
        }
    }

    private static func mapCredits(_ credits: CreditsSnapshot?) -> CreditsInfo? {
        guard let credits else {
            return nil
        }

        return CreditsInfo(
            hasCredits: credits.hasCredits,
            unlimited: credits.unlimited,
            balance: credits.balance
        )
    }

    private static func mapLimits(_ limit: RateLimitSnapshot) -> LimitsInfo {
        var quotaWindows: [UsageQuotaPeriod: LimitWindowInfo] = [:]
        for window in [limit.primary, limit.secondary].compactMap({ $0 }) {
            switch window.windowDurationMins {
            case 300: quotaWindows[.fiveHours] = mapWindow(window)
            case 10_080: quotaWindows[.week] = mapWindow(window)
            default: break
            }
        }
        return LimitsInfo(
            limitID: limit.limitId,
            limitName: limit.limitName,
            planType: limit.planType,
            primary: mapWindow(limit.primary),
            secondary: mapWindow(limit.secondary),
            individualLimit: mapSpendControl(limit.individualLimit),
            rateLimitReachedType: limit.rateLimitReachedType,
            quotaWindows: quotaWindows
        )
    }

    private static func mapSubscription(account: AccountInfo?, limits: LimitsInfo) -> SubscriptionInfo? {
        let accountPlan = account?.planType?.lowercased()
        guard let plan = accountPlan.flatMap({ $0 == "unknown" || $0.isEmpty ? nil : $0 })
            ?? limits.planType?.lowercased(), !plan.isEmpty, plan != "unknown" else { return nil }

        switch plan {
        case "plus":
            return SubscriptionInfo(displayName: "Plus", visibleQuotaPeriods: [.fiveHours, .week])
        case "pro", "prolite":
            return SubscriptionInfo(displayName: "Pro", visibleQuotaPeriods: [.week])
        default:
            return SubscriptionInfo(
                displayName: plan.capitalized,
                visibleQuotaPeriods: UsageQuotaPeriod.allCases.filter { limits.quotaWindows[$0] != nil }
            )
        }
    }

    private static func mapWindow(_ window: RateLimitWindow?) -> LimitWindowInfo? {
        guard let window else {
            return nil
        }

        return LimitWindowInfo(
            usedPercent: window.usedPercent,
            resetsAt: window.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            windowDurationMinutes: window.windowDurationMins
        )
    }

    private static func mapSpendControl(_ limit: SpendControlLimitSnapshot?) -> SpendControlInfo? {
        guard let limit else {
            return nil
        }

        return SpendControlInfo(
            limit: limit.limit,
            used: limit.used,
            remainingPercent: limit.remainingPercent,
            resetsAt: Date(timeIntervalSince1970: TimeInterval(limit.resetsAt))
        )
    }

    private static func mapTokenUsage(
        _ response: GetAccountTokenUsageResponse,
        refreshedAt: Date,
        calendar: Calendar
    ) -> TokenUsageInfo {
        let todayPrefix = dayPrefix(for: refreshedAt, calendar: calendar)
        let todayTokens = response.dailyUsageBuckets?
            .first(where: { $0.startDate.hasPrefix(todayPrefix) })?
            .tokens
            ?? response.dailyUsageBuckets?
            .max { $0.startDate < $1.startDate }?
            .tokens

        return TokenUsageInfo(
            todayTokens: todayTokens,
            lifetimeTokens: response.summary.lifetimeTokens,
            peakDailyTokens: response.summary.peakDailyTokens,
            longestRunningTurnSeconds: response.summary.longestRunningTurnSec,
            currentStreakDays: response.summary.currentStreakDays,
            longestStreakDays: response.summary.longestStreakDays,
            dailyUsage: mapDailyUsage(response.dailyUsageBuckets, refreshedAt: refreshedAt, calendar: calendar)
        )
    }

    private static func mapDailyUsage(
        _ buckets: [AccountTokenUsageDailyBucket]?,
        refreshedAt: Date,
        calendar: Calendar
    ) -> [DailyTokenUsage]? {
        guard let buckets else { return nil }

        // Provider day labels use the Gregorian calendar. Calendar arithmetic
        // preserves local dates across daylight-saving transitions.
        var dayCalendar = Calendar(identifier: .gregorian)
        dayCalendar.timeZone = calendar.timeZone
        let today = dayCalendar.startOfDay(for: refreshedAt)
        return (0..<30).reversed().compactMap { daysAgo in
            guard let date = dayCalendar.date(byAdding: .day, value: -daysAgo, to: today) else {
                return nil
            }
            let prefix = dayPrefix(for: date, calendar: dayCalendar)
            let tokens = buckets.first(where: { $0.startDate.hasPrefix(prefix) })?.tokens
            return DailyTokenUsage(date: date, tokens: tokens)
        }
    }

    private static func dayPrefix(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
