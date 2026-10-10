import AgentUsageCore
import SwiftUI

struct TokenUsageChart: View {
    let dailyUsage: [DailyTokenUsage]?
    let strings: AppStrings

    @State private var hoveredDate: Date?

    private let plotHeight: CGFloat = 100
    private let axisWidth: CGFloat = 36
    private let axisSpacing: CGFloat = 8

    private var days: [DailyTokenUsage] { dailyUsage ?? [] }
    private var hasData: Bool { days.contains { $0.tokens != nil } }
    private var peak: Int64 { max(days.compactMap(\.tokens).max() ?? 0, 1) }
    private var hoveredDay: DailyTokenUsage? { days.first { $0.date == hoveredDate } }
    private var totalTokens: Int64? {
        guard hasData else { return nil }
        return days.compactMap(\.tokens).reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(strings.tokenSectionTitle)
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 0)
                Text(hoveredDay.map { "\(strings.tokenChartDate($0.date)) · \(strings.localizedValue(UsageFormatting.tokenCount($0.tokens)))" }
                     ?? strings.tokenChartTotal(totalTokens))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .help(hoveredDay.map { "\(strings.tokenChartDate($0.date, includeYear: true)): \(strings.tokenChartValue($0.tokens))" }
                          ?? strings.tokenChartTotalDetail(totalTokens, reportedDays: days.filter { $0.tokens != nil }.count))
            }

            if hasData {
                plot
                    .accessibilityHint(strings.tokenChartHint)
                dateAxis
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.title2)
                    Text(strings.tokenHistoryUnavailable)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: plotHeight + 20)
            }
        }
    }

    private var plot: some View {
        HStack(alignment: .top, spacing: axisSpacing) {
            VStack(alignment: .trailing, spacing: 0) {
                Text(UsageFormatting.tokenCount(peak))
                Spacer()
                if peak > 1 {
                    Text(UsageFormatting.tokenCount(peak / 2))
                    Spacer()
                }
                Text("0")
            }
            .font(.system(size: 10, weight: .regular))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(width: axisWidth, height: plotHeight, alignment: .trailing)
            .accessibilityHidden(true)

            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    gridLine
                    Spacer()
                    gridLine
                    Spacer()
                    gridLine
                }
                .accessibilityHidden(true)

                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(days) { day in
                        dayColumn(day)
                    }
                }
            }
            .frame(height: plotHeight)
        }
    }

    private var gridLine: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.10))
            .frame(height: 0.5)
    }

    private func dayColumn(_ day: DailyTokenUsage) -> some View {
        let isHovered = hoveredDate == day.date
        let isToday = day.date == days.last?.date
        let height = plotHeight * CGFloat(max(day.tokens ?? 0, 0)) / CGFloat(peak)

        return Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: plotHeight)
            .background(Color.primary.opacity(isHovered ? 0.06 : 0))
            .overlay(alignment: .bottom) {
                if day.tokens == nil {
                    Capsule()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(height: 2)
                } else {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.accentColor.opacity(isHovered || isToday ? 1 : 0.65))
                        .frame(height: height)
                }
            }
            .contentShape(Rectangle())
            .onHover { inside in
                if inside {
                    hoveredDate = day.date
                } else if hoveredDate == day.date {
                    hoveredDate = nil
                }
            }
            .help("\(strings.tokenChartDate(day.date, includeYear: true)): \(strings.tokenChartValue(day.tokens))")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(strings.tokenChartDate(day.date, includeYear: true))
            .accessibilityValue(strings.tokenChartValue(day.tokens))
    }

    private var dateAxis: some View {
        HStack {
            if let first = days.first, let last = days.last {
                Text(strings.tokenChartDate(first.date))
                Spacer()
                Text(strings.tokenChartDate(days[days.count / 2].date))
                Spacer()
                Text(strings.tokenChartDate(last.date))
            }
        }
        .font(.system(size: 10, weight: .regular))
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .padding(.leading, axisWidth + axisSpacing)
        .accessibilityHidden(true)
    }
}
