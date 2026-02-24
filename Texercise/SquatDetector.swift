import Vision
import CoreGraphics
import Foundation

struct SquatDetector {
    
    static func detectSquat(observation: VNHumanBodyPoseObservation) -> Bool? {
        guard let points = try? observation.recognizedPoints(.all) else {
            return nil
        }
        
        // Get key points
        guard let leftHip = getPoint(points, .leftHip),
              let leftKnee = getPoint(points, .leftKnee),
              let leftAnkle = getPoint(points, .leftAnkle),
              let rightHip = getPoint(points, .rightHip),
              let rightKnee = getPoint(points, .rightKnee),
              let rightAnkle = getPoint(points, .rightAnkle) else {
            return nil
        }
        
        // Calculate knee angles
        let leftAngle = angle(p1: leftHip, p2: leftKnee, p3: leftAnkle)
        let rightAngle = angle(p1: rightHip, p2: rightKnee, p3: rightAnkle)
        
        // Average the angles
        let avgAngle = (leftAngle + rightAngle) / 2
        
        // Squat down position: knees bent (< 120°)
        return avgAngle < 120
    }
    
    private static func getPoint(_ points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
                                _ joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
        guard let point = points[joint], point.confidence > 0.3 else {
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
