import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var pointSettings: PointSettingsStore
    @EnvironmentObject var goalSettings: GoalSettingsStore

    @State private var showingScreenTimePicker = false

    // Snapshot of the screen-time-related values as they were when this screen
    // opened. Used to decide whether DeviceActivity needs re-registering.
    @State private var initialLimit: Int? = nil
    @State private var initialPenalty: Int? = nil

    private let appGroup = "group.com.samring.texercise"

    var body: some View {
        NavigationView {
            Form {
                Section("Steps") {
                    HStack {
                        Text("Steps per point")
                        Spacer()
                        TextField("Steps", value: $pointSettings.settings.stepsPerPoint, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Section("Workouts") {
                    HStack {
                        Text("Minutes per point")
                        Spacer()
                        TextField("Minutes", value: $pointSettings.settings.workoutMinutesPerPoint, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
                Section("Debug") {
                    Button("Copy Debug Log") {
                        let log = UserDefaults(suiteName: appGroup)?.string(forKey: "sharedDebugLog") ?? "empty"
                        UIPasteboard.general.string = log
                    }
                    Button("Clear Debug Log") {
                        UserDefaults(suiteName: appGroup)?.removeObject(forKey: "sharedDebugLog")
                    }
                    .foregroundColor(.red)
                }
                Section("Exercise Points") {
                    ExercisePointRow(label: "Pushups", unit: "reps = 1 pt", value: $pointSettings.settings.pushupsPerPoint)
                    ExercisePointRow(label: "Squats", unit: "reps = 1 pt", value: $pointSettings.settings.squatsPerPoint)
                    ExercisePointRow(label: "Sit-ups", unit: "reps = 1 pt", value: $pointSettings.settings.situpsPerPoint)
                    ExercisePointRow(label: "Lunges", unit: "reps = 1 pt", value: $pointSettings.settings.lungeRepsPerPoint)
                    ExercisePointRow(label: "Plank", unit: "sec = 1 pt", value: $pointSettings.settings.plankSecondsPerPoint)
                }

                Section("Screen Time") {
                    HStack {
                        Text("Minutes per penalty")
                        Spacer()
                        TextField("Minutes", value: $pointSettings.settings.screenTimeMinutesPerPenalty, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    Button {
                        showingScreenTimePicker = true
                    } label: {
                        HStack {
                            Text("Tracked Apps & Categories")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(ScreenTimeCategoryStore.shared.selectionSummary)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Hard daily ceiling — locks apps regardless of points balance.
                MaxDailyLimitSection(settings: $pointSettings.settings)

                // Re-registering DeviceActivity thresholds mid-day resets its
                // cumulative counters and re-fires every event already fired
                // today, which inflates the screen time log. So changes only
                // apply immediately while today's log is still empty.
                if screenTimeSettingsChanged && hasTrackedScreenTimeToday {
                    Section {
                        Label {
                            Text("Screen time changes take effect tomorrow. Today's tracking is already running and restarting it now would double-count the minutes you've already used.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } icon: {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.orange)
                        }
                    }
                }

                Section("Daily Goals") {
                    VStack(spacing: 16) {
                        GoalRow(
                            title: "Steps Goal",
                            isEnabled: $goalSettings.goals.stepsGoalEnabled,
                            value: $goalSettings.goals.dailyStepsGoal,
                            color: .green
                        )

                        GoalRow(
                            title: "Points Goal",
                            isEnabled: $goalSettings.goals.pointsGoalEnabled,
                            value: $goalSettings.goals.dailyPointsGoal,
                            color: .blue
                        )

                        GoalRow(
                            title: "Workout Minutes",
                            isEnabled: $goalSettings.goals.workoutGoalEnabled,
                            value: $goalSettings.goals.dailyWorkoutMinutesGoal,
                            color: .orange
                        )

                        GoalRow(
                            title: "Exercise Reps",
                            isEnabled: $goalSettings.goals.exerciseGoalEnabled,
                            value: $goalSettings.goals.dailyExerciseRepsGoal,
                            color: .purple
                        )
                    }
                }

                Section {
                    Button("Reset to Defaults") {
                        pointSettings.settings = .default
                        goalSettings.goals = .default
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingScreenTimePicker) {
                ScreenTimePickerView()
            }
            .onAppear {
                if initialLimit == nil {
                    initialLimit = pointSettings.settings.maxDailyScreenTimeMinutes
                    initialPenalty = pointSettings.settings.screenTimeMinutesPerPenalty
                }
            }
            .onDisappear {
                applyScreenTimeChangesIfNeeded()
            }
        }
    }

    // MARK: - Screen Time Change Handling

    private var screenTimeSettingsChanged: Bool {
        guard let initialLimit, let initialPenalty else { return false }
        return initialLimit != pointSettings.settings.maxDailyScreenTimeMinutes
            || initialPenalty != pointSettings.settings.screenTimeMinutesPerPenalty
    }

    /// True once DeviceActivity has fired at least one threshold today.
    /// While this is false, monitoring can be restarted with no side effects.
    private var hasTrackedScreenTimeToday: Bool {
        let defaults = UserDefaults(suiteName: appGroup)
        let log = (defaults?.array(forKey: SharedKeys.screenTimeEventLog) as? [String]) ?? []
        return !log.isEmpty
    }

    private func applyScreenTimeChangesIfNeeded() {
        guard screenTimeSettingsChanged else { return }

        // "Minutes per penalty" is a free-text field, so it can briefly be 0.
        // The event count is ceiling / minutesPerPenalty, so never restart
        // monitoring with a value below 1.
        guard pointSettings.settings.screenTimeMinutesPerPenalty >= 1 else {
            print("⚠️ Minutes per penalty is below 1 — not restarting monitoring")
            return
        }

        // PointSettingsStore has already mirrored the new values into the App
        // Group, so the extension's lockout check is current either way. Only
        // the registered threshold events need a restart to change.
        guard !hasTrackedScreenTimeToday else {
            print("⏳ Screen time settings changed but tracking already active today — new thresholds apply tomorrow")
            return
        }

        let minutesPerPenalty = pointSettings.settings.screenTimeMinutesPerPenalty
        let maxDailyMinutes = pointSettings.settings.maxDailyScreenTimeMinutes

        Task { @MainActor in
            let categoryStore = ScreenTimeCategoryStore.shared
            guard categoryStore.hasSelection else {
                print("⏳ Screen time settings changed but no apps selected — nothing to restart")
                return
            }

            print("⚡️ Screen time settings changed with a clean log — restarting monitoring now")
            AppBlockingManager.shared.startAutoMonitoring(
                selection: categoryStore.activitySelection,
                minutesPerPenalty: minutesPerPenalty,
                maxDailyMinutes: maxDailyMinutes
            )
        }

        initialLimit = maxDailyMinutes
        initialPenalty = minutesPerPenalty
    }
}

// MARK: - Reusable exercise point row
struct ExercisePointRow: View {
    let label: String
    let unit: String
    @Binding var value: Int

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit)
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

struct GoalRow: View {
    let title: String
    @Binding var isEnabled: Bool
    @Binding var value: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $isEnabled) {
                Text(title)
                    .font(.subheadline)
            }
            .tint(color)

            if isEnabled {
                HStack {
                    Text("Target:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    TextField("Goal", value: $value, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
        .environmentObject(PointSettingsStore())
        .environmentObject(GoalSettingsStore())
}
