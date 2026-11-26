import FamilyControls
import ManagedSettings

/// The only place that touches `ManagedSettingsStore`.
struct BlockingService {
    private let store = ManagedSettingsStore(named: .init(AppConfig.managedSettingsStoreName))

    /// Shields the mode's selection. Every setting is written so that nothing
    /// from a previously applied mode is left behind.
    ///
    /// `strictMode` stops the user deleting any app while the shields are up,
    /// which is the only way iOS offers to protect this app from removal.
    func apply(_ mode: BrickMode, strictMode: Bool) {
        store.application.denyAppRemoval = strictMode ? true : nil

        let selection = mode.selection
        if mode.isAllowlist {
            store.shield.applications = nil
            store.shield.applicationCategories = .all(except: selection.applicationTokens)
            store.shield.webDomains = nil
            store.shield.webDomainCategories = .all(except: selection.webDomainTokens)
        } else {
            let categories = selection.categoryTokens
            store.shield.applications = selection.applicationTokens.nilIfEmpty
            store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
            store.shield.webDomains = selection.webDomainTokens.nilIfEmpty
            store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
        }
    }

    func clear() {
        store.clearAllSettings()
    }
}

private extension Set {
    var nilIfEmpty: Self? { isEmpty ? nil : self }
}
