import Foundation
import Observation

/// App state: the saved modes, the paired card, and whether the phone is
/// locked. Keeps the persisted state and the shields in step with each other.
@MainActor
@Observable
final class AppModel {
    /// One instance for the whole app process, so the screens and the
    /// Shortcuts action act on the same state.
    static let shared = AppModel()

    private(set) var state: LockState
    private(set) var modes: [LockMode]
    private(set) var schedules: [LockSchedule]
    private(set) var settings: AppSettings
    private(set) var pairedCardUID: String?
    private(set) var emergencyUnlocksRemaining: Int
    /// A message the user has to see, such as a detected bypass.
    private(set) var notice: String?
    /// When the Shortcuts action last asked for a card scan. Home starts the
    /// scan once the app is on screen.
    private(set) var scanRequestedAt: Date?

    @ObservationIgnored private let store: SharedStore
    @ObservationIgnored private let keychain: KeychainStore
    @ObservationIgnored private let session: LockSessionService
    @ObservationIgnored private let scheduleService = ScheduleService()
    @ObservationIgnored private let nfc = NFCService()
    /// When a card last locked or unlocked, by either route.
    @ObservationIgnored private var lastCardActionAt: Date?

    init(store: SharedStore = SharedStore(), keychain: KeychainStore = KeychainStore()) {
        self.store = store
        self.keychain = keychain
        session = LockSessionService(store: store)
        state = store.lockState
        modes = store.modes
        schedules = store.schedules
        settings = store.settings
        pairedCardUID = keychain.pairedCardUID
        emergencyUnlocksRemaining = keychain.emergencyUnlocksRemaining
        scheduleService.stopOrphans(keeping: schedules)
    }

    /// Picks up a session the monitor extension started or ended.
    func reload() {
        let stored = store.lockState
        if stored != state { state = stored }
    }

    /// The mode in force while locked, or the one a new lock would use.
    var activeMode: LockMode? {
        modes.first { $0.id == state.activeModeID } ?? modes.first
    }

    /// Every session so far, including one still running.
    func sessionLogs() -> [SessionLog] {
        store.sessionLogs
    }

    /// The schedule that started the current session, if one did.
    var activeSchedule: LockSchedule? {
        guard state.isLocked, let id = state.scheduleID else { return nil }
        return schedules.first { $0.id == id }
    }

    /// Strict Mode hides Emergency Unlock entirely.
    var offersEmergencyUnlock: Bool { !settings.strictMode }

    var canEmergencyUnlock: Bool {
        state.isLocked && offersEmergencyUnlock && emergencyUnlocksRemaining > 0
    }

    // MARK: - Setup, allowed only while unlocked

    /// Adds or replaces a mode. Ignored while locked, since editing the
    /// active mode would be a way around the block.
    func save(_ mode: LockMode) {
        guard !state.isLocked else { return }
        if let index = modes.firstIndex(where: { $0.id == mode.id }) {
            modes[index] = mode
        } else {
            modes.append(mode)
        }
        store.modes = modes
    }

    /// Chooses the mode the next card tap will lock with.
    func selectMode(_ id: UUID) {
        guard !state.isLocked, modes.contains(where: { $0.id == id }) else { return }
        state.activeModeID = id
        store.lockState = state
    }

    /// The last mode, and a mode a schedule uses, have to stay.
    func canDelete(_ mode: LockMode) -> Bool {
        !state.isLocked && modes.count > 1 && !schedules.contains { $0.modeID == mode.id }
    }

    func deleteMode(_ mode: LockMode) {
        guard canDelete(mode) else { return }
        modes.removeAll { $0.id == mode.id }
        store.modes = modes
        if state.activeModeID == mode.id {
            state.activeModeID = nil
            store.lockState = state
        }
    }

