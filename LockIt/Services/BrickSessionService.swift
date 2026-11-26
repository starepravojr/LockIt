import Foundation

/// Starts and ends bricked sessions. The app and the monitor extension both
/// go through here, so a card tap and a schedule follow the same steps.
struct BrickSessionService {
    let store: SharedStore
    private let blocking = BlockingService()

    /// Returns false, changing nothing, when a session is already running.
    @discardableResult
    func start(mode: BrickMode, scheduleID: UUID? = nil) -> Bool {
        guard !store.brickState.isBricked else { return false }
        let now = Date.now
        blocking.apply(mode, strictMode: store.settings.strictMode)
        store.brickState = BrickState(
            isBricked: true, brickedAt: now, activeModeID: mode.id, scheduleID: scheduleID
        )
        store.sessionLogs.append(SessionLog(start: now, modeID: mode.id))
        StateChangeSignal.post()
        return true
    }

    /// Returns false, changing nothing, when no session is running.
    @discardableResult
    func end(reason: SessionLog.EndReason) -> Bool {
        var state = store.brickState
        guard state.isBricked else { return false }
        blocking.clear()
        state.isBricked = false
        state.brickedAt = nil
        state.scheduleID = nil
        store.brickState = state

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
