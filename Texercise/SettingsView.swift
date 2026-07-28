import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var pointSettings: PointSettingsStore
    @EnvironmentObject var goalSettings: GoalSettingsStore
    
    @State private var showingScreenTimePicker = false
    
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
                        let log = UserDefaults(suiteName: "group.com.samring.texercise")?.string(forKey: "sharedDebugLog") ?? "empty"
                        UIPasteboard.general.string = log
                    }
                    Button("Clear Debug Log") {
                        UserDefaults(suiteName: "group.com.samring.texercise")?.removeObject(forKey: "sharedDebugLog")
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
        }
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
