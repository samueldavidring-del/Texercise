import Foundation

struct PointsStore {
    static func pointsForDay(
        date: Date,
        healthStore: HealthStore,
        exerciseStore: ExerciseStore,
        screenTimeStore: ScreenTimeStore,
        settings: PointSettings = .default
    ) -> DailyPoints {
        let steps = healthStore.steps(on: date)
        let workouts = healthStore.workouts(on: date)
        let exercises = exerciseStore.exercises(for: date)
        let screenMinutes = screenTimeStore.totalMinutes(on: date)
        
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
        
        return DailyPoints(
            steps: stepsPoints,
            workout: workoutPoints,
            exercise: exercisePoints,
            screen: screenPenalty
        )
    }
}
