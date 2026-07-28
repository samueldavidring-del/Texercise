import Vision
import CoreGraphics
import Foundation

struct PushupDetector {
    
    /// Head-on detection (phone propped facing user in portrait).
    ///
    /// Requirements for a valid pushup frame:
    /// 1. Both shoulders visible and wide apart (confirms head-on, not side view)
    /// 2. Both wrists visible at roughly shoulder height (body is horizontal)
    /// 3. Down = nose Y is at or below wrist Y level
    /// 4. Up  = nose Y is clearly above wrist Y level
    static func detectPushup(observation: VNHumanBodyPoseObservation) -> Bool? {
        guard let points = try? observation.recognizedPoints(.all) else { return nil }
        
        guard let leftShoulder  = getPoint(points, .leftShoulder,  minConfidence: 0.4),
              let rightShoulder = getPoint(points, .rightShoulder, minConfidence: 0.4),
              let leftWrist     = getPoint(points, .leftWrist,     minConfidence: 0.4),
              let rightWrist    = getPoint(points, .rightWrist,    minConfidence: 0.4),
              let nose          = getPoint(points, .nose,          minConfidence: 0.4) else {
            return nil
        }
        
        // 1. Shoulders must be wide — confirms head-on view
        let shoulderWidth = abs(Double(leftShoulder.x) - Double(rightShoulder.x))
        guard shoulderWidth > 0.30 else {
            return nil
        }
        
        let shoulderCenterY = (Double(leftShoulder.y) + Double(rightShoulder.y)) / 2
        let wristCenterY    = (Double(leftWrist.y)    + Double(rightWrist.y))    / 2
        let noseY           = Double(nose.y)
        
        // 2. Wrists must be close to shoulder height — confirms body is horizontal.
        // If shoulders are much higher than wrists, user is upright (not in pushup).
        let shoulderWristDiff = shoulderCenterY - wristCenterY
        guard shoulderWristDiff < 0.25 else { return nil }
        
        // 3. Wrists must be in the lower portion of the frame (rules out arms raised while standing)
        guard wristCenterY < 0.65 else { return nil }
        
        // 4. Down = nose at or below wrist level (nose-to-wrist diff < 0.10)
        //    Up   = nose clearly above wrists
        let noseToWristDiff = noseY - wristCenterY
        let isDown = noseToWristDiff < 0.10
        
        print("💪 Pushup — noseToWrist: \(String(format: "%.2f", noseToWristDiff)) shoulderWidth: \(String(format: "%.2f", shoulderWidth)) isDown: \(isDown)")
        return isDown
    }
    
    private static func getPoint(_ points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
                                 _ joint: VNHumanBodyPoseObservation.JointName,
                                 minConfidence: Float = 0.4) -> CGPoint? {
        guard let point = points[joint], point.confidence > minConfidence else { return nil }
        return CGPoint(x: point.location.x, y: point.location.y)
    }
}
