import SwiftUI
import HealthKit

struct AddWorkoutView: View {
    @EnvironmentObject var healthStore: HealthStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var activityType: HKWorkoutActivityType = .running
    @State private var durationHours = 0
    @State private var durationMinutes = 30
    @State private var durationSeconds = 0
    @State private var distance: Double = 0.0
    @State private var distanceText = ""
    @State private var selectedDate = Date()
    @FocusState private var isDistanceFocused: Bool
    
    private var totalDurationSeconds: Double {
        Double(durationHours * 3600 + durationMinutes * 60 + durationSeconds)
    }
    
    private let activityTypes: [(HKWorkoutActivityType, String, String)] = [
        (.running, "Running", "figure.run"),
        (.walking, "Walking", "figure.walk"),
        (.cycling, "Cycling", "bicycle"),
        (.swimming, "Swimming", "figure.pool.swim"),
        (.hiking, "Hiking", "figure.hiking"),
        (.yoga, "Yoga", "figure.yoga"),
        (.functionalStrengthTraining, "Strength Training", "dumbbell.fill"),
        (.other, "Other", "figure.mixed.cardio")
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Activity Type") {
                    Picker("Type", selection: $activityType) {
                        ForEach(activityTypes, id: \.0.rawValue) { type, name, icon in
                            HStack {
                                Image(systemName: icon)
                                Text(name)
                            }
                            .tag(type)
                        }
                    }
                }
                
                Section("Duration") {
                    HStack(spacing: 16) {
                        // Hours
                        VStack(spacing: 4) {
                            Stepper("\(durationHours)", value: $durationHours, in: 0...23)
                            Text("hours")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Minutes
                        VStack(spacing: 4) {
                            Stepper("\(durationMinutes)", value: $durationMinutes, in: 0...59)
                            Text("minutes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Seconds
                        VStack(spacing: 4) {
                            Stepper("\(durationSeconds)", value: $durationSeconds, in: 0...59)
                            Text("seconds")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // Summary display
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
                
                Section("Distance (Optional)") {
                    HStack {
                        TextField("Miles", text: $distanceText)
                            .keyboardType(.decimalPad)
                            .focused($isDistanceFocused)
                            .onChange(of: distanceText) { _, newValue in
                                let filtered = newValue.filter { "0123456789.".contains($0) }
                                if filtered != newValue { distanceText = filtered }
                                distance = Double(filtered) ?? 0.0
                            }
                        Text("miles")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Date") {
                    DatePicker("Workout Date", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section {
                    Button("Save Workout") {
                        let distanceValue = distance > 0 ? distance : nil
                        healthStore.logWorkout(
                            activityType: activityType,
                            durationSeconds: totalDurationSeconds,
                            distanceMiles: distanceValue,
                            date: selectedDate
                        )
                        dismiss()
                    }
                    .disabled(totalDurationSeconds == 0)
                }
            }
            .navigationTitle("Add Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") { isDistanceFocused = false }
                    }
                }
            }
        }
    }
}

#Preview {
    AddWorkoutView()
        .environmentObject(HealthStore())
}