    /// Adds or replaces a schedule and registers it with the system. The
    /// schedule is stored first because the monitor extension looks it up
    /// there, and it can be woken the moment monitoring starts.
    func saveSchedule(_ schedule: LockSchedule) throws {
        guard !state.isLocked else { return }
        let previous = schedules
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
        } else {
            guard schedules.count < LockSchedule.maximumCount else { throw TooManySchedulesError() }
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

    func deleteSchedule(_ schedule: LockSchedule) {
        guard !state.isLocked else { return }
        scheduleService.stop(schedule)
        schedules.removeAll { $0.id == schedule.id }
        store.schedules = schedules
    }

    func setStrictMode(_ isOn: Bool) {
        guard !state.isLocked else { return }
        settings.strictMode = isOn
        store.settings = settings
    }

    /// Scans a card and makes it the only one that locks and unlocks.
    func pairCard() async throws {
        guard !state.isLocked else { return }
        guard let uid = try await scan(successMessage: "Card paired") else { return }
        guard !state.isLocked else { return }
        try keychain.setPairedCardUID(uid)
        pairedCardUID = uid
    }

    // MARK: - Lock and unlock

    /// Scans for the paired card, then locks or unlocks. A wrong card, or a
    /// cancelled scan, changes nothing.
    func tapCard() async throws {
        guard let pairedCardUID else { throw NoPairedCardError() }
        reload()
        let wasLocked = state.isLocked
        guard wasLocked || activeMode != nil else { return }

        let message = wasLocked ? "Unlocked" : "Locked"
        guard try await scan(expecting: pairedCardUID, successMessage: message) != nil else { return }
        // A schedule may have started or ended the session during the scan.
        reload()
        guard state.isLocked == wasLocked else { return }
        toggleLock()
    }

    // MARK: - Card tap reported by Shortcuts
    //
    // A Shortcuts automation fires when the card is scanned, but it does not
    // say which card. So this route may only lock. Unlocking always goes
    // through `tapCard()`, which reads the card and checks it is the paired one.

    /// Locks with the chosen mode and returns true. Returns false, changing
    /// nothing, if already locked or the card only just acted.
    @discardableResult
    func lockFromShortcut() throws -> Bool {
        reload()
        guard !state.isLocked, !isInCardCooldown else { return false }
        guard pairedCardUID != nil, activeMode != nil else { throw CardTapError.setupIncomplete }
        toggleLock()
        return state.isLocked
    }

    /// Asks Home to start the verified card scan. Returns false when the tap
    /// should be ignored because the card only just acted.
    func requestScanFromShortcut() -> Bool {
        guard !isInCardCooldown else { return false }
        scanRequestedAt = .now
        return true
    }

    func cancelScanRequest() {
        scanRequestedAt = nil
    }

    /// Returns true once for each fresh request. A request left unanswered
    /// for a while is dropped rather than starting a scan out of nowhere.
    func consumeScanRequest() -> Bool {
        guard let requestedAt = scanRequestedAt else { return false }
        scanRequestedAt = nil
        return Date.now.timeIntervalSince(requestedAt) < Self.scanRequestLifetime
    }

    /// The phone is usually still on the card just after it locks or unlocks,
    /// and iOS can report that same card to Shortcuts again. Without this
    /// pause an unlock would be followed at once by a new lock.
    private var isInCardCooldown: Bool {
        guard let lastCardActionAt else { return false }
        return Date.now.timeIntervalSince(lastCardActionAt) < Self.cardCooldown
    }

    private static let cardCooldown: TimeInterval = 5
    private static let scanRequestLifetime: TimeInterval = 30

    /// Ends the block without the card and spends one Emergency Unlock.
    /// The counter is saved first, so a failed save leaves the block in place.
    func emergencyUnlock() throws {
        reload()
        guard canEmergencyUnlock else { return }
        try keychain.setEmergencyUnlocksRemaining(emergencyUnlocksRemaining - 1)
        emergencyUnlocksRemaining = keychain.emergencyUnlocksRemaining
        unlock(endedBy: .emergency)
    }

    /// Call when Screen Time access is found revoked. If the phone was
    /// locked, that was a bypass: it ends the session and costs one
    /// Emergency Unlock, staying at zero if none are left.
    func endLockAfterAccessRevoked() {
        guard state.isLocked else { return }
        let cost: String
        if emergencyUnlocksRemaining > 0 {
            try? keychain.setEmergencyUnlocksRemaining(emergencyUnlocksRemaining - 1)
            emergencyUnlocksRemaining = keychain.emergencyUnlocksRemaining
            cost = "That cost one Emergency Unlock. \(emergencyUnlocksRemaining) left."
        } else {
            cost = "You had no Emergency Unlocks left to lose."
        }
        unlock(endedBy: .bypassDetected)
        notice = "Screen Time access was turned off while your apps were locked, so the lock ended. " + cost
    }

    func dismissNotice() {
        notice = nil
    }

    // MARK: - Private

    /// What a successful read of the paired card does.
    private func toggleLock() {
        lastCardActionAt = .now
        if state.isLocked {
            unlock(endedBy: .card)
        } else {
            lock()
        }
    }

    private func lock() {
        guard let mode = activeMode else { return }
        session.start(mode: mode)
        state = store.lockState
    }

    private func unlock(endedBy reason: SessionLog.EndReason) {
        session.end(reason: reason)
        state = store.lockState
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
        "iOS allows at most \(LockSchedule.maximumCount) schedules. Delete one first."
    }
}

struct NoPairedCardError: LocalizedError {
    var errorDescription: String? {
        "No paired card could be read from the Keychain. Restart your iPhone and try again."
    }
}
