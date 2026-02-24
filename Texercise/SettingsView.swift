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
                
                Section("Exercise Points") {
                    HStack {
                        Text("Pushups/Squats/Sit-ups")
                        Spacer()
                        TextField("Reps", value: $pointSettings.settings.repsPerPoint, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("reps = 1 pt")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("Lunges")
                        Spacer()
                        TextField("Reps", value: $pointSettings.settings.lungeRepsPerPoint, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("reps = 1 pt")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("Plank")
                        Spacer()
                        TextField("Seconds", value: $pointSettings.settings.plankSecondsPerPoint, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("sec = 1 pt")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
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
