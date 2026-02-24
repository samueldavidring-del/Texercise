import Foundation

struct DailyPoints {
    let steps: Int
    let workout: Int
    let exercise: Int
    let screen: Int
    
    var earned: Int {
        steps + workout + exercise
    }
    
    var net: Int {
        earned - screen
    }
}

struct Points {
    static func today(
        steps: Int,
        workouts: [WorkoutSummary],
        exercises: [ExerciseEntry],
        screenMinutes: Int,
        settings: PointSettings = .default
    ) -> Int {
        let stepsPoints = steps / settings.stepsPerPoint
        let workoutPoints = workouts.reduce(0) { $0 + $1.durationMinutes } / settings.workoutMinutesPerPoint
        
        // Calculate exercise points - 1 rep = 1 point for all except plank
        var exercisePoints = 0
        for exercise in exercises {
            let type = exercise.type?.lowercased() ?? ""
            let count = Int(exercise.count)
            
            if type.contains("plank") {
                // Plank: use threshold (default 6 seconds = 1 point)
                exercisePoints += count / settings.plankSecondsPerPoint
            } else {
                // All other exercises: 1 rep = 1 point (no threshold)
                exercisePoints += count
            }
        }
        
        let screenPenalty = screenMinutes / settings.screenTimeMinutesPerPenalty
        
        return stepsPoints + workoutPoints + exercisePoints - screenPenalty
    }
}
