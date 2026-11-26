import SwiftUI

/// The list of schedules: add, edit, delete.
struct SchedulesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if model.schedules.isEmpty {
                    ContentUnavailableView(
                        "No schedules",
                        systemImage: "clock",
                        description: Text("A schedule locks your apps at the same time every day, without you opening LockIt.")
                    )
                } else {
                    List(model.schedules) { schedule in
                        NavigationLink {
                            ScheduleEditorView(schedule: schedule)
                        } label: {
                            ScheduleRow(schedule: schedule, modeName: modeName(for: schedule))
                        }
                    }
                }
            }
            .navigationTitle("Schedules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        ScheduleEditorView(schedule: nil)
                    } label: {
                        Label("New schedule", systemImage: "plus")
                    }
                }
            }
        }
    }

    private func modeName(for schedule: LockSchedule) -> String {
        model.modes.first { $0.id == schedule.modeID }?.name ?? "Deleted mode"
    }
}

private struct ScheduleRow: View {
    let schedule: LockSchedule
    let modeName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(modeName)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .opacity(schedule.isEnabled ? 1 : 0.5)
    }

    private var detail: String {
        let times = "\(LockSchedule.timeText(schedule.startMinuteOfDay)) to \(LockSchedule.timeText(schedule.endMinuteOfDay))"
        if !schedule.isEnabled { return "\(times), off" }
        return "\(times), \(schedule.requiresCard ? "until card tap" : "ends automatically")"
    }
}

/// Creates or edits a schedule: its mode, daily time range, and what happens
/// when the time range ends.
struct ScheduleEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft: LockSchedule?
    @State private var errorMessage: String?

    private let existing: LockSchedule?

    init(schedule: LockSchedule?) {
        existing = schedule
        _draft = State(initialValue: schedule)
    }

    var body: some View {
        Group {
            if let draft {
                form(for: draft)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(existing == nil ? "New schedule" : "Edit schedule")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // A new schedule needs a mode from the model, which is not
            // available until the view is in the hierarchy.
            if draft == nil, let mode = model.activeMode {
                draft = .startingSoon(modeID: mode.id)
            }
        }
        .errorAlert($errorMessage)
    }

    private func form(for schedule: LockSchedule) -> some View {
        let binding = Binding<LockSchedule>(
            get: { draft ?? schedule },
            set: { draft = $0 }
        )
        return Form {
            Section {
                Picker("Mode", selection: binding.modeID) {
                    ForEach(model.modes) { mode in
                        Text(mode.name).tag(mode.id)
                    }
                }
            }

            Section {
                DatePicker("Starts", selection: time(binding.startMinuteOfDay), displayedComponents: .hourAndMinute)
                DatePicker("Ends", selection: time(binding.endMinuteOfDay), displayedComponents: .hourAndMinute)
            } footer: {
                Text(schedule.endsNextDay ? "Repeats every day. Ends the next day." : "Repeats every day.")
            }

            Section("When it ends") {
                Picker("When it ends", selection: binding.requiresCard) {
                    Text("Stay locked until I tap my card").tag(true)
                    Text("Unlock automatically").tag(false)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {
                Toggle("Enabled", isOn: binding.isEnabled)
            }

            if let note = note(for: schedule) {
                Section {
                    Label(note, systemImage: "exclamationmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if existing != nil {
                Section {
                    Button("Delete schedule", role: .destructive) {
                        model.deleteSchedule(schedule)
                        dismiss()
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save(schedule) }
                    .disabled(schedule.validationError != nil)
            }
        }
    }

    /// The reason it can't be saved, or a warning that saving locks now.
    private func note(for schedule: LockSchedule) -> String? {
        if let error = schedule.validationError { return error }
        if schedule.isEnabled, schedule.contains(.now) {
            return "It's inside this time range right now, so saving will lock your apps straight away."
        }
        return nil
    }

    private func save(_ schedule: LockSchedule) {
        do {
            try model.saveSchedule(schedule)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Edits a minute-of-day value through a time-only date picker.
    private func time(_ minuteOfDay: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { LockSchedule.date(forMinuteOfDay: minuteOfDay.wrappedValue) },
            set: { minuteOfDay.wrappedValue = LockSchedule.minuteOfDay(for: $0) }
        )
    }
}

extension LockSchedule {
    /// A one-hour schedule starting 15 minutes from now.
    static func startingSoon(modeID: UUID, now: Date = .now) -> LockSchedule {
        // Round up to the next whole minute so the start is never in the past.
        let start = (minuteOfDay(for: now) + minimumMinutes + 1) % (24 * 60)
        return LockSchedule(
            modeID: modeID,
            startMinuteOfDay: start,
            endMinuteOfDay: (start + 60) % (24 * 60)
        )
    }

    static func minuteOfDay(for date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    static func date(forMinuteOfDay minute: Int, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: .now) ?? .now
    }

    /// The time in the user's own format, for example "22:00" or "10:00 PM".
    static func timeText(_ minuteOfDay: Int) -> String {
        date(forMinuteOfDay: minuteOfDay).formatted(date: .omitted, time: .shortened)
    }
}
