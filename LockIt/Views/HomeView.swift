import SwiftUI

/// The locked / unlocked state, the time since locking, the mode chooser,
/// and the one button that starts a card scan.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var isShowingModes = false
    @State private var isShowingSchedules = false
    @State private var isShowingStats = false
    @State private var isShowingSettings = false
    @State private var isScanning = false
    @State private var errorMessage: String?

    private var isLocked: Bool { model.state.isLocked }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Spacer()

                Image(systemName: isLocked ? "lock.fill" : "lock.open")
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(isLocked ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(height: 96)
                    .accessibilityHidden(true)

                Text(isLocked ? "Locked" : "Unlocked")
                    .font(.largeTitle.bold())

                if let lockedAt = model.state.lockedAt, isLocked {
                    Text(lockedAt, style: .timer)
                        .font(.title2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if let mode = model.activeMode {
                    if isLocked {
                        Text(mode.name)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    } else {
                        modeMenu(selected: mode)
                            .padding(.top, 4)
                    }
                }

                if let schedule = model.activeSchedule, !schedule.requiresCard {
                    Text("Unlocks automatically at \(LockSchedule.timeText(schedule.endMinuteOfDay)).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: tapCard) {
                    Text(isLocked ? "Unlock" : "Lock It")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isScanning)

                Text("You'll be asked to tap your card.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") {
                        isShowingSettings = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Stats", systemImage: "chart.bar") {
                        isShowingStats = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schedules", systemImage: "clock") {
                        isShowingSchedules = true
                    }
                    .disabled(isLocked)
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $isShowingModes) {
                ModesView()
            }
            .sheet(isPresented: $isShowingSchedules) {
                SchedulesView()
            }
            .sheet(isPresented: $isShowingStats) {
                StatsView()
            }
            .errorAlert($errorMessage)
        }
    }

    /// Chooses the mode for the next lock. Only shown while unlocked.
    private func modeMenu(selected: LockMode) -> some View {
        Menu {
            Picker("Mode", selection: Binding(
                get: { selected.id },
                set: { model.selectMode($0) }
            )) {
                ForEach(model.modes) { mode in
                    Text(mode.name).tag(mode.id)
                }
            }
            Divider()
            Button("Edit modes", systemImage: "slider.horizontal.3") {
                isShowingModes = true
            }
        } label: {
            HStack(spacing: 6) {
                Text(selected.name)
                Image(systemName: "chevron.up.chevron.down")
                    .imageScale(.small)
            }
            .font(.headline)
        }
        .accessibilityLabel("Mode: \(selected.name)")
    }

    private func tapCard() {
        isScanning = true
        Task {
            do {
                try await model.tapCard()
            } catch {
                errorMessage = error.localizedDescription
            }
            isScanning = false
        }
    }
}
