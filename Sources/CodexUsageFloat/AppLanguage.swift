import AgentUsageCore
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String {
        rawValue
    }
}

struct AppStrings {
    let language: AppLanguage

    var locale: Locale {
        switch language {
        case .english:
            return Locale(identifier: "en_US")
        case .simplifiedChinese:
            return Locale(identifier: "zh_Hans_CN")
        }
    }

    var appTitle: String {
        "CodexUsageFloat"
    }

    var refresh: String {
        switch language {
        case .english:
            return "Refresh"
        case .simplifiedChinese:
            return "刷新"
        }
    }

    var refreshing: String {
        switch language {
        case .english: return "Refreshing…"
        case .simplifiedChinese: return "正在刷新…"
        }
    }

    var menuBarMetrics: String {
        switch language {
        case .english:
            return "Menu Bar Metrics"
        case .simplifiedChinese:
            return "状态栏指标"
        }
    }

    var iconOnly: String {
        switch language {
        case .english:
            return "Icon only"
        case .simplifiedChinese:
            return "仅显示图标"
        }
    }

    var launchAtLogin: String {
        switch language {
        case .english:
            return "Launch at login"
        case .simplifiedChinese:
            return "登录时启动"
        }
    }

    var floatingWindow: String {
        switch language {
        case .english:
            return "Floating window"
        case .simplifiedChinese:
            return "浮窗展示"
        }
    }

    var credits: String {
        switch language {
        case .english:
            return "Credits"
        case .simplifiedChinese:
            return "余额"
        }
    }

    var subscriptionType: String {
        switch language {
        case .english: return "Subscription"
        case .simplifiedChinese: return "订阅类型"
        }
    }

    func quotaTitle(_ period: UsageQuotaPeriod) -> String {
        metricTitle(period == .fiveHours ? .fiveHourRemaining : .weeklyRemaining)
    }

    var available: String {
        switch language {
        case .english:
            return "Available"
        case .simplifiedChinese:
            return "可用"
        }
    }

    var noCredits: String {
        switch language {
        case .english:
            return "No credits"
        case .simplifiedChinese:
            return "无余额"
        }
    }

    var unlimited: String {
        switch language {
        case .english:
            return "Unlimited"
        case .simplifiedChinese:
            return "无限制"
        }
    }

    var unavailable: String {
        switch language {
        case .english:
            return "Unavailable"
        case .simplifiedChinese:
            return "不可用"
        }
    }

    var limits: String {
        switch language {
        case .english:
            return "Limits"
        case .simplifiedChinese:
            return "额度"
        }
    }

    var spendLimit: String {
        switch language {
        case .english:
            return "Spend limit"
        case .simplifiedChinese:
            return "消费额度上限"
        }
    }

    var spendUsed: String {
        switch language {
        case .english:
            return "Spend used"
        case .simplifiedChinese:
            return "已用消费额度"
        }
    }

    var tokenSectionTitle: String {
        switch language {
        case .english:
            return "Tokens"
        case .simplifiedChinese:
            return "Token"
        }
    }

    var tokenChartHint: String {
        switch language {
        case .english: return "Hover for daily usage"
        case .simplifiedChinese: return "悬停查看每日用量"
        }
    }

    func tokenChartTotal(_ tokens: Int64?) -> String {
        let value = localizedValue(UsageFormatting.tokenCount(tokens))
        switch language {
        case .english: return "30-day total: \(value)"
        case .simplifiedChinese: return "最近30天总计用量：\(value)"
        }
    }

    func tokenChartTotalDetail(_ tokens: Int64?, reportedDays: Int) -> String {
        let value = tokenChartValue(tokens)
        guard tokens != nil, reportedDays < 30 else { return value }
        switch language {
        case .english: return "\(value) · Based on \(reportedDays) days with reported usage"
        case .simplifiedChinese: return "\(value) · 汇总已返回数据的 \(reportedDays) 天"
        }
    }

    var tokenHistoryUnavailable: String {
        switch language {
        case .english: return "Daily usage unavailable"
        case .simplifiedChinese: return "暂无每日用量数据"
        }
    }

    func tokenChartDate(_ date: Date, includeYear: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = includeYear ? "yyyy/M/dd" : "M/dd"
        return formatter.string(from: date)
    }

    func tokenChartValue(_ tokens: Int64?) -> String {
        guard let tokens else { return unavailable }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        return "\(formatter.string(from: NSNumber(value: tokens)) ?? String(tokens)) tokens"
    }

    var today: String {
        switch language {
        case .english:
            return "Today"
        case .simplifiedChinese:
            return "今日"
        }
    }

    var lifetime: String {
        switch language {
        case .english:
            return "Lifetime"
        case .simplifiedChinese:
            return "累计"
        }
    }

    var peakDay: String {
        switch language {
        case .english:
            return "Peak day"
        case .simplifiedChinese:
            return "峰值日"
        }
    }

    var updatedAtPrefix: String {
        switch language {
        case .english:
            return "Updated at"
        case .simplifiedChinese:
            return "更新于"
        }
    }

    var openPanel: String {
        switch language {
        case .english:
            return "Open Panel"
        case .simplifiedChinese:
            return "打开面板"
        }
    }

    var languageMenuTitle: String {
        switch language {
        case .english:
            return "Language"
        case .simplifiedChinese:
            return "语言"
        }
    }

    var quit: String {
        switch language {
        case .english:
            return "Quit"
        case .simplifiedChinese:
            return "退出"
        }
    }

