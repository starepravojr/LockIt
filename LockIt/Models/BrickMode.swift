import FamilyControls
import Foundation

/// A named set of apps, categories and websites to block.
struct BrickMode: Codable, Identifiable, Equatable {
    /// Apple does not shield anything when a block list holds more than this
    /// many individual apps. Categories do not count toward the limit.
    static let maxBlockedApps = 50

    var id = UUID()
    var name: String
    var selection = FamilyActivitySelection()
    /// When true, everything is blocked except the selected apps and websites.
    var isAllowlist = false

    var hasEmptySelection: Bool {
        selection.applicationTokens.isEmpty
            && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
    }

    /// Why this mode cannot be saved, or nil when it can.
    var validationError: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Give the mode a name."
        }
        if isAllowlist { return nil }
        if hasEmptySelection {
            return "Choose at least one app, category or website to block."
        }
        if selection.applicationTokens.count > Self.maxBlockedApps {
            return "iOS can block at most \(Self.maxBlockedApps) individually chosen apps. Select whole categories instead."
        }
        return nil
    }
}
