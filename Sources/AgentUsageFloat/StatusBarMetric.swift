import AgentUsageCore
import Foundation

enum StatusBarMetric: String, CaseIterable, Identifiable {
    case primaryRemaining
    case secondaryRemaining
    case spendRemaining
    case resetTime
    case credits
    case todayTokens
    case lifetimeTokens
    case peakDailyTokens
    case currentStreakDays

    var id: String {
        rawValue
    }

    var panelTitle: String {
        switch self {
        case .primaryRemaining:
            return "主额度剩余"
        case .secondaryRemaining:
            return "次额度剩余"
        case .spendRemaining:
            return "消费额度剩余"
        case .resetTime:
            return "重置时间"
        case .credits:
            return "余额"
        case .todayTokens:
            return "今日 Token"
        case .lifetimeTokens:
            return "累计 Token"
        case .peakDailyTokens:
            return "峰值日 Token"
        case .currentStreakDays:
            return "连续天数"
        }
    }

    var shortLabel: String {
        switch self {
        case .primaryRemaining:
            return "P"
        case .secondaryRemaining:
            return "S"
        case .spendRemaining:
            return "Spend"
        case .resetTime:
            return "R"
        case .credits:
            return "C"
        case .todayTokens:
            return "T"
        case .lifetimeTokens:
            return "L"
        case .peakDailyTokens:
            return "Pk"
        case .currentStreakDays:
            return "Stk"
        }
    }

    func menuBarComponent(from snapshot: UsageSnapshot?) -> String {
        "\(shortLabel) \(compactValue(from: snapshot))"
    }

    func tooltipComponent(from snapshot: UsageSnapshot?) -> String {
        "\(panelTitle)：\(fullValue(from: snapshot))"
    }

    func fullValue(from snapshot: UsageSnapshot?) -> String {
        switch self {
        case .primaryRemaining:
            return UsageFormatting.percent(snapshot?.limits?.primary?.remainingPercent)
        case .secondaryRemaining:
            return UsageFormatting.percent(snapshot?.limits?.secondary?.remainingPercent)
        case .spendRemaining:
            return UsageFormatting.percent(snapshot?.limits?.individualLimit?.remainingPercent)
        case .resetTime:
            return UsageFormatting.dateTime(
                snapshot?.limits?.individualLimit?.resetsAt
                    ?? snapshot?.limits?.primary?.resetsAt
                    ?? snapshot?.limits?.secondary?.resetsAt
            )
        case .credits:
            return UsageFormatting.credits(snapshot?.credits)
        case .todayTokens:
            return UsageFormatting.tokenCount(snapshot?.tokenUsage?.todayTokens)
        case .lifetimeTokens:
            return UsageFormatting.tokenCount(snapshot?.tokenUsage?.lifetimeTokens)
        case .peakDailyTokens:
            return UsageFormatting.tokenCount(snapshot?.tokenUsage?.peakDailyTokens)
        case .currentStreakDays:
            guard let days = snapshot?.tokenUsage?.currentStreakDays else {
                return "Unavailable"
            }
            return "\(days)d"
        }
    }

    private func compactValue(from snapshot: UsageSnapshot?) -> String {
        let value = fullValue(from: snapshot)
        switch value {
        case "Unavailable":
            return "--"
        case "Unlimited":
            return "Unlim"
        case "Available":
            return "OK"
        case "No credits":
            return "No"
        default:
            return value
        }
    }
}
