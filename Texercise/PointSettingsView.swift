import SwiftUI

struct PointSettingsView: View {
    @EnvironmentObject var pointSettings: PointSettingsStore
    @Environment(\.dismiss) private var dismiss

    // Snapshot of the screen-time-related values as they were when this screen
    // opened. Used to decide whether DeviceActivity needs re-registering.
    @State private var initialLimit: Int? = nil
    @State private var initialPenalty: Int? = nil

    private let appGroup = "group.com.samring.texercise"

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Customize how many activities equal 1 point")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Section("Steps") {
                    HStack {
                        Text("Steps per point")
                        Spacer()
                        Stepper("\(pointSettings.settings.stepsPerPoint)",
                               value: $pointSettings.settings.stepsPerPoint,
                               in: 10...1000,
                               step: 10)
                    }

                    Text("Every \(pointSettings.settings.stepsPerPoint) steps = 1 point")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Exercises") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Pushups")
                            Spacer()
                            Stepper("\(pointSettings.settings.pushupsPerPoint)",
                                   value: $pointSettings.settings.pushupsPerPoint,
                                   in: 1...50)
                        }
                        Text("Every \(pointSettings.settings.pushupsPerPoint) rep\(pointSettings.settings.pushupsPerPoint == 1 ? "" : "s") = 1 point")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()

                        HStack {
                            Text("Squats")
                            Spacer()
                            Stepper("\(pointSettings.settings.squatsPerPoint)",
                                   value: $pointSettings.settings.squatsPerPoint,
                                   in: 1...50)
                        }
                        Text("Every \(pointSettings.settings.squatsPerPoint) rep\(pointSettings.settings.squatsPerPoint == 1 ? "" : "s") = 1 point")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()

                        HStack {
                            Text("Sit-ups")
                            Spacer()
                            Stepper("\(pointSettings.settings.situpsPerPoint)",
                                   value: $pointSettings.settings.situpsPerPoint,
                                   in: 1...50)
                        }
                        Text("Every \(pointSettings.settings.situpsPerPoint) rep\(pointSettings.settings.situpsPerPoint == 1 ? "" : "s") = 1 point")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()

                        HStack {
                            Text("Lunges")
                            Spacer()
                            Stepper("\(pointSettings.settings.lungeRepsPerPoint)",
                                   value: $pointSettings.settings.lungeRepsPerPoint,
                                   in: 1...50)
                        }
                        Text("Every \(pointSettings.settings.lungeRepsPerPoint) rep\(pointSettings.settings.lungeRepsPerPoint == 1 ? "" : "s") = 1 point")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()

                        HStack {
                            Text("Plank")
                            Spacer()
                            Stepper("\(pointSettings.settings.plankSecondsPerPoint)",
                                   value: $pointSettings.settings.plankSecondsPerPoint,
                                   in: 1...60)
                        }
                        Text("Every \(pointSettings.settings.plankSecondsPerPoint) second\(pointSettings.settings.plankSecondsPerPoint == 1 ? "" : "s") = 1 point")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Workouts") {
                    HStack {
                        Text("Minutes per point")
                        Spacer()
                        Stepper("\(pointSettings.settings.workoutMinutesPerPoint)",
                               value: $pointSettings.settings.workoutMinutesPerPoint,
                               in: 1...30)
                    }

                    Text("Every \(pointSettings.settings.workoutMinutesPerPoint) minute\(pointSettings.settings.workoutMinutesPerPoint == 1 ? "" : "s") = 1 point")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Screen Time Penalty") {
                    HStack {
                        Text("Minutes per penalty")
                        Spacer()
                        Stepper("\(pointSettings.settings.screenTimeMinutesPerPenalty)",
                               value: $pointSettings.settings.screenTimeMinutesPerPenalty,
                               in: 1...30)
                    }

                    Text("Every \(pointSettings.settings.screenTimeMinutesPerPenalty) minute\(pointSettings.settings.screenTimeMinutesPerPenalty == 1 ? "" : "s") = -1 point")
                        .font(.caption)
                        .foregroundColor(.secondary)
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

                Section {
                    Button(role: .destructive) {
                        pointSettings.settings = .default
                    } label: {
                        HStack {
                            Spacer()
                            Text("Reset to Defaults")
                            Spacer()
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Values:")
                            .font(.headline)
                        Text("• 100 steps = 1 point")
                        Text("• 1 rep = 1 point (pushups)")
                        Text("• 1 rep = 1 point (squats)")
                        Text("• 1 rep = 1 point (sit-ups)")
                        Text("• 1 rep = 1 point (lunges)")
                        Text("• 6 seconds = 1 point (plank)")
                        Text("• 1 workout minute = 1 point")
                        Text("• 1 screen time minute = -1 point")
                        Text("• No daily screen time limit")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Point Values")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
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

        // PointSettingsStore has already mirrored the new values into the App
        // Group, so the extension's lockout check is current either way. Only
        // the registered threshold events need a restart to change.
        guard !hasTrackedScreenTimeToday else {
            print("⏳ Screen time settings changed but tracking already active today — new thresholds apply tomorrow")
            return
        }

        Task { @MainActor in
            let categoryStore = ScreenTimeCategoryStore.shared
            guard categoryStore.hasSelection else {
                print("⏳ Screen time settings changed but no apps selected — nothing to restart")
                return
            }

            print("⚡️ Screen time settings changed with a clean log — restarting monitoring now")
            AppBlockingManager.shared.startAutoMonitoring(
                selection: categoryStore.activitySelection,
                minutesPerPenalty: pointSettings.settings.screenTimeMinutesPerPenalty,
                maxDailyMinutes: pointSettings.settings.maxDailyScreenTimeMinutes
            )
        }

        initialLimit = pointSettings.settings.maxDailyScreenTimeMinutes
        initialPenalty = pointSettings.settings.screenTimeMinutesPerPenalty
    }
}

#Preview {
    PointSettingsView()
        .environmentObject(PointSettingsStore())
}
