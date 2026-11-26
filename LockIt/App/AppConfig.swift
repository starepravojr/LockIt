import Foundation

/// Identifiers shared by the app and its extensions.
/// `appGroupID` must match the App Group in every target's entitlements.
enum AppConfig {
    static let appGroupID = "group.com.starepravo.lockit"
    static let managedSettingsStoreName = "lockit"
    static let keychainService = "com.starepravo.lockit"
    static let stateChangeNotification = "com.starepravo.lockit.stateChanged"
}
