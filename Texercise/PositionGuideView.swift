import SwiftUI

struct PositionGuideView: View {
    let exerciseType: String
    let onDismiss: () -> Void
    
    private var guideText: String {
        switch exerciseType.lowercased() {
        case "plank":
            return "Position phone to the SIDE\n\nMake sure your:\n• Shoulders\n• Elbows\n• Hips\n\nare ALL visible\n\n(Feet can be out of frame)"
        case "lunges":
            return "Face SIDEWAYS to the camera\n\nMake sure your:\n• Hips\n• Both knees\n\nare visible\n\nStep forward slowly\nAlternate legs"
        case "pushups", "push-ups":
            return "Position phone to the SIDE\n\nKeep your full body visible\nGo all the way down\nFully extend arms up"
        case "squats":
            return "Face the camera directly\n\nKeep your full body visible\nGo below parallel\nFully stand up"
        case "sit-ups", "situps":
            return "Position phone to the SIDE\n\nKeep torso and legs visible\nCome all the way up\nGo all the way down"
        default:
            return "Keep your full body visible\nPerform the exercise with full range of motion"
        }
    }
    
    private var iconName: String {
        switch exerciseType.lowercased() {
        case "plank":
            return "figure.core.training"
        case "lunges":
            return "figure.walk"
        case "pushups", "push-ups":
            return "figure.strengthtraining.traditional"
        case "squats":
            return "figure.strengthtraining.functional"
        case "sit-ups", "situps":
            return "figure.core.training"
        default:
            return "figure.walk"
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 32) {
                Image(systemName: iconName)
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                
                Text("Position Guide")
                    .font(.title.bold())
                    .foregroundColor(.white)
                
                Text(guideText)
                    .font(.title3)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .padding(.horizontal, 40)
                
                Button {
                    onDismiss()
                } label: {
                    Text("Got It!")
                        .font(.headline)
                        .frame(maxWidth: 200)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.top, 20)
            }
        }
    }
}

#Preview {
    PositionGuideView(exerciseType: "Plank") {
        print("Guide dismissed")
    }
}
