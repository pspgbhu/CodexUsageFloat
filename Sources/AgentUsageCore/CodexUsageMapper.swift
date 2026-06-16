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
            account: mapAccount(account.account),
            credits: mapCredits(selected.credits),
            limits: mapLimits(selected),
            tokenUsage: mapTokenUsage(tokenUsage, refreshedAt: refreshedAt, calendar: calendar),
            status: status
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
        LimitsInfo(
            limitID: limit.limitId,
            limitName: limit.limitName,
            planType: limit.planType,
            primary: mapWindow(limit.primary),
            secondary: mapWindow(limit.secondary),
            individualLimit: mapSpendControl(limit.individualLimit),
            rateLimitReachedType: limit.rateLimitReachedType
        )
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
            longestStreakDays: response.summary.longestStreakDays
        )
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
