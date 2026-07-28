import SwiftUI

struct ManualExerciseEntryView: View {
    let exerciseType: String
    
    @EnvironmentObject var exerciseStore: ExerciseStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var count = 10
    @State private var selectedDate = Date()
    @State private var showingDatePicker = false
    
    private var isPlank: Bool {
        exerciseType.lowercased().contains("plank")
    }
    
    private var unitText: String {
        isPlank ? (count == 1 ? "second" : "seconds") : "reps"
    }
    
    private var maxValue: Int {
        isPlank ? 300 : 200
    }
    
    private var dateLabel: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "Today"
        }
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: selectedDate)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                
                // Exercise type header
                VStack(spacing: 8) {
                    Image(systemName: iconForExercise(exerciseType))
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)
                    Text(exerciseType)
                        .font(.title.bold())
                }
                .padding(.top, 32)
                
                // Big number display
                VStack(spacing: 8) {
                    Text("\(count)")
                        .font(.system(size: 100, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                        .animation(.none, value: count)
                    
                    Text(unitText)
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                
                // Adjustment controls
                VStack(spacing: 20) {
                    HStack(spacing: 40) {
                        Button {
                            if count >= 10 { count -= 10 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                        }
                        .disabled(count < 10)
                        
                        Button {
                            if count > 0 { count -= 1 }
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                        }
                        .disabled(count == 0)
                        
                        Button {
                            if count < maxValue { count += 1 }
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                        }
                        .disabled(count >= maxValue)
                        
                        Button {
                            if count <= maxValue - 10 { count += 10 }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                        }
                        .disabled(count > maxValue - 10)
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
                
                // Date picker
                Button {
                    showingDatePicker.toggle()
                } label: {
                    HStack {
                        Image(systemName: "calendar")
                        Text(dateLabel)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .rotationEffect(.degrees(showingDatePicker ? 180 : 0))
                    }
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(20)
                }
                
                if showingDatePicker {
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding(.horizontal)
                        .transition(.opacity)
                }
                
                Spacer()
                
                // Save button
                VStack(spacing: 12) {
                    Button {
                        exerciseStore.logExercise(
                            type: exerciseType,
                            count: count,
                            date: selectedDate
                        )
                        dismiss()
                    } label: {
                        Text("Log \(count) \(exerciseType)")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(count > 0 ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(count == 0)
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal)
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
