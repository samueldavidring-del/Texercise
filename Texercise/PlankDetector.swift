import Vision
import CoreGraphics
import Foundation

enum PlankFormFeedback {
    case valid
    case notDetected
    case bodyNotHorizontal  // shoulders/hips/ankles not level
    case hipsToHigh         // downward dog / pike
    
    var message: String? {
        switch self {
        case .valid, .notDetected: return nil
        case .bodyNotHorizontal:   return "Keep your body flat and horizontal"
        case .hipsToHigh:          return "Lower your hips"
        }
    }
}

struct PlankDetector {
    
    static func detectPlankWithFeedback(observation: VNHumanBodyPoseObservation) -> (isPlank: Bool?, feedback: PlankFormFeedback) {
        guard let points = try? observation.recognizedPoints(.all) else {
            return (nil, .notDetected)
        }
        
        let leftShoulder  = getPoint(points, .leftShoulder,  minConfidence: 0.2)
        let rightShoulder = getPoint(points, .rightShoulder, minConfidence: 0.2)
        let leftHip       = getPoint(points, .leftHip,       minConfidence: 0.2)
        let rightHip      = getPoint(points, .rightHip,      minConfidence: 0.2)
        let leftAnkle     = getPoint(points, .leftAnkle,     minConfidence: 0.15)
        let rightAnkle    = getPoint(points, .rightAnkle,    minConfidence: 0.15)
        
        guard let lShoulder = leftShoulder ?? rightShoulder,
              let rShoulder = rightShoulder ?? leftShoulder,
              let lHip      = leftHip ?? rightHip,
              let rHip      = rightHip ?? leftHip else {
            print("🚫 Plank rejected: landmarks not detected")
            return (nil, .notDetected)
        }
        
        let shoulderCenter = CGPoint(
            x: (lShoulder.x + rShoulder.x) / 2,
            y: (lShoulder.y + rShoulder.y) / 2
        )
        let hipCenter = CGPoint(
            x: (lHip.x + rHip.x) / 2,
            y: (lHip.y + rHip.y) / 2
        )
        
        // Primary: shoulders and hips roughly level (horizontal body)
        let shoulderHipDiff = abs(shoulderCenter.y - hipCenter.y)
        
        // Hips too high = downward dog
        if hipCenter.y > shoulderCenter.y + 0.15 {
            print("🚫 Plank rejected: hips too high (diff: \(String(format: "%.2f", hipCenter.y - shoulderCenter.y)))")
            return (nil, .hipsToHigh)
        }
        
        if let lAnkle = leftAnkle ?? rightAnkle,
           let rAnkle = rightAnkle ?? leftAnkle {
            let ankleCenter = CGPoint(
                x: (lAnkle.x + rAnkle.x) / 2,
                y: (lAnkle.y + rAnkle.y) / 2
            )
            let hipAnkleDiff = abs(hipCenter.y - ankleCenter.y)
            let isPlank = shoulderHipDiff < 0.20 && hipAnkleDiff < 0.20
            if !isPlank {
                print("🚫 Plank rejected: not horizontal (shoulderHipDiff: \(String(format: "%.2f", shoulderHipDiff)) hipAnkleDiff: \(String(format: "%.2f", hipAnkleDiff)))")
                return (nil, .bodyNotHorizontal)
            }
            print("✅ Plank valid (with ankles) — shoulderHipDiff: \(String(format: "%.2f", shoulderHipDiff)) hipAnkleDiff: \(String(format: "%.2f", hipAnkleDiff))")
            return (true, .valid)
        }
        
        // Fallback: just shoulders and hips
        let isPlank = shoulderHipDiff < 0.20
        if !isPlank {
            print("🚫 Plank rejected: shoulders/hips not level (diff: \(String(format: "%.2f", shoulderHipDiff)))")
            return (nil, .bodyNotHorizontal)
        }
        print("✅ Plank valid (shoulders+hips) — shoulderHipDiff: \(String(format: "%.2f", shoulderHipDiff))")
        return (true, .valid)
    }
    
    static func detectPlank(observation: VNHumanBodyPoseObservation) -> Bool? {
        return detectPlankWithFeedback(observation: observation).isPlank
    }
    
    private static func getPoint(_ points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
                                 _ joint: VNHumanBodyPoseObservation.JointName,
                                 minConfidence: Float = 0.3) -> CGPoint? {
        guard let point = points[joint], point.confidence > minConfidence else { return nil }
        return CGPoint(x: point.location.x, y: point.location.y)
    }
}
