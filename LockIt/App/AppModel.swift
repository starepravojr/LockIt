import Foundation
import Observation

/// App state: the saved modes, the paired card, and whether the phone is
/// bricked. Keeps the persisted state and the shields in step with each other.
@MainActor
@Observable
final class AppModel {
    private(set) var state: BrickState
    private(set) var modes: [BrickMode]
    private(set) var schedules: [BrickSchedule]
    private(set) var settings: AppSettings
    private(set) var pairedCardUID: String?
    private(set) var emergencyUnbricksRemaining: Int
    /// A message the user has to see, such as a detected bypass.
    private(set) var notice: String?

    @ObservationIgnored private let store: SharedStore
    @ObservationIgnored private let keychain: KeychainStore
    @ObservationIgnored private let session: BrickSessionService
    @ObservationIgnored private let scheduleService = ScheduleService()
    @ObservationIgnored private let nfc = NFCService()

    init(store: SharedStore = SharedStore(), keychain: KeychainStore = KeychainStore()) {
        self.store = store
        self.keychain = keychain
        session = BrickSessionService(store: store)
        state = store.brickState
        modes = store.modes
        schedules = store.schedules
        settings = store.settings
        pairedCardUID = keychain.pairedCardUID
        emergencyUnbricksRemaining = keychain.emergencyUnbricksRemaining
        scheduleService.stopOrphans(keeping: schedules)
    }

    /// Picks up a session the monitor extension started or ended.
    func reload() {
        let stored = store.brickState
        if stored != state { state = stored }
    }

    /// The mode in force while bricked, or the one a new brick would use.
    var activeMode: BrickMode? {
        modes.first { $0.id == state.activeModeID } ?? modes.first
    }

    /// Every session so far, including one still running.
    func sessionLogs() -> [SessionLog] {
        store.sessionLogs
    }

    /// The schedule that started the current session, if one did.
    var activeSchedule: BrickSchedule? {
        guard state.isBricked, let id = state.scheduleID else { return nil }
        return schedules.first { $0.id == id }
    }

    /// Strict Mode hides Emergency Unbrick entirely.
    var offersEmergencyUnbrick: Bool { !settings.strictMode }

    var canEmergencyUnbrick: Bool {
        state.isBricked && offersEmergencyUnbrick && emergencyUnbricksRemaining > 0
    }

    // MARK: - Setup, allowed only while unbricked

    /// Adds or replaces a mode. Ignored while bricked, since editing the
    /// active mode would be a way around the block.
    func save(_ mode: BrickMode) {
        guard !state.isBricked else { return }
        if let index = modes.firstIndex(where: { $0.id == mode.id }) {
            modes[index] = mode
        } else {
            modes.append(mode)
        }
        store.modes = modes
    }

    /// Chooses the mode the next card tap will brick with.
    func selectMode(_ id: UUID) {
        guard !state.isBricked, modes.contains(where: { $0.id == id }) else { return }
        state.activeModeID = id
        store.brickState = state
    }

    /// The last mode, and a mode a schedule uses, have to stay.
    func canDelete(_ mode: BrickMode) -> Bool {
        !state.isBricked && modes.count > 1 && !schedules.contains { $0.modeID == mode.id }
    }

    func deleteMode(_ mode: BrickMode) {
        guard canDelete(mode) else { return }
        modes.removeAll { $0.id == mode.id }
        store.modes = modes
        if state.activeModeID == mode.id {
            state.activeModeID = nil
            store.brickState = state
        }
    }

    /// Adds or replaces a schedule and registers it with the system. The
    /// schedule is stored first because the monitor extension looks it up
    /// there, and it can be woken the moment monitoring starts.
    func saveSchedule(_ schedule: BrickSchedule) throws {
        guard !state.isBricked else { return }
        let previous = schedules
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
        } else {
            guard schedules.count < BrickSchedule.maximumCount else { throw TooManySchedulesError() }
            schedules.append(schedule)
        }
        store.schedules = schedules

