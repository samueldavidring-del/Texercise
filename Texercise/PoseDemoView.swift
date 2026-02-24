import SwiftUI

struct PoseDemoView: View {
    let exerciseType: String

    @EnvironmentObject var exerciseStore: ExerciseStore
    @Environment(\.dismiss) private var dismiss

    @State private var reps: Int = 0
    @State private var showingCaptureSheet = false

    var body: some View {
        VStack(spacing: 16) {

            Text(exerciseType)
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .onAppear {
                    print("🎯 PoseDemoView appeared with exerciseType: '\(exerciseType)'")
                }

            Text("Reps")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(reps)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)

            // Manual adjust
            HStack(spacing: 24) {
                Button {
                    reps = max(0, reps - 1)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.largeTitle)
                }

                Button {
                    reps += 1
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.largeTitle)
                }
            }
            .padding(.bottom, 4)

            // Live capture entry
            Button {
                print("🎥 Opening live capture for: '\(exerciseType)'")
                showingCaptureSheet = true
            } label: {
                Text("Live Capture Reps")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }

            Button {
                print("💾 Logging \(reps) \(exerciseType)")
                exerciseStore.logExercise(type: exerciseType, count: reps, date: Date())
                dismiss()
            } label: {
                Text("Log \(reps) \(exerciseType)")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(reps > 0 ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(reps == 0)

            Spacer()
        }
        .padding()
        .fullScreenCover(isPresented: $showingCaptureSheet) {
            LiveRepCaptureView(exerciseType: exerciseType, initialReps: reps) { captured in
                reps = captured
            }
        }
    }
}

#Preview {
    PoseDemoView(exerciseType: "Pushups")
        .environmentObject(ExerciseStore())
}
