import SwiftUI

struct PlankTimerView: View {
    let initialSeconds: Int
    let onComplete: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var elapsedSeconds: Int = 0
    @State private var isRunning: Bool = false
    @State private var timer: Timer? = nil
    @State private var showingEditScreen = false

    private var pointsEarned: Int { elapsedSeconds / 6 }

    private var timeFormatted: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("Plank")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(20)
                }
                .padding()

                Spacer()

                // Timer display
                VStack(spacing: 16) {
                    Text(timeFormatted)
                        .font(.system(size: 96, weight: .bold, design: .monospaced))
                        .foregroundColor(isRunning ? .green : .white)
                        .shadow(color: isRunning ? .green.opacity(0.4) : .clear, radius: 20)

                    Text(elapsedSeconds == 1 ? "second" : "seconds")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.6))

                    if elapsedSeconds > 0 {
                        Text("+\(pointsEarned) pts")
                            .font(.headline)
                            .foregroundColor(.green)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(20)
                    }
                }

                Spacer()

                // Tip
                Text(isRunning ? "Tap Stop when you're done" : elapsedSeconds == 0 ? "Tap Start when you're in position" : "Tap Start to resume")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 12)

                // Controls
                HStack(spacing: 20) {
                    // Reset
                    Button {
                        stopTimer()
                        elapsedSeconds = 0
                    } label: {
                        Text("Reset")
                            .font(.headline)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .opacity(elapsedSeconds > 0 ? 1 : 0.4)
                    .disabled(elapsedSeconds == 0)

                    // Start / Stop
                    Button {
                        if isRunning { stopTimer() } else { startTimer() }
                    } label: {
                        Text(isRunning ? "Stop" : "Start")
                            .font(.title2.bold())
                            .padding(.horizontal, 40)
                            .padding(.vertical, 14)
                            .background(isRunning ? Color.orange : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }

                    // Done
                    Button {
                        stopTimer()
                        showingEditScreen = true
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(Color.blue.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .opacity(elapsedSeconds > 0 ? 1 : 0.4)
                    .disabled(elapsedSeconds == 0)
                }
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            stopTimer()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sheet(isPresented: $showingEditScreen) {
            EditCapturedRepsView(
                exerciseType: "Plank",
                capturedCount: elapsedSeconds,
                initialReps: initialSeconds
            ) { finalSeconds in
                onComplete(finalSeconds)
                dismiss()
            }
        }
    }

    private func startTimer() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    private func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    PlankTimerView(initialSeconds: 0) { seconds in
        print("Plank: \(seconds) seconds")
    }
}
