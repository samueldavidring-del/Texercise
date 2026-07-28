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
    
    // Sit-up/Crunch tracking with debounce
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
        let isInUpPosition = SitupDetector.detectSitup(observation: observation) ?? false
        
        let now = Date()
        let canCount = lastCrunchCountTime == nil || now.timeIntervalSince(lastCrunchCountTime!) > crunchDebounceDuration
        
        // Count on transition to up position with debounce
        if isInUpPosition && !wasInPosition && canCount {
            repCount += 1
            lastCrunchCountTime = now
            AudioServicesPlaySystemSound(1520)
            print("🏋️ Crunch counted! Total: \(repCount)")
        }
        
        wasInPosition = isInUpPosition
        return repCount
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
