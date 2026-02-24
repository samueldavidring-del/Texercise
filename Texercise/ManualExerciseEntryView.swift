import SwiftUI

struct ManualExerciseEntryView: View {
    let exerciseType: String
    
    @EnvironmentObject var exerciseStore: ExerciseStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var count = 10
    @State private var selectedDate = Date()
    
    private var isPlank: Bool {
        exerciseType.lowercased().contains("plank")
    }
    
    private var countLabel: String {
        if isPlank {
            return "Seconds: \(count)"
        } else {
            return "Count: \(count)"
        }
    }
    
    private var maxValue: Int {
        isPlank ? 300 : 100  // 5 minutes max for plank
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Exercise") {
                    HStack {
                        Image(systemName: iconForExercise(exerciseType))
                        Text(exerciseType)
                            .font(.headline)
                    }
                }
                
                Section("Details") {
                    Stepper(countLabel, value: $count, in: 1...maxValue)
                    DatePicker("Date", selection: $selectedDate, displayedComponents: [.date])
                }
                
                Section {
                    Button("Save") {
                        exerciseStore.logExercise(
                            type: exerciseType,
                            count: count,
                            date: selectedDate
                        )
                        dismiss()
                    }
                }
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func iconForExercise(_ type: String) -> String {
        switch type.lowercased() {
        case "pushups", "push-ups":
            return "figure.strengthtraining.traditional"
        case "squats":
            return "figure.strengthtraining.functional"
        case "sit-ups", "situps":
            return "figure.core.training"
        case "lunges":
            return "figure.walk"
        case "plank":
            return "figure.core.training"
        default:
            return "figure.walk"
        }
    }
}

#Preview {
    ManualExerciseEntryView(exerciseType: "Pushups")
        .environmentObject(ExerciseStore())
}
