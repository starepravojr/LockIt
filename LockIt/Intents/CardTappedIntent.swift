import AppIntents

/// The action a Shortcuts automation runs when the user's card is scanned:
/// "When NFC tag is scanned, Card Tapped". It lets a tap lock the apps
/// without the user opening LockIt and pressing the button first.
///
/// Shortcuts does not pass on which card was scanned, so this action is only
/// trusted to lock, which it does before bringing LockIt to the front to show
/// the result. If the apps are already locked it brings LockIt to the front,
/// where the app's own scan checks the card before unlocking.
struct CardTappedIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Card Tapped"
    static let description = IntentDescription(
        "Locks your apps and opens LockIt. If they are already locked, opens LockIt to scan your card and unlock."
    )

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }

    @MainActor
    func perform() async throws -> some IntentResult {
        let model = AppModel.shared
        model.reload()

        if model.state.isLocked {
            guard model.requestScanFromShortcut() else { return .result() }
            do {
                try await bringAppToFront()
            } catch {
                model.cancelScanRequest()
                throw error
            }
        } else {
            guard await AuthorizationService.shared.waitUntilApproved() else {
                throw CardTapError.screenTimeOff
            }
            // The lock is already in place by the time the app opens, so a
            // refusal to open it is not a failure.
            if try model.lockFromShortcut() {
                try? await bringAppToFront()
            }
        }
        return .result()
    }

    private func bringAppToFront() async throws {
        if #available(iOS 26.0, *) {
            try await continueInForeground(alwaysConfirm: false)
        } else {
            try await requestToContinueInForeground()
        }
    }
}

enum CardTapError: Error, CustomLocalizedStringResourceConvertible {
    case setupIncomplete
    case screenTimeOff

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .setupIncomplete: "Open LockIt and finish setting it up first."
        case .screenTimeOff: "LockIt doesn't have Screen Time access. Open LockIt to allow it."
        }
    }
}
