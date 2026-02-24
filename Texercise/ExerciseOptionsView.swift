import SwiftUI

struct ExerciseOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var exerciseStore: ExerciseStore
    
    @State private var selectedExerciseType: String?
    @State private var showingLiveCapture = false
    @State private var showingManualEntry = false
    
    private let exerciseTypes = ["Pushups", "Squats", "Sit-ups", "Lunges", "Plank"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Choose Exercise Type")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // Exercise type selection
                VStack(spacing: 12) {
                    ForEach(exerciseTypes, id: \.self) { type in
                        Button {
                            selectedExerciseType = type
                        } label: {
                            HStack {
                                Image(systemName: iconForExercise(type))
                                    .frame(width: 30)
                                Text(type)
                                Spacer()
                                if selectedExerciseType == type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding()
                            .background(
                                selectedExerciseType == type ?
                                Color.accentColor.opacity(0.2) :
                                Color(.secondarySystemBackground)
                            )
                            .cornerRadius(12)
                        }
                        .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        showingLiveCapture = true
                    } label: {
                        HStack {
                            Image(systemName: "video.fill")
                            Text("Live Capture")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedExerciseType != nil ? Color.accentColor : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(selectedExerciseType == nil)
                    
                    Button {
                        showingManualEntry = true
                    } label: {
                        HStack {
                            Image(systemName: "hand.tap.fill")
                            Text("Manual Entry")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedExerciseType != nil ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(selectedExerciseType == nil)
                }
                .padding()
            }
            .navigationTitle("Log Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showingLiveCapture) {
                if let exerciseType = selectedExerciseType {
                    LiveRepCaptureView(exerciseType: exerciseType, initialReps: 0) { totalReps in
                        // Log directly after live capture
                        exerciseStore.logExercise(type: exerciseType, count: totalReps, date: Date())
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                if let exerciseType = selectedExerciseType {
                    ManualExerciseEntryView(exerciseType: exerciseType)
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
    ExerciseOptionsView()
        .environmentObject(ExerciseStore())
}
