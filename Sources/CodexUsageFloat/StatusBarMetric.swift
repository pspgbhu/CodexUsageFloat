import AgentUsageCore
import Foundation

enum StatusBarMetric: String, CaseIterable, Identifiable {
    case fiveHourRemaining
    case weeklyRemaining
    case resetTime
    case credits

    var id: String {
        rawValue
    }

    static func available(for snapshot: UsageSnapshot?) -> [StatusBarMetric] {
        guard let snapshot else { return allCases }
        return allCases.filter { metric in
            switch metric {
            case .fiveHourRemaining: return snapshot.visibleQuotaPeriods.contains(.fiveHours)
            case .weeklyRemaining: return snapshot.visibleQuotaPeriods.contains(.week)
            case .resetTime, .credits: return true
            }
        }
    }

    private static func resetDate(from snapshot: UsageSnapshot?) -> Date? {
        guard let snapshot else { return nil }
        return snapshot.visibleQuotaPeriods.compactMap { snapshot.limits?.quotaWindows[$0]?.resetsAt }.first
    }

    var shortLabel: String {
        switch self {
        case .fiveHourRemaining:
            return "5h"
        case .weeklyRemaining:
            return "W"
        case .resetTime:
            return "R"
        case .credits:
            return "C"
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
                Self.resetDate(from: snapshot)
            )
        default:
            return strings.localizedValue(rawFullValue(from: snapshot))
        }
    }

    private func rawFullValue(from snapshot: UsageSnapshot?) -> String {
        switch self {
        case .fiveHourRemaining:
            return UsageFormatting.percent(snapshot?.limits?.quotaWindows[.fiveHours]?.remainingPercent)
        case .weeklyRemaining:
            return UsageFormatting.percent(snapshot?.limits?.quotaWindows[.week]?.remainingPercent)
        case .resetTime:
            return UsageFormatting.adaptiveResetTime(
                Self.resetDate(from: snapshot)
            )
        case .credits:
            return UsageFormatting.credits(snapshot?.credits)
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
