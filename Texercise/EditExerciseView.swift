import SwiftUI

struct EditExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var exerciseStore: ExerciseStore
    
    let exercise: ExerciseEntry
    
    @State private var count: Int
    @State private var selectedDate: Date
    @State private var type: String
    
    init(exercise: ExerciseEntry) {
        self.exercise = exercise
        _count = State(initialValue: Int(exercise.count))
        _selectedDate = State(initialValue: exercise.timestamp ?? Date())
        _type = State(initialValue: exercise.type ?? "Exercise")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Exercise") {
                    HStack {
                        Image(systemName: iconForExercise(type))
                        Text(type)
                            .font(.headline)
                    }
                }
                
                Section("Details") {
                    Stepper("Count: \(count)", value: $count, in: 1...1000)
                    DatePicker("Date", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section {
                    Button("Save Changes") {
                        updateExercise()
                    }
                    .frame(maxWidth: .infinity)
                    
                    Button("Delete", role: .destructive) {
                        deleteExercise()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func updateExercise() {
        exerciseStore.updateExercise(exercise, type: type, count: count, date: selectedDate)
        dismiss()
    }
    
    private func deleteExercise() {
        exerciseStore.deleteExercise(exercise)
        dismiss()
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
            return "figure.strengthtraining.traditional"
        }
    }
}

#Preview {
    let context = PersistenceController.shared.container.viewContext
    let exercise = ExerciseEntry(context: context)
    exercise.id = UUID()
    exercise.type = "Pushups"
    exercise.count = 20
    exercise.timestamp = Date()
    
    return EditExerciseView(exercise: exercise)
        .environmentObject(ExerciseStore())
}
