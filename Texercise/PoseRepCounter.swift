import Vision
import CoreGraphics
import AudioToolbox
import Foundation

final class PoseRepCounter {
    private var wasInPosition = false
    private var repCount = 0
    var lastPublished = 0
    
    // Plank-specific tracking
    private var plankStartTime: Date?
    private var plankTotalSeconds: Int = 0
    private var plankAccumulatedSeconds: Int = 0
    private var isInPlank = false
    var plankFeedback: PlankFormFeedback = .notDetected
    
    // Plank requires N consecutive valid frames before starting,
    // and N consecutive invalid frames before stopping
    private var consecutiveValidFrames = 0
    private var consecutiveInvalidFrames = 0
    private let plankEntryFrames = 8   // ~0.5s at 15fps — must hold position before counting starts
    private let plankExitFrames  = 30  // ~2s at 15fps — tolerates gaps between valid detections
    
    // Lunge tracking with better debounce
    private var lastLungeDetection = false
    private var lastLungeCountTime: Date?
    private let lungeDebounceDuration: TimeInterval = 2.0  // Longer debounce
    
    // Sit-up tracking: hysteresis between an "up" and a "down" torso angle
    // (shoulder → hip → knee). Lying flat reads ~160–180°.
    /// Torso angle at or below which a rep counts.
    static let situpUpAngle: Double = 115
    /// Torso angle above which you're back down and the next rep can count.
    static let situpDownAngle: Double = 145
    private var situpIsUp = false
    private var situpCycleMinAngle: Double = 180
    private var situpMissingFrames = 0
    private let situpMissingLogFrames = 30   // ~2s at 15fps
    private var lastCrunchCountTime: Date?
    private let crunchDebounceDuration: TimeInterval = 0.5
    
    // Pushup tracking with debounce
    private var lastPushupCountTime: Date?
    private let pushupDebounceDuration: TimeInterval = 0.5
    
    func reset() {
        wasInPosition = false
        repCount = 0
        lastPublished = 0
        plankStartTime = nil
        plankTotalSeconds = 0
        plankAccumulatedSeconds = 0
        isInPlank = false
        lastLungeDetection = false
        lastLungeCountTime = nil
        lastCrunchCountTime = nil
        situpIsUp = false
        situpCycleMinAngle = 180
        situpMissingFrames = 0
        lastPushupCountTime = nil
        consecutiveValidFrames = 0
        consecutiveInvalidFrames = 0
    }
    
    func process(observation: VNHumanBodyPoseObservation, exerciseType: String) -> Int {
        let detected: Bool?
        
        switch exerciseType.lowercased() {
        case "pushups", "push-ups":
            return processPushup(observation: observation)
        case "squats":
            detected = SquatDetector.detectSquat(observation: observation)
        case "sit-ups", "situps":
            return processCrunch(observation: observation)
        case "lunges":
            return processLunge(observation: observation)
        case "plank":
            return processPlank(observation: observation)
        default:
            detected = nil
        }
        
        guard let isInPosition = detected else { return repCount }
        
        // Standard rep counting (transition from not in position -> in position)
        if isInPosition && !wasInPosition {
            repCount += 1
            AudioServicesPlaySystemSound(1520) // Haptic feedback
        }
        wasInPosition = isInPosition
        
        return repCount
    }
    
    private func processPushup(observation: VNHumanBodyPoseObservation) -> Int {
        let isInDownPosition = PushupDetector.detectPushup(observation: observation) ?? false
        
        let now = Date()
        let canCount = lastPushupCountTime == nil || now.timeIntervalSince(lastPushupCountTime!) > pushupDebounceDuration
        
        // Count on transition to down position with debounce
        if isInDownPosition && !wasInPosition && canCount {
            repCount += 1
            lastPushupCountTime = now
            AudioServicesPlaySystemSound(1520)
            print("💪 Pushup counted! Total: \(repCount)")
        }
        
        wasInPosition = isInDownPosition
        return repCount
    }
    
