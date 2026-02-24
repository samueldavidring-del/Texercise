import Vision
import CoreGraphics
import Foundation

struct PlankDetector {
    
    static func detectPlank(observation: VNHumanBodyPoseObservation) -> Bool? {
        guard let points = try? observation.recognizedPoints(.all) else {
            return nil
        }
        
        // Check what we can see
        let leftShoulder = getPoint(points, .leftShoulder, minConfidence: 0.3)
        let rightShoulder = getPoint(points, .rightShoulder, minConfidence: 0.3)
        let leftElbow = getPoint(points, .leftElbow, minConfidence: 0.3)
        let rightElbow = getPoint(points, .rightElbow, minConfidence: 0.3)
        let leftHip = getPoint(points, .leftHip, minConfidence: 0.3)
        let rightHip = getPoint(points, .rightHip, minConfidence: 0.3)
        
        let lShoulderVisible = leftShoulder != nil
        let rShoulderVisible = rightShoulder != nil
        let lElbowVisible = leftElbow != nil
        let rElbowVisible = rightElbow != nil
        let lHipVisible = leftHip != nil
        let rHipVisible = rightHip != nil
        
        print("👁️ Plank visibility - LShoulder: \(lShoulderVisible), RShoulder: \(rShoulderVisible), LElbow: \(lElbowVisible), RElbow: \(rElbowVisible), LHip: \(lHipVisible), RHip: \(rHipVisible)")
        
        guard let lShoulder = leftShoulder,
              let rShoulder = rightShoulder,
              let lHip = leftHip,
              let rHip = rightHip else {
            print("❌ Plank: Missing required points")
            return nil
        }
        
        // Calculate center points
        let shoulderCenter = CGPoint(
            x: (lShoulder.x + rShoulder.x) / 2,
            y: (lShoulder.y + rShoulder.y) / 2
        )
        let hipCenter = CGPoint(
            x: (lHip.x + rHip.x) / 2,
            y: (lHip.y + rHip.y) / 2
        )
        
        // Simple check: shoulders and hips should be roughly level
        let verticalDiff = abs(shoulderCenter.y - hipCenter.y)
        
        print("📏 Plank vertical diff: \(verticalDiff) (should be < 0.3)")
        
        let isPlank = verticalDiff < 0.3
        
        if isPlank {
            print("✅ PLANK DETECTED!")
        }
        
        return isPlank
    }
    
    private static func getPoint(_ points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
                                _ joint: VNHumanBodyPoseObservation.JointName,
                                minConfidence: Float = 0.3) -> CGPoint? {
        guard let point = points[joint], point.confidence > minConfidence else {
            return nil
        }
        return CGPoint(x: point.location.x, y: point.location.y)
    }
}
