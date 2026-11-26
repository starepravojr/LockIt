import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The screen iOS shows over a blocked app or website.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        locked
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        locked
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        locked
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        locked
    }

    /// iOS always shows one button on a shield. Without a shield action
    /// extension it only closes the blocked app, so it is labelled as that.
    private var locked: ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterial,
            icon: UIImage(systemName: "lock.fill")?
                .withTintColor(.label, renderingMode: .alwaysOriginal),
            title: .init(text: "Locked", color: .label),
            subtitle: .init(text: "Go find your card.", color: .secondaryLabel),
            primaryButtonLabel: .init(text: "Close", color: .systemBackground),
            primaryButtonBackgroundColor: .label
        )
    }
}
