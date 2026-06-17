import AgentUsageCore
import AppKit
import SwiftUI

struct UsagePanelView: View {
    @ObservedObject var viewModel: UsageViewModel
    @ObservedObject var settings: AppSettings

    var onRefresh: () -> Void
    var onSetLaunchAtLogin: (Bool) -> Void
    var onSetStatusBarMetric: (StatusBarMetric, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let snapshot = viewModel.snapshot {
                statusRow(snapshot.status)
                creditsSection(snapshot)
                limitsSection(snapshot.limits)
                tokenSection(snapshot.tokenUsage)
                Divider()
                settingsSection
                footer(snapshot.refreshedAt)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
                Divider()
                settingsSection
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .frame(width: 340)
        .frame(minHeight: 492, alignment: .topLeading)
        .background(MenuMaterialBackground())
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 0.5)
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: 18, weight: .semibold))
            Text("智能体用量")
                .font(.headline)
            Spacer()
            iconButton(
                systemName: viewModel.isRefreshing ? "arrow.clockwise.circle.fill" : "arrow.clockwise",
                action: onRefresh,
                help: "刷新"
            )
        }
    }

    private var settingsSection: some View {
        VStack(spacing: 8) {
            actionRow
            HStack(spacing: 12) {
                settingsRowLabel("状态栏指标", systemName: "menubar.rectangle")
                Spacer()
                Menu(statusBarMetricSummary) {
                    Button("仅显示图标") {
                        for metric in StatusBarMetric.allCases {
                            onSetStatusBarMetric(metric, false)
                        }
                    }
                    Divider()

                    ForEach(StatusBarMetric.allCases) { metric in
                        Toggle(metric.panelTitle, isOn: Binding(
                            get: { settings.isStatusBarMetricEnabled(metric) },
                            set: { onSetStatusBarMetric(metric, $0) }
                        ))
                    }
                }
                .menuStyle(.borderlessButton)
            }
        }
        .font(.subheadline)
    }

    private var statusBarMetricSummary: String {
        let count = settings.selectedStatusBarMetrics.count
        return count == 0 ? "仅图标" : "\(count) 项"
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            settingsRowLabel("登录时启动", systemName: "power")
            Spacer()
            NativeSwitch(isOn: Binding(
                get: { settings.launchAtLoginEnabled },
                set: { onSetLaunchAtLogin($0) }
            ))
            .frame(width: 44, height: 24)
        }
    }

    private func settingsRowLabel(_ title: String, systemName: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemName)
                .frame(width: 20, alignment: .center)
            Text(title)
        }
    }

    private func statusRow(_ status: UsageStatus) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 8, height: 8)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(localizedStatusTitle(status))
                    .font(.subheadline.weight(.semibold))
                if let message = status.message {
                    Text(localizedStatusMessage(status, fallback: message))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
    }

    private func creditsSection(_ snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            labelValue("余额", localizedValue(UsageFormatting.credits(snapshot.credits)), prominent: true)

            if let credits = snapshot.credits {
                HStack(spacing: 10) {
                    chip(credits.hasCredits ? "可用" : "无余额")
                    if credits.unlimited {
                        chip("无限制")
                    }
                    if let plan = snapshot.account?.planType ?? snapshot.limits?.planType {
                        chip(plan)
                    }
                }
            }
        }
    }

    private func limitsSection(_ limits: LimitsInfo?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("额度")
            labelValue("额度桶", localizedValue(limits?.limitName ?? limits?.limitID ?? "Unavailable"))
            labelValue("主额度剩余", localizedValue(UsageFormatting.percent(limits?.primary?.remainingPercent)), prominent: true)
            labelValue("次额度剩余", localizedValue(UsageFormatting.percent(limits?.secondary?.remainingPercent)))

            if let individual = limits?.individualLimit {
                Divider()
                labelValue("消费额度剩余", "\(individual.remainingPercent)%", prominent: true)
                labelValue("消费额度上限", individual.limit)
                labelValue("已用消费额度", individual.used)
                labelValue("重置时间", UsageFormatting.dateTime(individual.resetsAt))
                labelValue("次额度重置时间", localizedValue(UsageFormatting.adaptiveResetTime(limits?.secondary?.resetsAt)))
            } else if let reset = limits?.primary?.resetsAt {
                labelValue("重置时间", UsageFormatting.dateTime(reset))
                labelValue("次额度重置时间", localizedValue(UsageFormatting.adaptiveResetTime(limits?.secondary?.resetsAt)))
            } else {
                labelValue("次额度重置时间", localizedValue(UsageFormatting.adaptiveResetTime(limits?.secondary?.resetsAt)))
            }
        }
    }

    private func tokenSection(_ tokenUsage: TokenUsageInfo?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Token")
            labelValue("今日", localizedValue(UsageFormatting.tokenCount(tokenUsage?.todayTokens)), prominent: true)
            labelValue("累计", localizedValue(UsageFormatting.tokenCount(tokenUsage?.lifetimeTokens)))
            labelValue("峰值日", localizedValue(UsageFormatting.tokenCount(tokenUsage?.peakDailyTokens)))

            if let streak = tokenUsage?.currentStreakDays {
                labelValue("连续天数", "\(streak) 天")
            }
        }
    }

    private func footer(_ refreshedAt: Date) -> some View {
        HStack {
            Text("更新于 \(UsageFormatting.timeWithSeconds(refreshedAt))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(Int(settings.refreshIntervalSeconds))s")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func labelValue(_ label: String, _ value: String, prominent: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .font(.subheadline)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.08), in: Capsule())
    }

    private func iconButton(systemName: String, action: @escaping () -> Void, help: String) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    private func statusColor(_ status: UsageStatus) -> Color {
        switch status {
        case .fresh:
            return .green
        case .stale:
            return .yellow
        case .authRequired, .agentUnavailable, .error:
            return .red
        case .rateLimited:
            return .orange
        }
    }

    private func localizedValue(_ value: String) -> String {
        switch value {
        case "Unavailable":
            return "不可用"
        case "Unlimited":
            return "无限制"
        case "Available":
            return "可用"
        case "No credits":
            return "无余额"
        default:
            return value
        }
    }

    private func localizedStatusTitle(_ status: UsageStatus) -> String {
        switch status {
        case .fresh:
            return "已更新"
        case .stale:
            return "数据可能过期"
        case .authRequired:
            return "需要登录"
        case .agentUnavailable:
            return "智能体不可用"
        case .rateLimited:
            return "已触发限流"
        case .error:
            return "读取失败"
        }
    }

    private func localizedStatusMessage(_ status: UsageStatus, fallback: String) -> String {
        switch status {
        case .authRequired:
            return "打开已配置的智能体并重新登录。"
        default:
            return fallback
        }
    }
}

private struct NativeSwitch: NSViewRepresentable {
    @Binding var isOn: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isOn: $isOn)
    }

    func makeNSView(context: Context) -> NSSwitch {
        let switchControl = NSSwitch()
        switchControl.controlSize = .regular
        switchControl.target = context.coordinator
        switchControl.action = #selector(Coordinator.switchChanged(_:))
        switchControl.state = isOn ? .on : .off
        return switchControl
    }

    func updateNSView(_ switchControl: NSSwitch, context: Context) {
        switchControl.state = isOn ? .on : .off
    }

    final class Coordinator: NSObject {
        private var isOn: Binding<Bool>

        init(isOn: Binding<Bool>) {
            self.isOn = isOn
        }

        @objc func switchChanged(_ sender: NSSwitch) {
            isOn.wrappedValue = sender.state == .on
        }
    }
}

private struct MenuMaterialBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .menu
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 10
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = .menu
        view.state = .active
    }
}
