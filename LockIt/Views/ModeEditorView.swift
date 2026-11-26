import FamilyControls
import SwiftUI

/// Creates or edits a mode: its name, what it covers, and whether that is a
/// block list or an allow list.
struct ModeEditorView: View {
    let title: String
    let onSave: (BrickMode) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: BrickMode
    @State private var isPickerPresented = false

    init(mode: BrickMode?, title: String, onSave: @escaping (BrickMode) -> Void) {
        self.title = title
        self.onSave = onSave
        _draft = State(initialValue: mode ?? BrickMode(name: "Focus"))
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $draft.name)
            }

            Section {
                Button {
                    isPickerPresented = true
                } label: {
                    LabeledContent(draft.isAllowlist ? "Allowed" : "Blocked", value: draft.selectionSummary)
                }
                .tint(.primary)

                Toggle("Block everything except these", isOn: $draft.isAllowlist)
            } header: {
                Text("Apps and websites")
            } footer: {
                if let selectionNote {
                    Text(selectionNote)
                }
            }

            if let error = draft.validationError {
                Section {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $draft.selection)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(draft)
                    dismiss()
                }
                .disabled(draft.validationError != nil)
            }
        }
    }

    private var selectionNote: String? {
        guard draft.isAllowlist else { return nil }
        if !draft.selection.categoryTokens.isEmpty {
            return "Whole categories can't be allowed. Open the category and choose the apps to keep, one by one."
        }
        if draft.hasEmptySelection {
            return "Nothing is allowed yet, so this mode blocks every app and website."
        }
        return "Every other app and website is blocked."
    }
}

extension BrickMode {
    /// For example "3 apps, 1 category", or "None".
    var selectionSummary: String {
        func count(_ value: Int, _ singular: String, _ plural: String) -> String? {
            value == 0 ? nil : "\(value) \(value == 1 ? singular : plural)"
        }
        let parts = [
            count(selection.applicationTokens.count, "app", "apps"),
            count(selection.categoryTokens.count, "category", "categories"),
            count(selection.webDomainTokens.count, "website", "websites"),
        ].compactMap { $0 }
        return parts.isEmpty ? "None" : parts.joined(separator: ", ")
    }
}