    var tooltipSeparator: String {
        switch language {
        case .english:
            return ": "
        case .simplifiedChinese:
            return "："
        }
    }

    var tooltipItemSeparator: String {
        switch language {
        case .english:
            return ", "
        case .simplifiedChinese:
            return "，"
        }
    }

    func displayName(for appLanguage: AppLanguage) -> String {
        switch appLanguage {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    func metricTitle(_ metric: StatusBarMetric) -> String {
        switch metric {
        case .fiveHourRemaining:
            switch language {
            case .english:
                return "5-hour quota remaining"
            case .simplifiedChinese:
                return "5小时额度余额"
            }
        case .weeklyRemaining:
            switch language {
            case .english:
                return "Weekly quota remaining"
            case .simplifiedChinese:
                return "周额度余额"
            }
        case .resetTime:
            switch language {
            case .english:
                return "Reset time"
            case .simplifiedChinese:
                return "重置时间"
            }
        case .credits:
            switch language {
            case .english:
                return "Credits"
            case .simplifiedChinese:
                return "余额"
            }
        }
    }

    func statusBarMetricSummary(count: Int) -> String {
        if count == 0 {
            return iconOnly
        }

        switch language {
        case .english:
            return "\(count) \(count == 1 ? "item" : "items")"
        case .simplifiedChinese:
            return "\(count) 项"
        }
    }

    func localizedValue(_ value: String) -> String {
        switch value {
        case "Unavailable":
            return unavailable
        case "Unlimited":
            return unlimited
        case "Available":
            return available
        case "No credits":
            return noCredits
        default:
            return value
        }
    }

    func days(_ count: Int64) -> String {
        switch language {
        case .english:
            return "\(count) \(count == 1 ? "day" : "days")"
        case .simplifiedChinese:
            return "\(count) 天"
        }
    }

    func statusTitle(_ status: UsageStatus) -> String {
        switch status {
        case .fresh:
            switch language {
            case .english:
                return "Updated"
            case .simplifiedChinese:
                return "已更新"
            }
        case .stale:
            switch language {
            case .english:
                return "Data may be stale"
            case .simplifiedChinese:
                return "数据可能过期"
            }
        case .authRequired:
            switch language {
            case .english:
                return "Sign-in required"
            case .simplifiedChinese:
                return "需要登录"
            }
        case .agentUnavailable:
            switch language {
            case .english:
                return "Agent unavailable"
            case .simplifiedChinese:
                return "智能体不可用"
            }
        case .rateLimited:
            switch language {
            case .english:
                return "Rate limited"
            case .simplifiedChinese:
                return "已触发限流"
            }
        case .error:
            switch language {
            case .english:
                return "Read failed"
            case .simplifiedChinese:
                return "读取失败"
            }
        }
    }

    func statusMessage(_ status: UsageStatus, fallback: String) -> String {
        switch status {
        case .authRequired:
            return authRequiredMessage
        default:
            return localizedProviderMessage(fallback)
        }
    }

    private var authRequiredMessage: String {
        switch language {
        case .english:
            return "Open the configured agent and sign in again."
        case .simplifiedChinese:
            return "打开已配置的智能体并重新登录。"
        }
    }

    private func localizedProviderMessage(_ message: String) -> String {
        guard language == .simplifiedChinese else {
            return message
        }

        switch message {
        case "Open the configured agent and sign in again.":
            return authRequiredMessage
        case "Failed to start Codex app-server.":
            return "无法启动 Codex app-server。"
        case "Codex app-server is not running.":
            return "Codex app-server 未运行。"
        case "Failed to write to Codex app-server.":
            return "无法写入 Codex app-server。"
        case "JSON-RPC message was not an object.":
            return "JSON-RPC 消息不是对象。"
        case "JSON-RPC response did not include result.":
            return "JSON-RPC 响应缺少 result。"
        case "Agent usage provider returned an error.":
            return "用量 provider 返回错误。"
        case "Usage limit reached.":
            return "已达到使用额度限制。"
        default:
            break
        }

        if let method = extract(message, prefix: "Timed out while reading ", suffix: ".") {
            return "读取 \(method) 超时。"
        }

        if let path = extract(message, prefix: "Codex CLI is not executable at ", suffix: ".") {
            return "Codex CLI 不可执行：\(path)。"
        }

        if let status = extract(message, prefix: "Codex app-server exited with status ", suffix: ".") {
            return "Codex app-server 已退出，状态码 \(status)。"
        }

        if let method = extract(message, prefix: "Could not decode ", suffix: " response.") {
            return "无法解码 \(method) 响应。"
        }

        return message
    }

    private func extract(_ message: String, prefix: String, suffix: String) -> String? {
        guard
            message.hasPrefix(prefix),
            message.hasSuffix(suffix),
            message.count >= prefix.count + suffix.count
        else {
            return nil
        }

        let start = message.index(message.startIndex, offsetBy: prefix.count)
        let end = message.index(message.endIndex, offsetBy: -suffix.count)
        return String(message[start..<end])
    }

    func dateTime(_ date: Date?) -> String {
        guard let date else {
            return unavailable
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func timeWithSeconds(_ date: Date?) -> String {
        guard let date else {
            return unavailable
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    func adaptiveResetTime(
        _ date: Date?,
        now: Date = Date(),
        timeZone: TimeZone = .current,
        includeTimeWithDate: Bool = false
    ) -> String {
        localizedValue(UsageFormatting.adaptiveResetTime(date, now: now, timeZone: timeZone, includeTimeWithDate: includeTimeWithDate))
    }
}
