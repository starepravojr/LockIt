import DeviceActivity
import Foundation

/// Run by the system at the start and end of each scheduled interval, without
/// the app being open.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let store = SharedStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard let schedule = schedule(for: activity), schedule.isEnabled,
              // Bricking can only be undone with the card, so ignore a
              // callback that arrives outside the schedule's own interval.
              schedule.contains(.now, leeway: 2),
              let mode = store.modes.first(where: { $0.id == schedule.modeID })
        else { return }
        BrickSessionService(store: store).start(mode: mode, scheduleID: schedule.id)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard let schedule = schedule(for: activity), !schedule.requiresCard else { return }
        // Only end the session this schedule started. One started by the
        // card, or by another schedule, stays until its own way out.
        let state = store.brickState
        guard state.isBricked, state.scheduleID == schedule.id else { return }
        BrickSessionService(store: store).end(reason: .schedule)
    }

    private func schedule(for activity: DeviceActivityName) -> BrickSchedule? {
        guard let id = BrickSchedule.id(for: activity) else { return nil }
        return store.schedules.first { $0.id == id }
    }
}
