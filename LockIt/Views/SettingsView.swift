import SwiftUI

/// The paired card, Strict Mode, and Emergency Unbricks.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var isScanning = false
    @State private var isConfirmingEmergency = false
    @State private var errorMessage: String?

    private var isBricked: Bool { model.state.isBricked }

    var body: some View {
        NavigationStack {
            Form {
                cardSection
                strictModeSection
                if model.offersEmergencyUnbrick {
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
                "Emergency Unbrick",
                isPresented: $isConfirmingEmergency,
                titleVisibility: .visible
            ) {
                Button("Unbrick without my card", role: .destructive, action: emergencyUnbrick)
            } message: {
                Text("You have \(model.emergencyUnbricksRemaining) left. This can't be undone.")
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
                .disabled(isBricked || isScanning)
        } header: {
            Text("Card")
        } footer: {
            Text("You can change cards only while unbricked.")
        }
    }

    private var strictModeSection: some View {
        Section {
            Toggle("Strict Mode", isOn: Binding(
                get: { model.settings.strictMode },
                set: { model.setStrictMode($0) }
            ))
            .disabled(isBricked)
        } footer: {
            Text("While bricked, no app on this iPhone can be deleted, not only LockIt, and Emergency Unbrick is hidden. You can change this only while unbricked.")
        }
    }

    private var emergencySection: some View {
        Section {
            LabeledContent("Remaining", value: "\(model.emergencyUnbricksRemaining)")
            Button("Emergency Unbrick", role: .destructive) {
                isConfirmingEmergency = true
            }
            .disabled(!model.canEmergencyUnbrick)
        } header: {
            Text("Emergency Unbricks")
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

    private func emergencyUnbrick() {
        do {
            try model.emergencyUnbrick()
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
