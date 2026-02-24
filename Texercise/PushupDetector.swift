import Vision
import CoreGraphics
import Foundation

struct PushupDetector {
    
    static func detectPushup(observation: VNHumanBodyPoseObservation) -> Bool? {
        guard let points = try? observation.recognizedPoints(.all) else {
            return nil
        }
        
        // Get key points with very low confidence threshold
        guard let leftShoulder = getPoint(points, .leftShoulder, minConfidence: 0.15),
              let leftElbow = getPoint(points, .leftElbow, minConfidence: 0.15),
              let leftWrist = getPoint(points, .leftWrist, minConfidence: 0.15),
              let rightShoulder = getPoint(points, .rightShoulder, minConfidence: 0.15),
              let rightElbow = getPoint(points, .rightElbow, minConfidence: 0.15),
              let rightWrist = getPoint(points, .rightWrist, minConfidence: 0.15) else {
            return nil
        }
        
        // Calculate elbow angles
        let leftAngle = angle(p1: leftShoulder, p2: leftElbow, p3: leftWrist)
        let rightAngle = angle(p1: rightShoulder, p2: rightElbow, p3: rightWrist)
        
        // Average the angles
        let avgAngle = (leftAngle + rightAngle) / 2
        
        // Down position: arms bent (< 130° - very lenient)
        let isDown = avgAngle < 130
        
        return isDown
    }
    
    private static func getPoint(_ points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
                                _ joint: VNHumanBodyPoseObservation.JointName,
                                minConfidence: Float = 0.15) -> CGPoint? {
        guard let point = points[joint], point.confidence > minConfidence else {
            return nil
        }
        return CGPoint(x: point.location.x, y: point.location.y)
    }
    
    private static func angle(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> Double {
        let v1 = CGVector(dx: p1.x - p2.x, dy: p1.y - p2.y)
        let v2 = CGVector(dx: p3.x - p2.x, dy: p3.y - p2.y)
        
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let mag1 = sqrt(v1.dx * v1.dx + v1.dy * v1.dy)
        let mag2 = sqrt(v2.dx * v2.dx + v2.dy * v2.dy)
        
        let cosTheta = dot / (mag1 * mag2)
        let theta = acos(max(-1, min(1, cosTheta)))
        
        return theta * 180 / Double.pi
    }
}
