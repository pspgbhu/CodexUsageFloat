import AgentUsageCore
import AppKit
import SwiftUI

struct UsagePanelView: View {
    @ObservedObject var viewModel: UsageViewModel
    @ObservedObject var settings: AppSettings

    var onRefresh: () -> Void
    var onSetLaunchAtLogin: (Bool) -> Void
    var onSetFloatingWindow: (Bool) -> Void
    var onSetStatusBarMetric: (StatusBarMetric, Bool) -> Void

    private var strings: AppStrings {
        AppStrings(language: settings.language)
    }

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
        .frame(minHeight: 524, alignment: .topLeading)
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
            Text(strings.appTitle)
                .font(.headline)
            Spacer()
            iconButton(
                systemName: viewModel.isRefreshing ? "arrow.clockwise.circle.fill" : "arrow.clockwise",
                action: onRefresh,
                help: strings.refresh
            )
        }
    }

    private var settingsSection: some View {
        VStack(spacing: 4) {
            launchAtLoginRow
            floatingWindowRow
            HStack(spacing: 12) {
                settingsRowLabel(strings.menuBarMetrics, systemName: "menubar.rectangle")
                Spacer()
                Menu(statusBarMetricSummary) {
                    Button(strings.iconOnly) {
                        for metric in StatusBarMetric.allCases {
                            onSetStatusBarMetric(metric, false)
                        }
                    }
                    Divider()

                    ForEach(StatusBarMetric.allCases) { metric in
                        Toggle(strings.metricTitle(metric), isOn: Binding(
                            get: { settings.isStatusBarMetricEnabled(metric) },
                            set: { onSetStatusBarMetric(metric, $0) }
                        ))
                    }
                }
                .menuStyle(.borderlessButton)
            }
            .frame(height: 24)
        }
        .font(.subheadline)
    }

    private var statusBarMetricSummary: String {
        strings.statusBarMetricSummary(count: settings.selectedStatusBarMetrics.count)
    }

    private var launchAtLoginRow: some View {
        HStack(spacing: 12) {
            settingsRowLabel(strings.launchAtLogin, systemName: "power")
            Spacer()
            NativeSwitch(isOn: Binding(
                get: { settings.launchAtLoginEnabled },
                set: { onSetLaunchAtLogin($0) }
            ))
            .frame(width: 44, height: 24)
        }
        .frame(height: 24)
    }

    private var floatingWindowRow: some View {
        HStack(spacing: 12) {
            settingsRowLabel(strings.floatingWindow, systemName: "macwindow.on.rectangle")
            Spacer()
            NativeSwitch(isOn: Binding(
                get: { settings.floatingWindowEnabled },
                set: { onSetFloatingWindow($0) }
            ))
            .frame(width: 44, height: 24)
        }
        .frame(height: 24)
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
                Text(strings.statusTitle(status))
                    .font(.subheadline.weight(.semibold))
                if let message = status.message {
                    Text(strings.statusMessage(status, fallback: message))
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
            labelValue(strings.credits, strings.localizedValue(UsageFormatting.credits(snapshot.credits)), prominent: true)

            if let credits = snapshot.credits {
                HStack(spacing: 10) {
                    chip(credits.hasCredits ? strings.available : strings.noCredits)
                    if credits.unlimited {
                        chip(strings.unlimited)
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
            sectionTitle(strings.limits)
            labelValue(strings.bucket, strings.localizedValue(limits?.limitName ?? limits?.limitID ?? "Unavailable"))
            labelValue(strings.metricTitle(.primaryRemaining), strings.localizedValue(UsageFormatting.percent(limits?.primary?.remainingPercent)), prominent: true)

            if let individual = limits?.individualLimit {
                Divider()
                labelValue(strings.metricTitle(.spendRemaining), "\(individual.remainingPercent)%", prominent: true)
                labelValue(strings.spendLimit, individual.limit)
                labelValue(strings.spendUsed, individual.used)
                labelValue(strings.metricTitle(.resetTime), strings.adaptiveResetTime(individual.resetsAt))
            } else {
                labelValue(strings.metricTitle(.resetTime), strings.adaptiveResetTime(limits?.primary?.resetsAt))
            }
        }
    }

    private func tokenSection(_ tokenUsage: TokenUsageInfo?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(strings.tokenSectionTitle)
            labelValue(strings.today, strings.localizedValue(UsageFormatting.tokenCount(tokenUsage?.todayTokens)), prominent: true)
            labelValue(strings.lifetime, strings.localizedValue(UsageFormatting.tokenCount(tokenUsage?.lifetimeTokens)))
            labelValue(strings.peakDay, strings.localizedValue(UsageFormatting.tokenCount(tokenUsage?.peakDailyTokens)))

            if let streak = tokenUsage?.currentStreakDays {
                labelValue(strings.metricTitle(.currentStreakDays), strings.days(streak))
            }
        }
    }

    private func footer(_ refreshedAt: Date) -> some View {
        HStack {
            Text("\(strings.updatedAtPrefix) \(strings.timeWithSeconds(refreshedAt))")
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
