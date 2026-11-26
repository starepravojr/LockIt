import DeviceActivity
import Foundation

/// Locks the apps with a mode at the same time every day.
struct LockSchedule: Codable, Identifiable, Equatable {
    /// Apple refuses to monitor an interval shorter than this.
    static let minimumMinutes = 15
    /// Apple allows an app at most this many monitored activities.
    static let maximumCount = 20

    private static let minutesPerDay = 24 * 60

    var id = UUID()
    var modeID: UUID
    /// Minutes after midnight, 0 to 1439.
    var startMinuteOfDay: Int
    /// Minutes after midnight. At or before the start means the next day.
    var endMinuteOfDay: Int
    /// When the interval ends: stay locked until the card is tapped (true)
    /// or unlock automatically (false).
    var requiresCard = true
    var isEnabled = true

    var endsNextDay: Bool { endMinuteOfDay <= startMinuteOfDay }

    var durationMinutes: Int {
        let minutes = endMinuteOfDay - startMinuteOfDay
        return minutes > 0 ? minutes : minutes + Self.minutesPerDay
    }

    /// Why this schedule cannot be saved, or nil when it can.
    var validationError: String? {
        if startMinuteOfDay == endMinuteOfDay {
            return "The start and end can't be the same time."
        }
        if durationMinutes < Self.minimumMinutes {
            return "A schedule has to last at least \(Self.minimumMinutes) minutes. That's an iOS limit."
        }
        return nil
    }

    /// Whether `date` falls inside the interval. `leeway` admits a callback
    /// that arrives slightly before the start.
    func contains(_ date: Date, leeway minutes: Int = 0, calendar: Calendar = .current) -> Bool {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let now = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let sinceStart = (now - startMinuteOfDay + minutes + Self.minutesPerDay) % Self.minutesPerDay
        return sinceStart < durationMinutes + minutes
    }

    // MARK: - DeviceActivity

    var activityName: DeviceActivityName { DeviceActivityName(id.uuidString) }

    /// The schedule a monitored activity belongs to.
    static func id(for activity: DeviceActivityName) -> UUID? {
        UUID(uuidString: activity.rawValue)
    }

    var deviceActivitySchedule: DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: Self.components(startMinuteOfDay),
            intervalEnd: Self.components(endMinuteOfDay),
            repeats: true
        )
    }

    static func components(_ minuteOfDay: Int) -> DateComponents {
        DateComponents(hour: minuteOfDay / 60, minute: minuteOfDay % 60)
    }
}
