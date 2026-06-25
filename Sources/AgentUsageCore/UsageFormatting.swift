import Foundation

public enum UsageFormatting {
    public static func tokenCount(_ value: Int64?) -> String {
        guard let value else {
            return "Unavailable"
        }

        let doubleValue = Double(value)
        switch abs(value) {
        case 0..<1_000:
            return "\(value)"
        case 1_000..<1_000_000:
            return compact(doubleValue / 1_000, suffix: "K")
        case 1_000_000..<1_000_000_000:
            return compact(doubleValue / 1_000_000, suffix: "M")
        default:
            return compact(doubleValue / 1_000_000_000, suffix: "B")
        }
    }

    public static func percent(_ value: Int?) -> String {
        guard let value else {
            return "Unavailable"
        }
        return "\(value)%"
    }

    public static func remainingPercent(fromUsedPercent usedPercent: Int?) -> String {
        guard let usedPercent else {
            return "Unavailable"
        }
        return "\(max(0, min(100, 100 - usedPercent)))%"
    }

    public static func credits(_ credits: CreditsInfo?) -> String {
        guard let credits else {
            return "Unavailable"
        }

        if credits.unlimited {
            return "Unlimited"
        }

        if let balance = credits.balance, !balance.isEmpty {
            return balance
        }

        return credits.hasCredits ? "Available" : "No credits"
    }

    public static func dateTime(_ date: Date?) -> String {
        guard let date else {
            return "Unavailable"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    public static func timeWithSeconds(_ date: Date?) -> String {
        guard let date else {
            return "Unavailable"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    public static func adaptiveResetTime(
        _ date: Date?,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> String {
        guard let date else {
            return "Unavailable"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone

        let isWithin24Hours = abs(date.timeIntervalSince(now)) < 24 * 60 * 60
        formatter.dateFormat = isWithin24Hours ? "HH:mm" : "M/dd"
        let formattedTime = formatter.string(from: date)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        if isWithin24Hours, date > now, !calendar.isDate(date, inSameDayAs: now) {
            return "\(formattedTime)(+1)"
        }

        return formattedTime
    }

    private static func compact(_ value: Double, suffix: String) -> String {
        if value >= 10 {
            return String(format: "%.0f%@", value, suffix)
        }
        return String(format: "%.1f%@", value, suffix)
    }
}
