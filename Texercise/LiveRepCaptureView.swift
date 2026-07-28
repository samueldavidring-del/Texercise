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
    @State private var isLandscape = false
    @State private var plankFeedback: PlankFormFeedback = .notDetected
    @State private var isActivePlank: Bool = false
    
    private var requiresLandscape: Bool {
        let t = exerciseType.lowercased()
        return t.contains("sit-up") || t.contains("situp")
    }
    
    private var isPlank: Bool { false } // Plank now uses PlankTimerView
    
    private var unitText: String {
        isPlank ? (capturedReps == 1 ? "second" : "seconds") : "reps"
    }
    
    private var pointsEarned: Int {
        isPlank ? capturedReps / 6 : capturedReps
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                PoseCameraRepCounterView(
                    exerciseType: exerciseType,
                    isRunning: .constant(true),
                    reps: $capturedReps,
                    currentPose: $currentPose,
                    onPlankFeedbackUpdate: { feedback in
                        plankFeedback = feedback
                        isActivePlank = (feedback == .valid)
                    }
                )
                .edgesIgnoringSafeArea(.all)
                
                PoseOverlayView(observation: currentPose, viewSize: geometry.size)
                    .edgesIgnoringSafeArea(.all)
                
                // Landscape prompt for horizontal exercises
                if requiresLandscape && !isLandscape {
                    landscapePrompt
                } else {
                    // Normal UI
                    if showingGuide {
                        PositionGuideView(
                            exerciseType: exerciseType,
                            onDismiss: { withAnimation { showingGuide = false } }
                        )
                    }
                    
                    VStack {
                        // Top bar
                        HStack {
                            Button { dismiss() } label: {
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
                                    withAnimation { showingGuide.toggle() }
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
                            
                            // Plank form feedback — only show when not actively holding plank
                            if isPlank, let message = plankFeedback.message, capturedReps == 0 || !isActivePlank {
                                Text(message)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.yellow)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(12)
                                    .transition(.opacity)
                                    .animation(.easeInOut(duration: 0.3), value: plankFeedback.message)
                            }
                        }
                        
                        Spacer()
                        
                        if !showingGuide {
                            VStack(spacing: 4) {
                                Text("\(capturedReps)")
                                    .font(.system(size: isLandscape ? 72 : 120, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 4)
                                
                                Text(unitText)
                                    .font(isLandscape ? .headline : .title2)
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 2)
                                
                                if isPlank {
                                    Text("\(pointsEarned) points")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(Color.black.opacity(0.6))
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.bottom, isLandscape ? 8 : 40)
                        }
                        
                        if !showingGuide {
                            HStack(spacing: 20) {
                                Button {
                                    capturedReps = 0
                                } label: {
                                    Text("Reset")
                                        .font(.headline)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, isLandscape ? 8 : 12)
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
                                        .padding(.vertical, isLandscape ? 8 : 12)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                            }
                            .padding(.bottom, isLandscape ? 8 : 40)
                        }
                    }
                }
            }
            .onAppear {
                updateOrientation(size: geometry.size)
            }
            .onChange(of: geometry.size) { newSize in
                updateOrientation(size: newSize)
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            if requiresLandscape {
                AppOrientationHelper.lockLandscape()
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            AppOrientationHelper.unlockPortrait()
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
    
    private var landscapePrompt: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                Image(systemName: "rectangle.landscape.rotate")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(isLandscape ? 0 : 0))
                
                Text("Rotate to Landscape")
                    .font(.title.bold())
                    .foregroundColor(.white)
                
                Text("\(exerciseType) works best with your phone sideways so the camera can see your full body.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button {
                    // Allow them to proceed anyway
                    showingGuide = true
                    isLandscape = true
                } label: {
                    Text("Continue Anyway")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 8)
                }
                
                Button { dismiss() } label: {
                    Text("Go Back")
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private func updateOrientation(size: CGSize) {
        isLandscape = size.width > size.height
    }
}

// Helper to manage orientation locking
enum AppOrientationHelper {
    static func lockLandscape() {
        if #available(iOS 16.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
            }
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
        }
        AppDelegate.orientationLock = .landscape
    }
    
    static func unlockPortrait() {
        if #available(iOS 16.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        }
        AppDelegate.orientationLock = .portrait
    }
}

#Preview {
    LiveRepCaptureView(exerciseType: "Plank", initialReps: 0) { reps in
        print("Captured \(reps) reps")
    }
}
