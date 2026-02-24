import Foundation
import HealthKit

struct WorkoutSummary: Identifiable {
    let id: UUID
    let activityType: UInt
    let activityName: String
    let startDate: Date
    let endDate: Date
    let durationSeconds: Double
    let distanceMiles: Double?
    let caloriesBurned: Double?
    let averageHeartRate: Double?
    let maxHeartRate: Double?
    let elevationGain: Double?
    
    // Convenience: whole minutes for display
    var durationMinutes: Int { Int(durationSeconds / 60) }
    
    // Convenience: formatted duration e.g. "32:45"
    var durationFormatted: String {
        let m = Int(durationSeconds) / 60
        let s = Int(durationSeconds) % 60
        return String(format: "%d:%02d", m, s)
    }
    
    // Init from HKWorkout - uses full seconds
    init(workout: HKWorkout, averageHeartRate: Double? = nil, maxHeartRate: Double? = nil, elevationGain: Double? = nil) {
        self.id = workout.uuid
        self.activityType = workout.workoutActivityType.rawValue
        self.activityName = Self.activityName(for: workout.workoutActivityType)
        self.startDate = workout.startDate
        self.endDate = workout.endDate
        self.durationSeconds = workout.duration  // Full precision
        self.distanceMiles = workout.totalDistance?.doubleValue(for: .mile())
        self.caloriesBurned = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        
        if let metadata = workout.metadata,
           let elevation = metadata[HKMetadataKeyElevationAscended] as? HKQuantity {
            self.elevationGain = elevation.doubleValue(for: .foot())
        } else {
            self.elevationGain = elevationGain
        }
    }
    
    // Init with individual parameters (for manual creation)
    init(id: UUID, activityType: UInt, activityName: String, startDate: Date, endDate: Date,
         durationSeconds: Double, distanceMiles: Double?, caloriesBurned: Double?,
         averageHeartRate: Double? = nil, maxHeartRate: Double? = nil, elevationGain: Double? = nil) {
        self.id = id
        self.activityType = activityType
        self.activityName = activityName
        self.startDate = startDate
        self.endDate = endDate
        self.durationSeconds = durationSeconds
        self.distanceMiles = distanceMiles
        self.caloriesBurned = caloriesBurned
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.elevationGain = elevationGain
    }
    
    private static func activityName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .walking: return "Walking"
        case .hiking: return "Hiking"
        case .elliptical: return "Elliptical"
        case .traditionalStrengthTraining: return "Strength Training"
        case .functionalStrengthTraining: return "Strength Training"
        case .yoga: return "Yoga"
        case .rowing: return "Rowing"
        default: return "Workout"
        }
    }
}
