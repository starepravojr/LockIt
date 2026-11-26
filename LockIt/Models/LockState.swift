import Foundation

/// Whether the apps are currently locked, and with which mode.
/// Stored in the App Group so the extensions can read and write it.
struct LockState: Codable, Equatable {
    var isLocked = false
    var lockedAt: Date?
    var activeModeID: UUID?
    /// The schedule that started this session, or nil when the card did.
    var scheduleID: UUID?

    /// The first two keep the names they were saved under before the Brick
    /// to Lock rename, so state stored by an earlier build still loads.
    private enum CodingKeys: String, CodingKey {
        case isLocked = "isBricked"
        case lockedAt = "brickedAt"
        case activeModeID
        case scheduleID
    }
}
