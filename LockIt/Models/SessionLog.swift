import Foundation

/// One bricked session. `end` and `endedBy` are nil while it is still running.
struct SessionLog: Codable, Identifiable, Equatable {
    enum EndReason: String, Codable {
        case card
        case emergency
        case schedule
        case bypassDetected
    }

    var id = UUID()
    var start: Date
    var end: Date?
    var modeID: UUID
    var endedBy: EndReason?
}
