import Vision
import CoreGraphics
import Foundation

struct LungeDetector {
    
    static func detectLunge(observation: VNHumanBodyPoseObservation) -> Bool? {
        guard let points = try? observation.recognizedPoints(.all) else {
            return nil
        }
        
        // Get key points with higher confidence for reliability
        guard let lHip = getPoint(points, .leftHip, minConfidence: 0.4),
              let lKnee = getPoint(points, .leftKnee, minConfidence: 0.4),
              let lAnkle = getPoint(points, .leftAnkle, minConfidence: 0.4),
              let rHip = getPoint(points, .rightHip, minConfidence: 0.4),
              let rKnee = getPoint(points, .rightKnee, minConfidence: 0.4),
              let rAnkle = getPoint(points, .rightAnkle, minConfidence: 0.4) else {
            return nil
        }
        
        // Calculate knee angles
        let leftKneeAngle = angle(p1: lHip, p2: lKnee, p3: lAnkle)
        let rightKneeAngle = angle(p1: rHip, p2: rKnee, p3: rAnkle)
        
        // Require a VERY clear lunge position:
        // One leg very bent (< 95°) and one very straight (> 155°)
        let leftDeepBent = leftKneeAngle < 95
        let rightDeepBent = rightKneeAngle < 95
        let leftVeryStraight = leftKneeAngle > 155
        let rightVeryStraight = rightKneeAngle > 155
        
        // Must have clear distinction
        let isLunge = (leftDeepBent && rightVeryStraight) || (rightDeepBent && leftVeryStraight)
        
        return isLunge
    }
    
    private static func getPoint(_ points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
                                _ joint: VNHumanBodyPoseObservation.JointName,
                                minConfidence: Float = 0.4) -> CGPoint? {
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
