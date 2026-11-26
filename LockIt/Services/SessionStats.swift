import Foundation

/// Totals worked out from the session history. A session still running
/// counts up to `now`, and one that crosses midnight is split between days.
struct SessionStats: Equatable {
    struct Day: Identifiable, Equatable {
        /// Midnight at the start of the day.
        let date: Date
        let duration: TimeInterval
        var id: Date { date }
    }

    let today: TimeInterval
    let thisWeek: TimeInterval
    /// The most days in a row with any bricked time.
    let longestStreakDays: Int
    let longestSession: TimeInterval
    /// Oldest first, ending today. Always seven entries.
    let lastSevenDays: [Day]

    init(logs: [SessionLog], now: Date = .now, calendar: Calendar = .current) {
        let spans: [DateInterval] = logs.compactMap { log in
            let end = min(log.end ?? now, now)
            return end > log.start ? DateInterval(start: log.start, end: end) : nil
        }
        let startOfToday = calendar.startOfDay(for: now)

        func day(_ offset: Int) -> DateInterval {
            let start = calendar.date(byAdding: .day, value: offset, to: startOfToday) ?? startOfToday
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        }
        func total(in window: DateInterval) -> TimeInterval {
            spans.reduce(0) { $0 + ($1.intersection(with: window)?.duration ?? 0) }
        }

        today = total(in: day(0))
        thisWeek = calendar.dateInterval(of: .weekOfYear, for: now).map(total) ?? 0
        lastSevenDays = (-6...0).map { offset in
            let window = day(offset)
            return Day(date: window.start, duration: total(in: window))
        }
        longestSession = spans.map(\.duration).max() ?? 0
        longestStreakDays = Self.longestStreak(in: spans, calendar: calendar)
    }

    private static func longestStreak(in spans: [DateInterval], calendar: Calendar) -> Int {
        var days = Set<Date>()
        for span in spans {
            var day = calendar.startOfDay(for: span.start)
            repeat {
                days.insert(day)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            } while day < span.end
        }

        var longest = 0
        var run = 0
        var previous: Date?
        for day in days.sorted() {
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == day {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
            previous = day
        }
        return longest
    }
}
