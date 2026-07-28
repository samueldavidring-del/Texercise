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
        let stepsPoints = settings.stepsPerPoint > 0 ? steps / settings.stepsPerPoint : 0
        let workoutPoints = settings.workoutMinutesPerPoint > 0
            ? workouts.reduce(0) { $0 + $1.durationMinutes } / settings.workoutMinutesPerPoint
            : 0
        
        var exercisePoints = 0
        for exercise in exercises {
            let type = exercise.type?.lowercased() ?? ""
            let count = Int(exercise.count)
            
            if type.contains("plank") {
                exercisePoints += settings.plankSecondsPerPoint > 0 ? count / settings.plankSecondsPerPoint : 0
            } else if type.contains("push") {
                exercisePoints += settings.pushupsPerPoint > 0 ? count / settings.pushupsPerPoint : 0
            } else if type.contains("squat") {
                exercisePoints += settings.squatsPerPoint > 0 ? count / settings.squatsPerPoint : 0
            } else if type.contains("sit") {
                exercisePoints += settings.situpsPerPoint > 0 ? count / settings.situpsPerPoint : 0
            } else if type.contains("lunge") {
                exercisePoints += settings.lungeRepsPerPoint > 0 ? count / settings.lungeRepsPerPoint : 0
            } else {
                exercisePoints += count
            }
        }
        
        let screenPenalty = settings.screenTimeMinutesPerPenalty > 0
            ? screenMinutes / settings.screenTimeMinutesPerPenalty
            : 0
        
        return stepsPoints + workoutPoints + exercisePoints - screenPenalty
    }
}
