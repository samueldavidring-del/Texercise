import Foundation

struct GoalSettings: Codable, Equatable {
    var stepsGoalEnabled: Bool = false
    var pointsGoalEnabled: Bool = false
    var workoutGoalEnabled: Bool = false
    var exerciseGoalEnabled: Bool = false
    
    var dailyStepsGoal: Int = 10000
    var dailyPointsGoal: Int = 100
    var dailyWorkoutMinutesGoal: Int = 30
    var dailyExerciseRepsGoal: Int = 50
    
    // Computed property for checking if any goal is enabled
    var anyGoalEnabled: Bool {
        stepsGoalEnabled || pointsGoalEnabled || workoutGoalEnabled || exerciseGoalEnabled
    }
    
    static var `default`: GoalSettings {
        GoalSettings()
    }
}

class GoalSettingsStore: ObservableObject {
    @Published var goals: GoalSettings {
        didSet {
            saveGoals()
        }
    }
    
    private let goalsKey = "goalSettings"
    
    init() {
        if let data = UserDefaults.standard.data(forKey: goalsKey),
           let decoded = try? JSONDecoder().decode(GoalSettings.self, from: data) {
            self.goals = decoded
        } else {
            self.goals = .default
        }
    }
    
    private func saveGoals() {
        if let encoded = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(encoded, forKey: goalsKey)
        }
    }
}
