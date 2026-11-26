import Charts
import SwiftUI

/// Time locked today and this week, the longest streak, the last seven days
/// as a chart, and the session history.
struct StatsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var logs: [SessionLog] = []
    @State private var selectedDate: Date?

    var body: some View {
        NavigationStack {
            Group {
                if logs.isEmpty {
                    ContentUnavailableView(
                        "No sessions yet",
                        systemImage: "chart.bar",
                        description: Text("Lock your apps and your sessions will show up here.")
                    )
                } else {
                    // Recalculated each minute so a running session keeps counting.
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        content(SessionStats(logs: logs, now: context.date), now: context.date)
                    }
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { logs = model.sessionLogs() }
    }

    private func content(_ stats: SessionStats, now: Date) -> some View {
        List {
            Section {
                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        StatTile(label: "Today", value: stats.today.briefDuration)
                        StatTile(label: "This week", value: stats.thisWeek.briefDuration)
                    }
                    GridRow {
                        StatTile(label: "Longest streak", value: Self.days(stats.longestStreakDays))
                        StatTile(label: "Longest session", value: stats.longestSession.briefDuration)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Last 7 days") {
                WeekChart(days: stats.lastSevenDays, selectedDate: $selectedDate)
                    .padding(.vertical, 8)
            }

            Section("History") {
                ForEach(logs.sorted { $0.start > $1.start }.prefix(50)) { log in
                    SessionRow(log: log, modeName: modeName(for: log), now: now)
                }
            }
        }
    }

    private func modeName(for log: SessionLog) -> String {
        model.modes.first { $0.id == log.modeID }?.name ?? "Deleted mode"
    }

    private static func days(_ count: Int) -> String {
        count == 1 ? "1 day" : "\(count) days"
    }
}

private struct StatTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

/// Hours locked on each of the last seven days. Tap or drag across the
/// chart to read one day's total.
private struct WeekChart: View {
    let days: [SessionStats.Day]
    @Binding var selectedDate: Date?

    private var selectedDay: SessionStats.Day? {
        guard let selectedDate else { return nil }
        return days.last { $0.date <= selectedDate }
    }

    private var maxHours: Double {
        (days.map(\.duration).max() ?? 0) / 3600
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Chart(days) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Hours", day.duration / 3600),
                    width: .fixed(20)
                )
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
                .foregroundStyle(Color.accentColor)
                .opacity(selectedDay == nil || selectedDay == day ? 1 : 0.35)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let hours = value.as(Double.self) {
                            Text("\(hours.formatted(.number.precision(.fractionLength(0...1)))) h")
                        }
                    }
                }
            }
            // Keep a sensible scale when there is little or no data.
            .chartYScale(domain: 0...max(1, maxHours))
            .chartXSelection(value: $selectedDate)
            .frame(height: 180)
        }
    }

    private var caption: String {
        if let day = selectedDay {
            return "\(day.date.formatted(.dateTime.weekday(.wide).day().month())): \(day.duration.briefDuration)"
        }
        let total = days.reduce(0) { $0 + $1.duration }
        return "\(total.briefDuration) in total. Tap a bar for that day."
    }
}

private struct SessionRow: View {
    let log: SessionLog
    let modeName: String
    let now: Date

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.start.formatted(.dateTime.weekday(.abbreviated).day().month().hour().minute()))
                Text("\(modeName), \(ending)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(max(0, (log.end ?? now).timeIntervalSince(log.start)).briefDuration)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var ending: String {
        switch log.endedBy {
        case .card: "ended with card"
        case .emergency: "Emergency Unlock"
        case .schedule: "ended by schedule"
        case .bypassDetected: "bypass detected"
        case nil: "in progress"
        }
    }
}

extension TimeInterval {
    /// For example "2 hr, 15 min" or "0 min".
    var briefDuration: String {
        Duration.seconds(rounded())
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}
