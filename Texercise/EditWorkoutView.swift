import SwiftUI
import HealthKit

struct EditWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var healthStore: HealthStore
    
    let workout: WorkoutSummary
    
    @State private var durationHours: Int
    @State private var durationMinutes: Int
    @State private var durationSeconds: Int
    @State private var distance: Double
    @State private var selectedDate: Date
    
    init(workout: WorkoutSummary) {
        self.workout = workout
        let totalSecs = Int(workout.durationSeconds)
        _durationHours   = State(initialValue: totalSecs / 3600)
        _durationMinutes = State(initialValue: (totalSecs % 3600) / 60)
        _durationSeconds = State(initialValue: totalSecs % 60)
        _distance        = State(initialValue: workout.distanceMiles ?? 0.0)
        _selectedDate    = State(initialValue: workout.startDate)
    }
    
    private var totalDurationSeconds: Double {
        Double(durationHours * 3600 + durationMinutes * 60 + durationSeconds)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Workout") {
                    HStack {
                        Image(systemName: iconForWorkoutType(workout.activityType))
                        Text(workout.activityName)
                            .font(.headline)
                    }
                }
                
                Section("Duration") {
                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Stepper("\(durationHours)", value: $durationHours, in: 0...23)
                            Text("hours")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(spacing: 4) {
                            Stepper("\(durationMinutes)", value: $durationMinutes, in: 0...59)
                            Text("minutes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(spacing: 4) {
                            Stepper("\(durationSeconds)", value: $durationSeconds, in: 0...59)
                            Text("seconds")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Text("Total")
                            .foregroundColor(.secondary)
                        Spacer()
                        let h = durationHours
                        let m = durationMinutes
                        let s = durationSeconds
                        Text(h > 0
                             ? String(format: "%d:%02d:%02d", h, m, s)
                             : String(format: "%d:%02d", m, s))
                            .bold()
                            .foregroundColor(.blue)
                    }
                }
                
                if workout.distanceMiles != nil {
                    Section("Distance") {
                        HStack {
                            Text("Distance")
                            Spacer()
                            TextField("Miles", value: $distance, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("mi")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Date") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section {
                    Button("Save Changes") {
                        updateWorkout()
                    }
                    .disabled(totalDurationSeconds == 0)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func updateWorkout() {
        healthStore.deleteWorkout(workout)
        let activityType = HKWorkoutActivityType(rawValue: workout.activityType) ?? .other
        healthStore.logWorkout(
            activityType: activityType,
            durationSeconds: totalDurationSeconds,
            distanceMiles: distance > 0 ? distance : nil,
            date: selectedDate
        )
        dismiss()
    }
    
    private func iconForWorkoutType(_ type: UInt) -> String {
        switch type {
        case HKWorkoutActivityType.running.rawValue: return "figure.run"
        case HKWorkoutActivityType.cycling.rawValue: return "bicycle"
        case HKWorkoutActivityType.swimming.rawValue: return "figure.pool.swim"
        case HKWorkoutActivityType.walking.rawValue: return "figure.walk"
        case HKWorkoutActivityType.hiking.rawValue: return "figure.hiking"
        default: return "figure.mixed.cardio"
        }
    }
}
