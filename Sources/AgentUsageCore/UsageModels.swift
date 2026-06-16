import Foundation

public enum UsageStatus: Equatable {
    case fresh
    case stale(String?)
    case authRequired
    case agentUnavailable(String)
    case rateLimited(String?)
    case error(String)

    public var title: String {
        switch self {
        case .fresh:
            return "Fresh"
        case .stale:
            return "Stale"
        case .authRequired:
            return "Auth required"
        case .agentUnavailable:
            return "Agent unavailable"
        case .rateLimited:
            return "Rate limited"
        case .error:
            return "Error"
        }
    }

    public var message: String? {
        switch self {
        case .fresh:
            return nil
        case .stale(let message):
            return message
        case .authRequired:
            return "Open the configured agent and sign in again."
        case .agentUnavailable(let message):
            return message
        case .rateLimited(let message):
            return message
        case .error(let message):
            return message
        }
    }
}

public struct UsageProviderDescriptor: Equatable {
    public var id: String
    public var displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

public struct UsageSnapshot: Equatable {
    public var provider: UsageProviderDescriptor
    public var refreshedAt: Date
    public var account: AccountInfo?
    public var credits: CreditsInfo?
    public var limits: LimitsInfo?
    public var tokenUsage: TokenUsageInfo?
    public var status: UsageStatus

    public init(
        provider: UsageProviderDescriptor,
        refreshedAt: Date,
        account: AccountInfo?,
        credits: CreditsInfo?,
        limits: LimitsInfo?,
        tokenUsage: TokenUsageInfo?,
        status: UsageStatus
    ) {
        self.provider = provider
        self.refreshedAt = refreshedAt
        self.account = account
        self.credits = credits
        self.limits = limits
        self.tokenUsage = tokenUsage
        self.status = status
    }

    public func markingStale(_ message: String) -> UsageSnapshot {
        UsageSnapshot(
            provider: provider,
            refreshedAt: refreshedAt,
            account: account,
            credits: credits,
            limits: limits,
            tokenUsage: tokenUsage,
            status: .stale(message)
        )
    }
}

public struct AccountInfo: Equatable {
    public var kind: String
    public var planType: String?

    public init(kind: String, planType: String?) {
        self.kind = kind
        self.planType = planType
    }
}

public struct CreditsInfo: Equatable {
    public var hasCredits: Bool
    public var unlimited: Bool
    public var balance: String?

    public init(hasCredits: Bool, unlimited: Bool, balance: String?) {
        self.hasCredits = hasCredits
        self.unlimited = unlimited
        self.balance = balance
    }
}

public struct LimitsInfo: Equatable {
    public var limitID: String?
    public var limitName: String?
    public var planType: String?
    public var primary: LimitWindowInfo?
    public var secondary: LimitWindowInfo?
    public var individualLimit: SpendControlInfo?
    public var rateLimitReachedType: String?

    public init(
        limitID: String?,
        limitName: String?,
        planType: String?,
        primary: LimitWindowInfo?,
        secondary: LimitWindowInfo?,
        individualLimit: SpendControlInfo?,
        rateLimitReachedType: String?
    ) {
        self.limitID = limitID
        self.limitName = limitName
        self.planType = planType
        self.primary = primary
        self.secondary = secondary
        self.individualLimit = individualLimit
        self.rateLimitReachedType = rateLimitReachedType
    }
}

public struct LimitWindowInfo: Equatable {
    public var usedPercent: Int
    public var resetsAt: Date?
    public var windowDurationMinutes: Int64?

    public var remainingPercent: Int {
        max(0, min(100, 100 - usedPercent))
    }

    public init(usedPercent: Int, resetsAt: Date?, windowDurationMinutes: Int64?) {
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
        self.windowDurationMinutes = windowDurationMinutes
    }
}

public struct SpendControlInfo: Equatable {
    public var limit: String
    public var used: String
    public var remainingPercent: Int
    public var resetsAt: Date

    public init(limit: String, used: String, remainingPercent: Int, resetsAt: Date) {
        self.limit = limit
        self.used = used
        self.remainingPercent = remainingPercent
        self.resetsAt = resetsAt
    }
}

public struct TokenUsageInfo: Equatable {
    public var todayTokens: Int64?
    public var lifetimeTokens: Int64?
    public var peakDailyTokens: Int64?
    public var longestRunningTurnSeconds: Int64?
    public var currentStreakDays: Int64?
    public var longestStreakDays: Int64?

    public init(
        todayTokens: Int64?,
        lifetimeTokens: Int64?,
        peakDailyTokens: Int64?,
        longestRunningTurnSeconds: Int64?,
        currentStreakDays: Int64?,
        longestStreakDays: Int64?
    ) {
        self.todayTokens = todayTokens
        self.lifetimeTokens = lifetimeTokens
        self.peakDailyTokens = peakDailyTokens
        self.longestRunningTurnSeconds = longestRunningTurnSeconds
        self.currentStreakDays = currentStreakDays
        self.longestStreakDays = longestStreakDays
    }
}

public protocol UsageProvider {
    var descriptor: UsageProviderDescriptor { get }
    func refresh() async throws -> UsageSnapshot
}
