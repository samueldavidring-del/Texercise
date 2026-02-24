import SwiftUI

struct PointSettingsView: View {
    @EnvironmentObject var pointSettings: PointSettingsStore
    @Environment(\.dismiss) private var dismiss
    
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
                            Text("Pushups/Squats/Sit-ups")
                            Spacer()
                            Stepper("\(pointSettings.settings.repsPerPoint)",
                                   value: $pointSettings.settings.repsPerPoint,
                                   in: 1...50)
                        }
                        
                        Text("Every \(pointSettings.settings.repsPerPoint) rep\(pointSettings.settings.repsPerPoint == 1 ? "" : "s") = 1 point")
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
                        Text("• 10 reps = 1 point (pushups/squats/sit-ups)")
                        Text("• 10 reps = 1 point (lunges)")
                        Text("• 6 seconds = 1 point (plank)")
                        Text("• 1 workout minute = 1 point")
                        Text("• 15 screen time minutes = -1 point")
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
        }
    }
}

#Preview {
    PointSettingsView()
        .environmentObject(PointSettingsStore())
}
