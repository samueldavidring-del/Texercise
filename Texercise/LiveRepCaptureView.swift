import SwiftUI
import Vision

struct LiveRepCaptureView: View {
    let exerciseType: String
    let initialReps: Int
    let onComplete: (Int) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var capturedReps: Int = 0
    @State private var currentPose: VNHumanBodyPoseObservation?
    @State private var showingEditScreen = false
    @State private var showingGuide = true
    
    private var isPlank: Bool {
        exerciseType.lowercased().contains("plank")
    }
    
    private var isLunge: Bool {
        exerciseType.lowercased().contains("lunge")
    }
    
    private var displayText: String {
        if isPlank {
            return "\(capturedReps)"
        } else {
            return "\(capturedReps)"
        }
    }
    
    private var unitText: String {
        if isPlank {
            return capturedReps == 1 ? "second" : "seconds"
        } else {
            return "reps"
        }
    }
    
    private var pointsEarned: Int {
        if isPlank {
            // Every 6 seconds = 1 point
            return capturedReps / 6
        } else {
            // Standard rep counting
            return capturedReps
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera view - always running
                PoseCameraRepCounterView(
                    exerciseType: exerciseType,
                    isRunning: .constant(true), // Always on
                    reps: $capturedReps,
                    currentPose: $currentPose
                )
                .edgesIgnoringSafeArea(.all)
                
                // Pose overlay
                PoseOverlayView(observation: currentPose, viewSize: geometry.size)
                    .edgesIgnoringSafeArea(.all)
                
                // Position Guide Overlay
                if showingGuide {
                    PositionGuideView(
                        exerciseType: exerciseType,
                        onDismiss: {
                            withAnimation {
                                showingGuide = false
                            }
                        }
                    )
                }
                
                // Overlay UI
                VStack {
                    // Top bar
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Text(exerciseType)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Button {
                                withAnimation {
                                    showingGuide.toggle()
                                }
                            } label: {
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                    }
                    .padding()
                    
                    // Detection indicator
                    if !showingGuide {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(currentPose != nil ? Color.green : Color.red)
                                .frame(width: 12, height: 12)
                            
                            Text(currentPose != nil ? "Detecting" : "Position yourself")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    // Counter display
                    if !showingGuide {
                        VStack(spacing: 8) {
                            Text(displayText)
                                .font(.system(size: 120, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 4)
                            
                            Text(unitText)
                                .font(.title2)
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 2)
                            
                            if isPlank {
                                Text("\(pointsEarned) points")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                    
                    // Control buttons
                    if !showingGuide {
                        HStack(spacing: 20) {
                            Button {
                                capturedReps = 0
                            } label: {
                                Text("Reset")
                                    .font(.headline)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            
                            Button {
                                showingEditScreen = true
                            } label: {
                                Text("Done")
                                    .font(.headline)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            print("📸 LiveRepCaptureView appeared for: \(exerciseType)")
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            print("📸 LiveRepCaptureView disappeared")
        }
        .sheet(isPresented: $showingEditScreen) {
            EditCapturedRepsView(
                exerciseType: exerciseType,
                capturedCount: capturedReps,
                initialReps: initialReps
            ) { finalCount in
                onComplete(finalCount)
                dismiss()
            }
        }
    }
}

#Preview {
    LiveRepCaptureView(exerciseType: "Plank", initialReps: 0) { reps in
        print("Captured \(reps) reps")
    }
}
