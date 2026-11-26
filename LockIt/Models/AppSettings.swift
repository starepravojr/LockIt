import Foundation

struct AppSettings: Codable, Equatable {
    /// While bricked, no app can be deleted and Emergency Unbrick is hidden.
    var strictMode = false
}
