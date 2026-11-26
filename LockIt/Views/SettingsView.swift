import SwiftUI

/// The paired card, Strict Mode, and Emergency Unlocks.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var isScanning = false
    @State private var isConfirmingEmergency = false
    @State private var errorMessage: String?

    private var isLocked: Bool { model.state.isLocked }

    var body: some View {
        NavigationStack {
            Form {
                cardSection
                strictModeSection
                if model.offersEmergencyUnlock {
                    emergencySection
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Emergency Unlock",
                isPresented: $isConfirmingEmergency,
                titleVisibility: .visible
            ) {
                Button("Unlock without my card", role: .destructive, action: emergencyUnlock)
            } message: {
                Text("You have \(model.emergencyUnlocksRemaining) left. This can't be undone.")
            }
            .errorAlert($errorMessage)
        }
    }

    private var cardSection: some View {
        Section {
            LabeledContent("Paired card") {
                Text(Self.masked(model.pairedCardUID))
                    .monospaced()
            }
            Button("Pair a different card", action: pairCard)
                .disabled(isLocked || isScanning)
        } header: {
            Text("Card")
        } footer: {
            Text("You can change cards only while unlocked.")
        }
    }

    private var strictModeSection: some View {
        Section {
            Toggle("Strict Mode", isOn: Binding(
                get: { model.settings.strictMode },
                set: { model.setStrictMode($0) }
            ))
            .disabled(isLocked)
        } footer: {
            Text("While locked, no app on this iPhone can be deleted, not only LockIt, and Emergency Unlock is hidden. You can change this only while unlocked.")
        }
    }

    private var emergencySection: some View {
        Section {
            LabeledContent("Remaining", value: "\(model.emergencyUnlocksRemaining)")
            Button("Emergency Unlock", role: .destructive) {
                isConfirmingEmergency = true
            }
            .disabled(!model.canEmergencyUnlock)
        } header: {
            Text("Emergency Unlocks")
        } footer: {
            Text("For when you can't get to your card. The count never resets.")
        }
    }

    private func pairCard() {
        isScanning = true
        Task {
            do {
                try await model.pairCard()
            } catch {
                errorMessage = error.localizedDescription
            }
            isScanning = false
        }
    }

    private func emergencyUnlock() {
        do {
            try model.emergencyUnlock()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Shows only the ends of the UID, for example `04A1…E580`.
    private static func masked(_ uid: String?) -> String {
        guard let uid else { return "None" }
        guard uid.count > 8 else { return uid }
        return "\(uid.prefix(4))…\(uid.suffix(4))"
    }
}
