import Foundation

/// Whether the phone is currently bricked, and with which mode.
/// Stored in the App Group so the extensions can read and write it.
struct BrickState: Codable, Equatable {
    var isBricked = false
    var brickedAt: Date?
    var activeModeID: UUID?
    /// The schedule that started this session, or nil when the card did.
    var scheduleID: UUID?
}
