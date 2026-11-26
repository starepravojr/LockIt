import Foundation

struct AppSettings: Codable, Equatable {
    /// While locked, no app can be deleted and Emergency Unlock is hidden.
    var strictMode = false
}
