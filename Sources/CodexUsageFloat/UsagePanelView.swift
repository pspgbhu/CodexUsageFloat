import AgentUsageCore
import AppKit
import SwiftUI

struct UsagePanelView: View {
    static let width: CGFloat = 340

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
        VStack(alignment: .leading, spacing: 12) {
            header

            if let snapshot = viewModel.snapshot {
                if snapshot.status != .fresh {
                    statusRow(snapshot.status)
                }
                accountSection(snapshot)
                Divider()
                if !snapshot.visibleQuotaPeriods.isEmpty {
                    limitsSection(snapshot)
                    Divider()
                }
                TokenUsageChart(dailyUsage: snapshot.tokenUsage?.dailyUsage, strings: strings)
                Divider()
                settingsSection
                footer(snapshot)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
                Divider()
                settingsSection
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .frame(width: Self.width, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
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
                .font(.system(size: 16, weight: .semibold))
            Text(strings.appTitle)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            refreshButton
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

                    ForEach(StatusBarMetric.available(for: viewModel.snapshot)) { metric in
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
        .font(.system(size: 12, weight: .regular))
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
                .foregroundStyle(.secondary)
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

    private func accountSection(_ snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            labelValue(strings.subscriptionType, snapshot.subscription?.displayName ?? strings.unavailable)
            labelValue(strings.credits, strings.localizedValue(UsageFormatting.credits(snapshot.credits)))
        }
    }

    private func limitsSection(_ snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(snapshot.visibleQuotaPeriods, id: \.self) { period in
                quotaRow(period, window: snapshot.limits?.quotaWindows[period])
            }
        }
    }

    private func quotaRow(_ period: UsageQuotaPeriod, window: LimitWindowInfo?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(strings.quotaTitle(period))
                    .font(.system(size: 12, weight: .medium))
                Spacer(minLength: 12)
                Text(strings.localizedValue(UsageFormatting.percent(window?.remainingPercent)))
                    .font(.system(size: window == nil ? 12 : 20, weight: .semibold))
                    .monospacedDigit()
            }

            if let window {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(Color.accentColor.opacity(0.85))
                            .frame(width: geometry.size.width * CGFloat(window.remainingPercent) / 100)
                    }
                }
                .frame(height: 4)
                .accessibilityHidden(true)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(strings.metricTitle(.resetTime))
                Spacer(minLength: 12)
                Text(strings.adaptiveResetTime(window?.resetsAt, includeTimeWithDate: true))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
            }
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(.secondary)
        }
    }

    private func footer(_ snapshot: UsageSnapshot) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor(snapshot.status))
                .frame(width: 6, height: 6)
                .help(strings.statusTitle(snapshot.status))
                .accessibilityLabel(strings.statusTitle(snapshot.status))
            Text("\(strings.updatedAtPrefix) \(strings.timeWithSeconds(snapshot.refreshedAt))")
            Spacer()
            Text("\(Int(settings.refreshIntervalSeconds))s")
        }
        .font(.system(size: 10, weight: .regular))
        .monospacedDigit()
        .foregroundStyle(.secondary)
    }

    private func labelValue(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .font(.system(size: 12, weight: .regular))
    }

    private var refreshButton: some View {
        Button(action: onRefresh) {
            ZStack {
                Image(systemName: "arrow.clockwise")
                    .opacity(viewModel.isRefreshing ? 0 : 1)

                if viewModel.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16, height: 16)
                }
            }
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(viewModel.isRefreshing)
        .help(viewModel.isRefreshing ? strings.refreshing : strings.refresh)
        .accessibilityLabel(viewModel.isRefreshing ? strings.refreshing : strings.refresh)
        .transaction { $0.animation = nil }
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
