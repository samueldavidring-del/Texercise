import Vision
import CoreGraphics
import Foundation

struct SitupDetector {
    
    static func detectSitup(observation: VNHumanBodyPoseObservation) -> Bool? {
        guard let points = try? observation.recognizedPoints(.all) else {
            return nil
        }
        
        // Get key points
        guard let nose = getPoint(points, .nose, minConfidence: 0.3),
              let neck = getPoint(points, .neck, minConfidence: 0.3),
              let leftHip = getPoint(points, .leftHip, minConfidence: 0.3),
              let rightHip = getPoint(points, .rightHip, minConfidence: 0.3),
              let leftKnee = getPoint(points, .leftKnee, minConfidence: 0.3),
              let rightKnee = getPoint(points, .rightKnee, minConfidence: 0.3) else {
            return nil
        }
        
        // Calculate hip center
        let hipCenter = CGPoint(
            x: (leftHip.x + rightHip.x) / 2,
            y: (leftHip.y + rightHip.y) / 2
        )
        
        // Calculate knee center
        let kneeCenter = CGPoint(
            x: (leftKnee.x + rightKnee.x) / 2,
            y: (leftKnee.y + rightKnee.y) / 2
        )
        
        // Use neck for better tracking
        let torsoAngle = angle(p1: neck, p2: hipCenter, p3: kneeCenter)
        
        // Crunch up position: torso lifted (< 100°)
        let isUp = torsoAngle < 100
        
        return isUp
    }
    
    private static func getPoint(_ points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
                                _ joint: VNHumanBodyPoseObservation.JointName,
                                minConfidence: Float = 0.3) -> CGPoint? {
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