        guard schedule.isEnabled else {
            scheduleService.stop(schedule)
            return
        }
        do {
            try scheduleService.start(schedule)
        } catch {
            schedules = previous
            store.schedules = previous
            throw error
        }
    }

    func deleteSchedule(_ schedule: BrickSchedule) {
        guard !state.isBricked else { return }
        scheduleService.stop(schedule)
        schedules.removeAll { $0.id == schedule.id }
        store.schedules = schedules
    }

    func setStrictMode(_ isOn: Bool) {
        guard !state.isBricked else { return }
        settings.strictMode = isOn
        store.settings = settings
    }

    /// Scans a card and makes it the only one that bricks and unbricks.
    func pairCard() async throws {
        guard !state.isBricked else { return }
        guard let uid = try await scan(successMessage: "Card paired") else { return }
        guard !state.isBricked else { return }
        try keychain.setPairedCardUID(uid)
        pairedCardUID = uid
    }

    // MARK: - Brick and unbrick

    /// Scans for the paired card, then bricks or unbricks. A wrong card, or a
    /// cancelled scan, changes nothing.
    func tapCard() async throws {
        guard let pairedCardUID else { throw NoPairedCardError() }
        reload()
        let wasBricked = state.isBricked
        guard wasBricked || activeMode != nil else { return }

        let message = wasBricked ? "Unbricked" : "Bricked"
        guard try await scan(expecting: pairedCardUID, successMessage: message) != nil else { return }
        // A schedule may have started or ended the session during the scan.
        reload()
        guard state.isBricked == wasBricked else { return }
        toggleBrick()
    }

    #if DEBUG
    // MARK: - Simulated card, Debug builds only
    //
    // Stands in for the NFC read until the real cards arrive, so everything
    // after the read can be tested. Delete this block and the two buttons that
    // call it (search for "Simulate") once a real card is paired.

    static let simulatedCardUID = "04DEB060000000"

    func simulatePairCard() throws {
        guard !state.isBricked else { return }
        try keychain.setPairedCardUID(Self.simulatedCardUID)
        pairedCardUID = Self.simulatedCardUID
    }

    /// Behaves as if the paired card had just been read.
    func simulateCardTap() {
        guard pairedCardUID != nil else { return }
        toggleBrick()
    }
    #endif

    /// Ends the block without the card and spends one Emergency Unbrick.
    /// The counter is saved first, so a failed save leaves the block in place.
    func emergencyUnbrick() throws {
        reload()
        guard canEmergencyUnbrick else { return }
        try keychain.setEmergencyUnbricksRemaining(emergencyUnbricksRemaining - 1)
        emergencyUnbricksRemaining = keychain.emergencyUnbricksRemaining
        unbrick(endedBy: .emergency)
    }

    /// Call when Screen Time access is found revoked. If the phone was
    /// bricked, that was a bypass: it ends the session and costs one
    /// Emergency Unbrick, staying at zero if none are left.
    func endBrickAfterAccessRevoked() {
        guard state.isBricked else { return }
        let cost: String
        if emergencyUnbricksRemaining > 0 {
            try? keychain.setEmergencyUnbricksRemaining(emergencyUnbricksRemaining - 1)
            emergencyUnbricksRemaining = keychain.emergencyUnbricksRemaining
            cost = "That cost one Emergency Unbrick. \(emergencyUnbricksRemaining) left."
        } else {
            cost = "You had no Emergency Unbricks left to lose."
        }
        unbrick(endedBy: .bypassDetected)
        notice = "Screen Time access was turned off while you were bricked, so the block ended. " + cost
    }

    func dismissNotice() {
        notice = nil
    }

    // MARK: - Private

    /// What a successful read of the paired card does.
    private func toggleBrick() {
        if state.isBricked {
            unbrick(endedBy: .card)
        } else {
            brick()
        }
    }

    private func brick() {
        guard let mode = activeMode else { return }
        session.start(mode: mode)
        state = store.brickState
    }

    private func unbrick(endedBy reason: SessionLog.EndReason) {
        session.end(reason: reason)
        state = store.brickState
    }

    /// Returns nil when the scan ended in a way the NFC sheet already
    /// explained: cancelled, timed out, or the wrong kind of card.
    private func scan(expecting expectedUID: String? = nil, successMessage: String) async throws -> String? {
        do {
            return try await nfc.scan(expecting: expectedUID, successMessage: successMessage)
        } catch let error as NFCScanError where error.isAlreadyExplained {
            return nil
        }
    }
}

struct TooManySchedulesError: LocalizedError {
    var errorDescription: String? {
        "iOS allows at most \(BrickSchedule.maximumCount) schedules. Delete one first."
    }
}

struct NoPairedCardError: LocalizedError {
    var errorDescription: String? {
        "No paired card could be read from the Keychain. Restart your iPhone and try again."
    }
}
