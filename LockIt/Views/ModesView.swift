import SwiftUI

/// The list of modes: add, edit, delete.
struct ModesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.modes) { mode in
                        NavigationLink {
                            ModeEditorView(mode: mode, title: "Edit mode") { model.save($0) }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.name)
                                Text(Self.detail(for: mode))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .deleteDisabled(!model.canDelete(mode))
                    }
                    .onDelete { offsets in
                        offsets.map { model.modes[$0] }.forEach(model.deleteMode)
                    }
                } footer: {
                    Text("Swipe to delete. Your only mode, and a mode that a schedule uses, can't be deleted.")
                }
            }
            .navigationTitle("Modes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        ModeEditorView(mode: nil, title: "New mode") { model.save($0) }
                    } label: {
                        Label("New mode", systemImage: "plus")
                    }
                }
            }
        }
    }

    private static func detail(for mode: BrickMode) -> String {
        if mode.isAllowlist {
            return mode.hasEmptySelection ? "Blocks everything" : "Blocks everything except \(mode.selectionSummary)"
        }
        return "Blocks \(mode.selectionSummary)"
    }
}
