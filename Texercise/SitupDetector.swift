import Vision
import CoreGraphics
import Foundation

struct SitupDetector {

    // MARK: - Public API

    static func detectSitup(observation: VNHumanBodyPoseObservation) -> Bool? {
        guard let points = try? observation.recognizedPoints(.all) else { return nil }

        // Use shoulder midpoint instead of neck — more reliably detected
        guard let leftShoulder  = getPoint(points, .leftShoulder,  minConfidence: 0.2),
              let rightShoulder = getPoint(points, .rightShoulder, minConfidence: 0.2),
              let leftHip       = getPoint(points, .leftHip,       minConfidence: 0.2),
              let rightHip      = getPoint(points, .rightHip,      minConfidence: 0.2),
              let leftKnee      = getPoint(points, .leftKnee,      minConfidence: 0.2),
              let rightKnee     = getPoint(points, .rightKnee,     minConfidence: 0.2) else {
            return nil
        }

        let shoulderMid = midpoint(leftShoulder, rightShoulder)
        let hipMid      = midpoint(leftHip, rightHip)
        let kneeMid     = midpoint(leftKnee, rightKnee)

        // Torso angle: shoulder → hip → knee
        // In the "up" position (crunch) the torso folds toward the knees,
        // making this angle smaller (more acute).
        let torsoAngle = angle(p1: shoulderMid, p2: hipMid, p3: kneeMid)

        // In Vision coordinates y=0 is at the BOTTOM of the frame (y increases upward).
        // When lying flat, shoulders and hips have similar y.
        // When sitting up (crunching), shoulders rise — their y value INCREASES
        // relative to hips. So sitting up = shoulderMid.y > hipMid.y.
        let shouldersAboveHips = shoulderMid.y > hipMid.y

        // Angle threshold: lying flat ≈ 150–170°, sitting up ≈ 50–90°.
        // Use 110° as the threshold — clear crunch without being too demanding.
        let isCrunched = torsoAngle < 110

        print("🏋️ Situp — torsoAngle=\(Int(torsoAngle))° shouldersAboveHips=\(shouldersAboveHips) isCrunched=\(isCrunched)")

        return isCrunched && shouldersAboveHips
    }

    // MARK: - Helpers

    private static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    private static func getPoint(
        _ points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
        _ joint: VNHumanBodyPoseObservation.JointName,
        minConfidence: Float = 0.2
    ) -> CGPoint? {
        guard let point = points[joint], point.confidence > minConfidence else { return nil }
        return CGPoint(x: point.location.x, y: point.location.y)
    }

    private static func angle(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> Double {
        let v1 = CGVector(dx: p1.x - p2.x, dy: p1.y - p2.y)
        let v2 = CGVector(dx: p3.x - p2.x, dy: p3.y - p2.y)
        let dot  = v1.dx * v2.dx + v1.dy * v2.dy
        let mag1 = sqrt(v1.dx * v1.dx + v1.dy * v1.dy)
        let mag2 = sqrt(v2.dx * v2.dx + v2.dy * v2.dy)
        guard mag1 > 0, mag2 > 0 else { return 180 }
        let cosTheta = max(-1, min(1, dot / (mag1 * mag2)))
        return acos(cosTheta) * 180 / Double.pi
    }
}
