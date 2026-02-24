import SwiftUI

struct EditCapturedRepsView: View {
    let exerciseType: String
    let capturedCount: Int
    let initialReps: Int
    let onSave: (Int) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var editedCount: Int
    
    init(exerciseType: String, capturedCount: Int, initialReps: Int, onSave: @escaping (Int) -> Void) {
        self.exerciseType = exerciseType
        self.capturedCount = capturedCount
        self.initialReps = initialReps
        self.onSave = onSave
        _editedCount = State(initialValue: initialReps + capturedCount)
    }
    
    private var isPlank: Bool {
        exerciseType.lowercased().contains("plank")
    }
    
    private var unitText: String {
        isPlank ? (editedCount == 1 ? "second" : "seconds") : "reps"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                
                VStack(spacing: 12) {
                    Text(exerciseType)
                        .font(.title.bold())
                    
                    if capturedCount > 0 {
                        Text("Detected: \(capturedCount) \(isPlank ? (capturedCount == 1 ? "second" : "seconds") : "reps")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 40)
                
                // Big number display
                VStack(spacing: 8) {
                    Text("\(editedCount)")
                        .font(.system(size: 100, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    
                    Text(unitText)
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                
                // Adjustment controls
                VStack(spacing: 20) {
                    HStack(spacing: 40) {
                        Button {
                            if editedCount > 0 {
                                editedCount -= 10
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                        }
                        .disabled(editedCount < 10)
                        
                        Button {
                            if editedCount > 0 {
                                editedCount -= 1
                            }
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                        }
                        .disabled(editedCount == 0)
                        
                        Button {
                            editedCount += 1
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                        }
                        
                        Button {
                            editedCount += 10
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                        }
                    }
                    
                    HStack {
                        Text("-10")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50)
                        
                        Text("-1")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50)
                        
                        Text("+1")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50)
                        
                        Text("+10")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50)
                    }
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        onSave(editedCount)
                    } label: {
                        Text("Log \(editedCount) \(exerciseType)")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(editedCount > 0 ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(editedCount == 0)
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Back to Capture")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal)
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    EditCapturedRepsView(
        exerciseType: "Pushups",
        capturedCount: 25,
        initialReps: 0
    ) { count in
        print("Logging \(count) reps")
    }
}
