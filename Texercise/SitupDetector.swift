import Vision
import CoreGraphics
import Foundation

/// One frame's measurement of the sit-up position.
struct SitupReading {
    /// Shoulder → hip → knee angle in degrees. ~160–180 lying flat,
    /// ~60–100 fully up, ~120–140 for a crunch.
    let torsoAngle: Double
    /// Which side of the body was used ("left", "right" or "both").
    let side: String
    /// Lowest confidence among the three joints used.
    let confidence: Float
}

struct SitupDetector {

    /// Joints below this confidence are ignored.
    static let minConfidence: Float = 0.2

    // MARK: - Public API

    /// Measures the torso angle from whichever side of the body the camera
    /// can actually see. Returns nil when no full shoulder-hip-knee chain is
    /// visible.
    ///
    /// Why this changed (it counted zero reps):
    /// 1. It required BOTH shoulders, hips and knees. With the phone to the
    ///    side, as the guide asks, the far side of the body is hidden, so the
    ///    frame was usually thrown away.
    /// 2. It also required shoulders to be "above" hips on Vision's y axis.
    ///    Sit-ups run in landscape, but the camera feeds Vision a fixed
    ///    portrait image, so "up" in the room is sideways in the image. That
    ///    check depended on which way your head pointed, not on sitting up.
    ///    The angle alone is the same in any orientation, so only it is used.
    static func measure(observation: VNHumanBodyPoseObservation) -> SitupReading? {
        guard let points = try? observation.recognizedPoints(.all) else { return nil }

        let left  = chain(points, .leftShoulder,  .leftHip,  .leftKnee)
        let right = chain(points, .rightShoulder, .rightHip, .rightKnee)

        switch (left, right) {
        case let (l?, r?):
            // Both sides visible (rare from the side) — average them.
            return SitupReading(
                torsoAngle: (l.angle + r.angle) / 2,
                side: "both",
                confidence: min(l.confidence, r.confidence)
            )
        case let (l?, nil):
            return SitupReading(torsoAngle: l.angle, side: "left", confidence: l.confidence)
        case let (nil, r?):
            return SitupReading(torsoAngle: r.angle, side: "right", confidence: r.confidence)
        default:
            return nil
        }
    }

    /// Kept for any older callers: true when clearly in the "up" position.
    static func detectSitup(observation: VNHumanBodyPoseObservation) -> Bool? {
        guard let reading = measure(observation: observation) else { return nil }
        return reading.torsoAngle < PoseRepCounter.situpUpAngle
    }

    // MARK: - Helpers

    private static func chain(
        _ points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
        _ shoulder: VNHumanBodyPoseObservation.JointName,
        _ hip: VNHumanBodyPoseObservation.JointName,
        _ knee: VNHumanBodyPoseObservation.JointName
    ) -> (angle: Double, confidence: Float)? {
        guard let s = points[shoulder], s.confidence > minConfidence,
              let h = points[hip],      h.confidence > minConfidence,
              let k = points[knee],     k.confidence > minConfidence else {
            return nil
        }
        let a = angle(p1: s.location, p2: h.location, p3: k.location)
        return (a, min(s.confidence, h.confidence, k.confidence))
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
