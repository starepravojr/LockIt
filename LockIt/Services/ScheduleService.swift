import DeviceActivity

/// Registers schedules with the system, which wakes the monitor extension
/// at each interval's start and end.
struct ScheduleService {
    private let center = DeviceActivityCenter()

    /// Starts or replaces the monitor for one schedule. If the current time
    /// is inside its interval, the system starts the interval straight away.
    func start(_ schedule: BrickSchedule) throws {
        try center.startMonitoring(schedule.activityName, during: schedule.deviceActivitySchedule)
    }

    func stop(_ schedule: BrickSchedule) {
        center.stopMonitoring([schedule.activityName])
    }

    /// Stops monitors left behind by schedules that no longer exist or are off.
    func stopOrphans(keeping schedules: [BrickSchedule]) {
        let wanted = Set(schedules.filter(\.isEnabled).map(\.activityName))
        let orphans = center.activities.filter { !wanted.contains($0) }
        if !orphans.isEmpty {
            center.stopMonitoring(orphans)
        }
    }
}
