import Foundation

struct GoalSettings: Codable, Equatable {
    // All goals enabled by default so new users see goal progress immediately
    var stepsGoalEnabled: Bool = true
    var pointsGoalEnabled: Bool = true
    var workoutGoalEnabled: Bool = false   // workout goal off by default — not everyone tracks workouts
    var exerciseGoalEnabled: Bool = true
    
    var dailyStepsGoal: Int = 10000
    var dailyPointsGoal: Int = 100
    var dailyWorkoutMinutesGoal: Int = 30
    var dailyExerciseRepsGoal: Int = 100
    
    var anyGoalEnabled: Bool {
        stepsGoalEnabled || pointsGoalEnabled || workoutGoalEnabled || exerciseGoalEnabled
    }
    
    static var `default`: GoalSettings {
        GoalSettings()
    }
}

class GoalSettingsStore: ObservableObject {
    @Published var goals: GoalSettings {
        didSet { saveGoals() }
    }
    
    private let goalsKey = "goalSettings"
    
    init() {
        if let data = UserDefaults.standard.data(forKey: goalsKey),
           let decoded = try? JSONDecoder().decode(GoalSettings.self, from: data) {
            self.goals = decoded
        } else {
            // First launch — use defaults (goals enabled)
            self.goals = .default
        }
    }
    
    private func saveGoals() {
        if let encoded = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(encoded, forKey: goalsKey)
        }
    }
}
