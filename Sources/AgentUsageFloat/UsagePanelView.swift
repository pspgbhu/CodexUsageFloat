import AgentUsageCore
import SwiftUI

struct UsagePanelView: View {
    @ObservedObject var viewModel: UsageViewModel
    @ObservedObject var settings: AppSettings

    var onRefresh: () -> Void
    var onTogglePin: () -> Void
    var onToggleLaunchAtLogin: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let snapshot = viewModel.snapshot {
                statusRow(snapshot.status)
                creditsSection(snapshot)
                limitsSection(snapshot.limits)
                tokenSection(snapshot.tokenUsage)
                footer(snapshot.refreshedAt)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .padding(16)
        .frame(width: 340)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: 18, weight: .semibold))
            Text("Agent Usage")
                .font(.headline)
            Spacer()
            iconButton(systemName: settings.isPinned ? "pin.fill" : "pin", action: onTogglePin)
            iconButton(systemName: viewModel.isRefreshing ? "arrow.clockwise.circle.fill" : "arrow.clockwise", action: onRefresh)
            Menu {
                Button(settings.launchAtLoginEnabled ? "Disable Login Launch" : "Enable Login Launch") {
                    onToggleLaunchAtLogin()
                }
                Button("Quit") {
                    onQuit()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24, height: 24)
        }
    }

    private func statusRow(_ status: UsageStatus) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 8, height: 8)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.title)
                    .font(.subheadline.weight(.semibold))
                if let message = status.message {
                    Text(message)
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
            labelValue("Credits", UsageFormatting.credits(snapshot.credits), prominent: true)

            if let credits = snapshot.credits {
                HStack(spacing: 10) {
                    chip(credits.hasCredits ? "Available" : "No credits")
                    if credits.unlimited {
                        chip("Unlimited")
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
            sectionTitle("Limits")
            labelValue("Bucket", limits?.limitName ?? limits?.limitID ?? "Unavailable")
            labelValue("Primary remaining", UsageFormatting.percent(limits?.primary?.remainingPercent), prominent: true)
            labelValue("Secondary remaining", UsageFormatting.percent(limits?.secondary?.remainingPercent))

            if let individual = limits?.individualLimit {
                Divider()
                labelValue("Spend remaining", "\(individual.remainingPercent)%", prominent: true)
                labelValue("Spend limit", individual.limit)
                labelValue("Spend used", individual.used)
                labelValue("Resets", UsageFormatting.dateTime(individual.resetsAt))
            } else if let reset = limits?.primary?.resetsAt {
                labelValue("Resets", UsageFormatting.dateTime(reset))
            }
        }
    }

    private func tokenSection(_ tokenUsage: TokenUsageInfo?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Tokens")
            labelValue("Today", UsageFormatting.tokenCount(tokenUsage?.todayTokens), prominent: true)
            labelValue("Lifetime", UsageFormatting.tokenCount(tokenUsage?.lifetimeTokens))
            labelValue("Peak day", UsageFormatting.tokenCount(tokenUsage?.peakDailyTokens))

            if let streak = tokenUsage?.currentStreakDays {
                labelValue("Current streak", "\(streak)d")
            }
        }
    }

    private func footer(_ refreshedAt: Date) -> some View {
        HStack {
            Text("Updated \(UsageFormatting.dateTime(refreshedAt))")
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
                .font(prominent ? .title3.weight(.semibold) : .body.weight(.medium))
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

    private func iconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.borderless)
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