    private func processCrunch(observation: VNHumanBodyPoseObservation) -> Int {
        guard let reading = SitupDetector.measure(observation: observation) else {
            // Body not visible this frame. Keep the current up/down state —
            // a dropped frame mid-rep shouldn't count or cancel anything.
            situpMissingFrames += 1
            if situpMissingFrames == situpMissingLogFrames {
                logSitup("SITUP no shoulder-hip-knee chain for ~2s — conf \(SitupDetector.jointSummary(observation: observation))")
            }
            return repCount
        }
        situpMissingFrames = 0
        let angle = reading.torsoAngle

        // Hysteresis: count once on reaching "up", then require a clear
        // return to "down" before the next rep can count. The old version
        // flipped state on every frame, so one noisy frame could cost a rep.
        if !situpIsUp {
            situpCycleMinAngle = min(situpCycleMinAngle, angle)

            let now = Date()
            let canCount = lastCrunchCountTime == nil || now.timeIntervalSince(lastCrunchCountTime!) > crunchDebounceDuration

            if angle < Self.situpUpAngle && canCount {
                repCount += 1
                situpIsUp = true
                lastCrunchCountTime = now
                AudioServicesPlaySystemSound(1520)
                logSitup("SITUP rep=\(repCount) angle=\(Int(angle)) side=\(reading.side) conf=\(String(format: "%.2f", reading.confidence))")
                print("🏋️ Sit-up counted! Total: \(repCount)")
            } else if angle > Self.situpDownAngle {
                // Back flat without counting. If they got part-way, record how
                // close they came so thresholds can be tuned from real data.
                if situpCycleMinAngle < Self.situpDownAngle - 10 {
                    logSitup("SITUP near-miss minAngle=\(Int(situpCycleMinAngle)) needed<\(Int(Self.situpUpAngle)) side=\(reading.side)")
                }
                situpCycleMinAngle = 180
            }
        } else if angle > Self.situpDownAngle {
            situpIsUp = false
            situpCycleMinAngle = 180
        }

        return repCount
    }

    func logSitup(_ message: String) {
        let defaults = UserDefaults(suiteName: "group.com.samring.texercise")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        var log = defaults?.string(forKey: SharedKeys.debugLog) ?? ""
        log += line
        if log.count > 20_000 {
            let trimmed = String(log.suffix(15_000))
            log = String(trimmed.drop(while: { $0 != "\n" }).dropFirst())
        }
        defaults?.set(log, forKey: SharedKeys.debugLog)
    }
    
    private func processLunge(observation: VNHumanBodyPoseObservation) -> Int {
        let isInLungePosition = LungeDetector.detectLunge(observation: observation) ?? false
        
        let now = Date()
        let canCount = lastLungeCountTime == nil || now.timeIntervalSince(lastLungeCountTime!) > lungeDebounceDuration
        
        // Count on transition INTO lunge position with debounce
        if isInLungePosition && !lastLungeDetection && canCount {
            repCount += 1
            lastLungeCountTime = now
            AudioServicesPlaySystemSound(1520)
            print("🦵 Lunge counted! Total: \(repCount)")
        }
        
        lastLungeDetection = isInLungePosition
        return repCount
    }
    
    private func processPlank(observation: VNHumanBodyPoseObservation) -> Int {
        let result = PlankDetector.detectPlankWithFeedback(observation: observation)
        plankFeedback = result.feedback
        let isValidFrame = result.isPlank ?? false
        
        if isValidFrame {
            consecutiveValidFrames += 1
            consecutiveInvalidFrames = 0
        } else {
            consecutiveInvalidFrames += 1
            consecutiveValidFrames = 0
        }
        
        if !isInPlank {
            // Enter plank only after holding valid position for N frames
            if consecutiveValidFrames >= plankEntryFrames {
                plankStartTime = Date()
                isInPlank = true
                consecutiveValidFrames = 0
                AudioServicesPlaySystemSound(1520)
                print("🏋️ Plank started!")
            }
        } else {
            // Update timer while in plank
            if let startTime = plankStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                plankTotalSeconds = plankAccumulatedSeconds + Int(elapsed)
            }
            
            // Exit plank only after N consecutive invalid frames
            if consecutiveInvalidFrames >= plankExitFrames {
                if let startTime = plankStartTime {
                    let elapsed = Date().timeIntervalSince(startTime)
                    plankAccumulatedSeconds += Int(elapsed)
                    plankTotalSeconds = plankAccumulatedSeconds
                }
                isInPlank = false
                plankStartTime = nil
                consecutiveInvalidFrames = 0
                AudioServicesPlaySystemSound(1521)
                print("🏋️ Plank paused at \(plankTotalSeconds) seconds")
            }
        }
        
        return plankTotalSeconds
    }
}
