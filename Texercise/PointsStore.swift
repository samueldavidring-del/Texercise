import Foundation

struct PointsStore {
    static func pointsForDay(
        date: Date,
        healthStore: HealthStore,
        exerciseStore: ExerciseStore,
        screenTimeStore: ScreenTimeStore,
        settings: PointSettings = .default
    ) -> DailyPoints {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        // Use the historicalSteps dictionary keyed by startOfDay
        let steps = healthStore.historicalSteps[dayStart] ?? 0
        let workouts = healthStore.workouts(on: date)
        let exercises = exerciseStore.exercises(for: date)
        let screenMinutes = screenTimeStore.totalMinutes(on: date)

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

        return DailyPoints(
            steps: stepsPoints,
            workout: workoutPoints,
            exercise: exercisePoints,
            screen: screenPenalty
        )
    }
}
