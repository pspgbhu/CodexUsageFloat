import AgentUsageCore
import Foundation

enum StatusBarMetric: String, CaseIterable, Identifiable {
    case primaryRemaining
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

    var shortLabel: String {
        switch self {
        case .primaryRemaining:
            return "P"
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

    func tooltipComponent(from snapshot: UsageSnapshot?, language: AppLanguage) -> String {
        let strings = AppStrings(language: language)
        return "\(strings.metricTitle(self))\(strings.tooltipSeparator)\(fullValue(from: snapshot, language: language))"
    }

    func fullValue(from snapshot: UsageSnapshot?, language: AppLanguage) -> String {
        let strings = AppStrings(language: language)
        switch self {
        case .resetTime:
            return strings.adaptiveResetTime(
                snapshot?.limits?.individualLimit?.resetsAt
                    ?? snapshot?.limits?.primary?.resetsAt
            )
        case .currentStreakDays:
            guard let days = snapshot?.tokenUsage?.currentStreakDays else {
                return strings.unavailable
            }
            return strings.days(days)
        default:
            return strings.localizedValue(rawFullValue(from: snapshot))
        }
    }

    private func rawFullValue(from snapshot: UsageSnapshot?) -> String {
        switch self {
        case .primaryRemaining:
            return UsageFormatting.percent(snapshot?.limits?.primary?.remainingPercent)
        case .spendRemaining:
            return UsageFormatting.percent(snapshot?.limits?.individualLimit?.remainingPercent)
        case .resetTime:
            return UsageFormatting.adaptiveResetTime(
                snapshot?.limits?.individualLimit?.resetsAt
                    ?? snapshot?.limits?.primary?.resetsAt
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
        let value = rawFullValue(from: snapshot)
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
