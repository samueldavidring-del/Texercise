import SwiftUI
import Vision

struct PoseOverlayView: View {
    let observation: VNHumanBodyPoseObservation?
    let viewSize: CGSize
    
    var body: some View {
        Canvas { context, size in
            guard let obs = observation else { return }
            guard let points = try? obs.recognizedPoints(.all) else { return }
            
            // Define skeleton connections
            let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
                // Head to shoulders
                (.nose, .neck),
                (.neck, .leftShoulder),
                (.neck, .rightShoulder),
                
                // Left arm
                (.leftShoulder, .leftElbow),
                (.leftElbow, .leftWrist),
                
                // Right arm
                (.rightShoulder, .rightElbow),
                (.rightElbow, .rightWrist),
                
                // Torso
                (.leftShoulder, .leftHip),
                (.rightShoulder, .rightHip),
                (.leftHip, .rightHip),
                
                // Left leg
                (.leftHip, .leftKnee),
                (.leftKnee, .leftAnkle),
                
                // Right leg
                (.rightHip, .rightKnee),
                (.rightKnee, .rightAnkle)
            ]
            
            // Draw connections
            for (start, end) in connections {
                guard let startPoint = points[start],
                      let endPoint = points[end],
                      startPoint.confidence > 0.2,
                      endPoint.confidence > 0.2 else {
                    continue
                }
                
                let startPos = CGPoint(
                    x: CGFloat(startPoint.x) * size.width,
                    y: (1 - CGFloat(startPoint.y)) * size.height
                )
                let endPos = CGPoint(
                    x: CGFloat(endPoint.x) * size.width,
                    y: (1 - CGFloat(endPoint.y)) * size.height
                )
                
                var path = Path()
                path.move(to: startPos)
                path.addLine(to: endPos)
                
                context.stroke(
                    path,
                    with: .color(.green),
                    lineWidth: 3
                )
            }
            
            // Draw joints
            for (_, point) in points {
                guard point.confidence > 0.2 else { continue }
                
                let pos = CGPoint(
                    x: CGFloat(point.x) * size.width,
                    y: (1 - CGFloat(point.y)) * size.height
                )
                
                context.fill(
                    Circle().path(in: CGRect(x: pos.x - 5, y: pos.y - 5, width: 10, height: 10)),
                    with: .color(.white)
                )
            }
        }
    }
}
