import SwiftUI

struct ExerciseLogView: View {
    @EnvironmentObject var exerciseStore: ExerciseStore
    @Environment(\.dismiss) private var dismiss

    @State private var exerciseType: String = "Pushups"
    @State private var count: Int = 0

    private let exerciseTypes = [
        "Pushups",
        "Squats",
        "Sit-ups"
    ]

    var body: some View {
        NavigationView {
            Form {
                Section("Exercise") {
                    Picker("Type", selection: $exerciseType) {
                        ForEach(exerciseTypes, id: \.self) { type in
                            Text(type)
                        }
                    }

                    Stepper("Reps: \(count)", value: $count, in: 0...500)
                }

                Section {
                    Button("Log Exercise") {
                        exerciseStore.logExercise(
                            type: exerciseType,
                            count: count,
                            date: Date()
                        )
                        dismiss()
                    }
                    .disabled(count == 0)
                }
            }
            .navigationTitle("Log Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ExerciseLogView()
        .environmentObject(ExerciseStore())
}

