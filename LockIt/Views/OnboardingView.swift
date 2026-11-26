import FamilyControls
import SwiftUI

/// First launch: explain the idea, get Screen Time access, pair the card,
/// create the first mode.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(AuthorizationService.self) private var authorization

    var body: some View {
        if !authorization.isApproved {
            AuthorizationStepView()
        } else if model.pairedCardUID == nil {
            PairCardStepView()
        } else {
            NavigationStack {
                ModeEditorView(mode: nil, title: "Your first mode") { model.save($0) }
            }
        }
    }
}

private struct PairCardStepView: View {
    @Environment(AppModel.self) private var model
    @State private var isScanning = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()

            Image(systemName: "wave.3.right")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Pair your card")
                    .font(.largeTitle.bold())
                Text("This card becomes the only thing that blocks and unblocks your apps.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 18) {
                StepRow(symbol: "creditcard", text: "Use an NTAG215 card. Bank and transit cards won't work.")
                StepRow(symbol: "iphone.radiowaves.left.and.right", text: "Hold the top back edge of your iPhone against it.")
                StepRow(symbol: "arrow.triangle.2.circlepath", text: "You can switch to another card later, but only while unlocked.")
            }

            Spacer()

            Button {
                isScanning = true
                Task {
                    do {
                        try await model.pairCard()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    isScanning = false
                }
            } label: {
                Text("Pair card")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isScanning)
        }
        .padding(24)
        .errorAlert($errorMessage)
    }
}

private struct AuthorizationStepView: View {
    @Environment(AuthorizationService.self) private var authorization
    @State private var isRequesting = false
    @State private var failure: String?

    private var wasDeclined: Bool {
        failure != nil || authorization.status == .denied
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer()

            Image(systemName: "lock.square.stack")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("LockIt")
                    .font(.largeTitle.bold())
                Text("Block distracting apps until you tap your card.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 18) {
                StepRow(symbol: "square.grid.2x2", text: "Pick the apps and websites that distract you.")
                StepRow(symbol: "lock", text: "Tap your card to block them.")
                StepRow(symbol: "lock.open", text: "Tap the same card to get them back. Nothing else unlocks them.")
            }

            Spacer()

            if wasDeclined {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Screen Time access is off", systemImage: "exclamationmark.circle")
                        .font(.headline)
                    Text(failure ?? Self.declinedHelp)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
            } else {
                Text("LockIt uses Screen Time to block apps. Everything stays on this iPhone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button(action: requestAccess) {
                Text(wasDeclined ? "Try again" : "Allow Screen Time access")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isRequesting)
        }
        .padding(24)
    }

    private func requestAccess() {
        isRequesting = true
        Task {
            do {
                try await authorization.request()
                failure = nil
            } catch {
                failure = Self.help(for: error)
            }
            isRequesting = false
        }
    }

    private static let declinedHelp =
        "LockIt can't block anything without it. Tap Try again, choose Continue, then confirm with Face ID or your passcode."

    private static func help(for error: Error) -> String {
        guard let error = error as? FamilyControlsError else {
            return error.localizedDescription
        }
        switch error {
        case .authorizationCanceled:
            return declinedHelp
        case .restricted:
            return "Screen Time is restricted on this iPhone, for example by a parent or a work profile. Lift that restriction in Settings, then try again."
        case .authenticationMethodUnavailable:
            return "Set a passcode in Settings > Face ID & Passcode, then try again. iOS needs it to confirm the request."
        case .authorizationConflict:
            return "Another app or a parental control already manages Screen Time on this iPhone. Remove it, then try again."
        case .invalidAccountType:
            return "This Apple Account can't approve Screen Time access for itself. Sign in with an adult account, then try again."
        case .networkError:
            return "iOS couldn't reach Apple to confirm the request. Check your connection, then try again."
        default:
            return error.localizedDescription
        }
    }
}

private struct StepRow: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Image(systemName: symbol)
                .frame(width: 24)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(text)
        }
    }
}
