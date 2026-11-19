import SwiftUI

struct EditCapturedRepsView: View {
    let exerciseType: String
    let capturedCount: Int
    let initialReps: Int
    let onSave: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
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

    /// Sit-ups run in landscape, and this sheet inherits that. The old
    /// single tall column didn't fit: the title overlapped the number and the
    /// Log button fell off the bottom of the screen.
    private var isCompactHeight: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        Group {
            if isCompactHeight {
                landscapeLayout
            } else {
                portraitLayout
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    // MARK: - Layouts

    private var portraitLayout: some View {
        VStack(spacing: 28) {
            header
                .padding(.top, 32)
            countDisplay(size: 100)
            adjustmentControls
            Spacer()
            actionButtons
                .padding(.bottom, 24)
        }
        .padding(.horizontal)
    }

    private var landscapeLayout: some View {
        HStack(spacing: 32) {
            // Left: what you're logging
            VStack(spacing: 8) {
                header
                countDisplay(size: 72)
            }
            .frame(maxWidth: .infinity)

            // Right: adjust and save
            VStack(spacing: 20) {
                adjustmentControls
                actionButtons
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 6) {
            Text("Review")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
            Text(exerciseType)
                .font(.title2.bold())
            if capturedCount > 0 {
                Text("Detected: \(capturedCount) \(isPlank ? (capturedCount == 1 ? "second" : "seconds") : "reps")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Nothing detected — adjust below")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .multilineTextAlignment(.center)
    }

    private func countDisplay(size: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text("\(editedCount)")
                .font(.system(size: size, weight: .bold, design: .rounded))
                .foregroundColor(.blue)
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(unitText)
                .font(.title3)
                .foregroundColor(.secondary)
        }
    }

    /// Each button carries its own label underneath, so they always line up.
    private var adjustmentControls: some View {
        HStack(spacing: 20) {
            adjustButton(delta: -10, icon: "minus.circle.fill", color: .red)
            adjustButton(delta: -1, icon: "minus.circle", color: .orange)
            adjustButton(delta: 1, icon: "plus.circle", color: .green)
            adjustButton(delta: 10, icon: "plus.circle.fill", color: .green)
        }
    }

    private func adjustButton(delta: Int, icon: String, color: Color) -> some View {
        Button {
            editedCount = max(0, editedCount + delta)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundColor(color)
                Text(delta > 0 ? "+\(delta)" : "\(delta)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 56)
        }
        .buttonStyle(.plain)
        .disabled(delta < 0 && editedCount == 0)
        .opacity(delta < 0 && editedCount == 0 ? 0.4 : 1)
        .accessibilityLabel(delta > 0 ? "Add \(delta)" : "Subtract \(-delta)")
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                onSave(editedCount)
            } label: {
                Text("Log \(editedCount) \(exerciseType)")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, isCompactHeight ? 10 : 14)
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
                    .padding(.vertical, isCompactHeight ? 10 : 14)
                    .background(Color(.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
            }
        }
    }
}

#Preview {
    EditCapturedRepsView(
        exerciseType: "Sit-ups",
        capturedCount: 5,
        initialReps: 0
    ) { count in
        print("Logging \(count) reps")
    }
}
