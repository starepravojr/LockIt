import FamilyControls
import SwiftUI

/// Chooses between onboarding and the home screen, and watches for the user
/// revoking Screen Time access while bricked.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(AuthorizationService.self) private var authorization
    @Environment(\.scenePhase) private var scenePhase

    private var isSetUp: Bool {
        authorization.isApproved && model.pairedCardUID != nil && !model.modes.isEmpty
    }

    var body: some View {
        Group {
            // While bricked, stay on Home even if access looks revoked: the
            // bypass check below decides what happens next.
            if model.state.isBricked || isSetUp {
                HomeView()
            } else {
                OnboardingView()
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let notice = model.notice {
                NoticeBanner(text: notice) { model.dismissNotice() }
            }
        }
        // Runs at launch, each time the app becomes active, and whenever the
        // authorization status changes.
        .task(id: BypassCheckTrigger(phase: scenePhase, status: authorization.status)) {
            await checkForBypass()
        }
        // A schedule can brick or unbrick while the app is on screen.
        .onReceive(
            NotificationCenter.default.publisher(for: StateChangeSignal.didChange).receive(on: RunLoop.main)
        ) { _ in
            withAnimation { model.reload() }
        }
    }

    private func checkForBypass() async {
        guard scenePhase == .active else { return }
        model.reload()
        authorization.refresh()
        guard model.state.isBricked, !authorization.isApproved else { return }

        // The status can read as not approved for a moment after a cold
        // launch, so confirm it before charging the user for a bypass. A
        // status change in the meantime cancels this task and starts a new one.
        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled else { return }
        authorization.refresh()
        guard !authorization.isApproved else { return }

        withAnimation { model.endBrickAfterAccessRevoked() }
    }
}

private struct BypassCheckTrigger: Equatable {
    let phase: ScenePhase
    let status: AuthorizationStatus
}

private struct NoticeBanner: View {
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { Divider() }
    }
}
