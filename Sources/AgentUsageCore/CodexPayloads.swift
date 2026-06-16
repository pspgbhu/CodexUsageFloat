import Foundation

public struct GetAccountRateLimitsResponse: Decodable, Equatable {
    public var rateLimits: RateLimitSnapshot
    public var rateLimitsByLimitId: [String: RateLimitSnapshot]?
}

public struct RateLimitSnapshot: Decodable, Equatable {
    public var limitId: String?
    public var limitName: String?
    public var primary: RateLimitWindow?
    public var secondary: RateLimitWindow?
    public var credits: CreditsSnapshot?
    public var individualLimit: SpendControlLimitSnapshot?
    public var planType: String?
    public var rateLimitReachedType: String?
}

public struct CreditsSnapshot: Decodable, Equatable {
    public var hasCredits: Bool
    public var unlimited: Bool
    public var balance: String?
}

public struct RateLimitWindow: Decodable, Equatable {
    public var usedPercent: Int
    public var resetsAt: Int64?
    public var windowDurationMins: Int64?
}

public struct SpendControlLimitSnapshot: Decodable, Equatable {
    public var limit: String
    public var used: String
    public var remainingPercent: Int
    public var resetsAt: Int64
}

public struct GetAccountTokenUsageResponse: Decodable, Equatable {
    public var summary: AccountTokenUsageSummary
    public var dailyUsageBuckets: [AccountTokenUsageDailyBucket]?
}

public struct AccountTokenUsageSummary: Decodable, Equatable {
    public var lifetimeTokens: Int64?
    public var peakDailyTokens: Int64?
    public var longestRunningTurnSec: Int64?
    public var currentStreakDays: Int64?
    public var longestStreakDays: Int64?
}

public struct AccountTokenUsageDailyBucket: Decodable, Equatable {
    public var startDate: String
    public var tokens: Int64
}

public struct GetAccountResponse: Decodable, Equatable {
    public var account: AccountPayload?
    public var requiresOpenaiAuth: Bool
}

public enum AccountPayload: Equatable {
    case apiKey
    case chatgpt(planType: String)
    case amazonBedrock
    case unknown(String)
}

extension AccountPayload: Decodable {
    private enum CodingKeys: String, CodingKey {
        case type
        case planType
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "apiKey":
            self = .apiKey
        case "chatgpt":
            let planType = try container.decodeIfPresent(String.self, forKey: .planType) ?? "unknown"
            self = .chatgpt(planType: planType)
        case "amazonBedrock":
            self = .amazonBedrock
        default:
            self = .unknown(type)
        }
    }
}
