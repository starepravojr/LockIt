import Foundation

/// Starts and ends locked sessions. The app and the monitor extension both
/// go through here, so a card tap and a schedule follow the same steps.
struct LockSessionService {
    let store: SharedStore
    private let blocking = BlockingService()

    /// Returns false, changing nothing, when a session is already running.
    @discardableResult
    func start(mode: LockMode, scheduleID: UUID? = nil) -> Bool {
        guard !store.lockState.isLocked else { return false }
        let now = Date.now
        blocking.apply(mode, strictMode: store.settings.strictMode)
        store.lockState = LockState(
            isLocked: true, lockedAt: now, activeModeID: mode.id, scheduleID: scheduleID
        )
        store.sessionLogs.append(SessionLog(start: now, modeID: mode.id))
        StateChangeSignal.post()
        return true
    }

    /// Returns false, changing nothing, when no session is running.
    @discardableResult
    func end(reason: SessionLog.EndReason) -> Bool {
        var state = store.lockState
        guard state.isLocked else { return false }
        blocking.clear()
        state.isLocked = false
        state.lockedAt = nil
        state.scheduleID = nil
        store.lockState = state

        var logs = store.sessionLogs
        if let index = logs.lastIndex(where: { $0.end == nil }) {
            logs[index].end = .now
            logs[index].endedBy = reason
            store.sessionLogs = logs
        }
        StateChangeSignal.post()
        return true
    }
}
