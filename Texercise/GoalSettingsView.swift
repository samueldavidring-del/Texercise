import SwiftUI

struct GoalSettingsView: View {
    @EnvironmentObject var goalSettings: GoalSettingsStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Choose which goals to track. Only enabled goals will show progress rings.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Section("Steps Goal") {
                    Toggle(isOn: $goalSettings.goals.stepsGoalEnabled) {
                        HStack {
                            Image(systemName: "figure.walk")
                                .foregroundColor(.green)
                                .frame(width: 30)
                            Text("Track Steps Goal")
                        }
                    }
                    
                    if goalSettings.goals.stepsGoalEnabled {
                        Stepper("Target: \(goalSettings.goals.dailyStepsGoal) steps",
                               value: $goalSettings.goals.dailyStepsGoal,
                               in: 1000...50000,
                               step: 1000)
                    }
                }
                
                Section("Points Goal") {
                    Toggle(isOn: $goalSettings.goals.pointsGoalEnabled) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            Text("Track Points Goal")
                        }
                    }
                    
                    if goalSettings.goals.pointsGoalEnabled {
                        Stepper("Target: \(goalSettings.goals.dailyPointsGoal) points",
                               value: $goalSettings.goals.dailyPointsGoal,
                               in: 10...500,
                               step: 10)
                    }
                }
                
                Section("Workout Minutes Goal") {
                    Toggle(isOn: $goalSettings.goals.workoutGoalEnabled) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.orange)
                                .frame(width: 30)
                            Text("Track Workout Goal")
                        }
                    }
                    
                    if goalSettings.goals.workoutGoalEnabled {
                        Stepper("Target: \(goalSettings.goals.dailyWorkoutMinutesGoal) minutes",
                               value: $goalSettings.goals.dailyWorkoutMinutesGoal,
                               in: 5...300,
                               step: 5)
                    }
                }
                
                Section("Exercise Reps Goal") {
                    Toggle(isOn: $goalSettings.goals.exerciseGoalEnabled) {
                        HStack {
                            Image(systemName: "dumbbell.fill")
                                .foregroundColor(.purple)
                                .frame(width: 30)
                            Text("Track Exercise Goal")
                        }
                    }
                    
                    if goalSettings.goals.exerciseGoalEnabled {
                        Stepper("Target: \(goalSettings.goals.dailyExerciseRepsGoal) reps",
                               value: $goalSettings.goals.dailyExerciseRepsGoal,
                               in: 10...500,
                               step: 10)
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        goalSettings.goals = .default
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
                        Text("Default Goals:")
                            .font(.headline)
                        Text("• All goals disabled by default")
                        Text("• 10,000 steps per day")
                        Text("• 100 points per day")
                        Text("• 30 workout minutes per day")
                        Text("• 50 exercise reps per day")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Daily Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    GoalSettingsView()
        .environmentObject(GoalSettingsStore())
}
