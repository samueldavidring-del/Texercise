import Foundation

struct Achievement: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let iconName: String
    let requirement: Int
    let category: AchievementCategory
    
    enum AchievementCategory: String, Codable {
        case points
        case steps
        case workouts
        case exercises
        case milestones
    }
}

class AchievementStore: ObservableObject {
    @Published var unlockedAchievements: Set<String> = []
    
    private let unlockedKey = "unlockedAchievements"
    
    init() {
        loadUnlocked()
    }
    
    // All available achievements
    let allAchievements: [Achievement] = [
        // Points Achievements
        Achievement(id: "first_point", title: "Getting Started", description: "Earn your first point", iconName: "star.fill", requirement: 1, category: .points),
        Achievement(id: "points_100", title: "Century Club", description: "Earn 100 net points", iconName: "100.circle.fill", requirement: 100, category: .points),
        Achievement(id: "points_500", title: "Five Hundred Strong", description: "Earn 500 net points", iconName: "star.circle.fill", requirement: 500, category: .points),
        Achievement(id: "points_1000", title: "Thousand Club", description: "Earn 1,000 net points", iconName: "trophy.fill", requirement: 1000, category: .points),
        
        // Gross Points (earned without screen time penalty)
        Achievement(id: "gross_100", title: "Century Mark (Gross)", description: "Earn 100 total points from activities", iconName: "arrow.up.circle.fill", requirement: 100, category: .points),
        Achievement(id: "gross_500", title: "Productivity Master", description: "Earn 500 total points from activities", iconName: "flame.fill", requirement: 500, category: .points),
        Achievement(id: "gross_1000", title: "Activity Legend", description: "Earn 1,000 total points from activities", iconName: "crown.fill", requirement: 1000, category: .points),
        
        // Steps Achievements
        Achievement(id: "steps_10k", title: "10K Steps", description: "Walk 10,000 steps in a day", iconName: "figure.walk", requirement: 10000, category: .steps),
        Achievement(id: "steps_20k", title: "20K Steps", description: "Walk 20,000 steps in a day", iconName: "figure.walk.motion", requirement: 20000, category: .steps),
        
        // Workout Achievements
        Achievement(id: "first_workout", title: "First Workout", description: "Complete your first workout", iconName: "figure.run", requirement: 1, category: .workouts),
        Achievement(id: "workouts_10", title: "Dedicated", description: "Complete 10 workouts", iconName: "figure.strengthtraining.traditional", requirement: 10, category: .workouts),
        Achievement(id: "workouts_50", title: "Fitness Enthusiast", description: "Complete 50 workouts", iconName: "heart.fill", requirement: 50, category: .workouts),
        Achievement(id: "workouts_100", title: "Workout Warrior", description: "Complete 100 workouts", iconName: "bolt.fill", requirement: 100, category: .workouts),
        
        // Exercise Achievements
        Achievement(id: "pushups_100", title: "Push It", description: "Do 100 total pushups", iconName: "hands.and.sparkles.fill", requirement: 100, category: .exercises),
        Achievement(id: "pushups_1000", title: "Push Master", description: "Do 1,000 total pushups", iconName: "sparkles", requirement: 1000, category: .exercises),
        
        // Milestones
        Achievement(id: "week_streak", title: "Weekly Warrior", description: "Earn positive points for 7 days in a row", iconName: "calendar.badge.checkmark", requirement: 7, category: .milestones),
        Achievement(id: "month_streak", title: "Monthly Champion", description: "Earn positive points for 30 days in a row", iconName: "calendar", requirement: 30, category: .milestones),
    ]
    
    func checkAchievements(
        totalNetPoints: Int,
        totalGrossPoints: Int,
        stepsToday: Int,
        totalWorkouts: Int,
        totalPushups: Int,
        currentStreak: Int
    ) -> [Achievement] {
        var newlyUnlocked: [Achievement] = []
        
        for achievement in allAchievements {
            // Skip if already unlocked
            if unlockedAchievements.contains(achievement.id) {
                continue
            }
            
            var shouldUnlock = false
            
            switch achievement.category {
            case .points:
                if achievement.id.contains("gross") {
                    shouldUnlock = totalGrossPoints >= achievement.requirement
                } else {
                    shouldUnlock = totalNetPoints >= achievement.requirement
                }
            case .steps:
                shouldUnlock = stepsToday >= achievement.requirement
            case .workouts:
                shouldUnlock = totalWorkouts >= achievement.requirement
            case .exercises:
                shouldUnlock = totalPushups >= achievement.requirement
            case .milestones:
                shouldUnlock = currentStreak >= achievement.requirement
            }
            
            if shouldUnlock {
                unlockAchievement(achievement.id)
                newlyUnlocked.append(achievement)
            }
        }
        
        return newlyUnlocked
    }
    
    func unlockAchievement(_ id: String) {
        unlockedAchievements.insert(id)
        saveUnlocked()
    }
    
    func isUnlocked(_ id: String) -> Bool {
        unlockedAchievements.contains(id)
    }
    
    func progress(for achievement: Achievement, totalNetPoints: Int, totalGrossPoints: Int, stepsToday: Int, totalWorkouts: Int, totalPushups: Int, currentStreak: Int) -> Double {
        if isUnlocked(achievement.id) {
            return 1.0
        }
        
        let current: Int
        switch achievement.category {
        case .points:
            current = achievement.id.contains("gross") ? totalGrossPoints : totalNetPoints
        case .steps:
            current = stepsToday
        case .workouts:
            current = totalWorkouts
        case .exercises:
            current = totalPushups
        case .milestones:
            current = currentStreak
        }
        
        return min(Double(current) / Double(achievement.requirement), 1.0)
    }
    
    private func loadUnlocked() {
        if let data = UserDefaults.standard.data(forKey: unlockedKey),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            unlockedAchievements = decoded
        }
    }
    
    private func saveUnlocked() {
        if let encoded = try? JSONEncoder().encode(unlockedAchievements) {
            UserDefaults.standard.set(encoded, forKey: unlockedKey)
        }
    }
}
