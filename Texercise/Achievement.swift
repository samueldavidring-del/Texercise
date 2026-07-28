import Foundation

struct Achievement: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let iconName: String
    let requirement: Int
    let category: AchievementCategory
    
    enum AchievementCategory: String, Codable, CaseIterable {
        case points
        case steps
        case workouts
        case exercises
        case milestones
        
        var displayName: String {
            switch self {
            case .points:     return "Points"
            case .steps:      return "Steps"
            case .workouts:   return "Workouts"
            case .exercises:  return "Exercises"
            case .milestones: return "Milestones"
            }
        }
        
        var iconName: String {
            switch self {
            case .points:     return "star.fill"
            case .steps:      return "figure.walk"
            case .workouts:   return "figure.run"
            case .exercises:  return "dumbbell.fill"
            case .milestones: return "calendar.badge.checkmark"
            }
        }
    }
}

struct AchievementRecord: Codable {
    let id: String
    var firstAchievedDate: Date
    var lastAchievedDate: Date
    var timesAchieved: Int
}

class AchievementStore: ObservableObject {
    @Published var records: [String: AchievementRecord] = [:]
    
    private let recordsKey = "achievementRecords"
    private let keychainInstallDateKey = "com.samring.texercise.installDate"
    
    var installDate: Date {
        // If records are empty and a Keychain date exists from a previous install,
        // this is a fresh reinstall — reset the install date to today so achievements
        // start fresh rather than counting historical HealthKit data.
        if records.isEmpty {
            let freshDate = Date()
            saveInstallDateToKeychain(freshDate)
            print("✅ Fresh install detected — resetting install date to today")
            return freshDate
        }
        // Try Keychain first — survives reinstalls
        if let date = keychainInstallDate() {
            return date
        }
        // Migrate from UserDefaults if present
        let legacyKey = "appInstallDate"
        let date: Date
        if let stored = UserDefaults.standard.object(forKey: legacyKey) as? Date {
            date = stored
            UserDefaults.standard.removeObject(forKey: legacyKey)
        } else {
            date = Date()
        }
        saveInstallDateToKeychain(date)
        return date
    }
    
    private func keychainInstallDate() -> Date? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      keychainInstallDateKey,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let interval = try? JSONDecoder().decode(Double.self, from: data) else {
            return nil
        }
        return Date(timeIntervalSince1970: interval)
    }
    
    private func saveInstallDateToKeychain(_ date: Date) {
        guard let data = try? JSONEncoder().encode(date.timeIntervalSince1970) else { return }
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: keychainInstallDateKey,
            kSecValueData:   data,
            // kSecAttrAccessible: keeps the item after reinstall
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]
        // Try adding first, update if it already exists
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update: [CFString: Any] = [kSecValueData: data]
            SecItemUpdate(query as CFDictionary, update as CFDictionary)
        }
        print("✅ Install date saved to Keychain: \(date)")
    }
    
    init() {
        loadRecords()
        migrateLegacyData()
        // If records are empty (fresh install or reinstall), reset the first-check
        // flag so the guard in checkAchievements fires correctly on next check.
        if records.isEmpty {
            UserDefaults.standard.removeObject(forKey: "hasCompletedFirstAchievementCheck")
        }
    }
    
    // All available achievements
    let allAchievements: [Achievement] = [
        // Points
        Achievement(id: "first_point",   title: "Getting Started",       description: "Earn your first point",                    iconName: "star.fill",                    requirement: 1,    category: .points),
        Achievement(id: "points_100",    title: "Century Club",           description: "Earn 100 net points",                      iconName: "100.circle",              requirement: 100,  category: .points),
        Achievement(id: "points_500",    title: "Five Hundred Strong",    description: "Earn 500 net points",                      iconName: "star.circle.fill",             requirement: 500,  category: .points),
        Achievement(id: "points_1000",   title: "Thousand Club",          description: "Earn 1,000 net points",                    iconName: "trophy.fill",                  requirement: 1000, category: .points),
        Achievement(id: "gross_100",     title: "Century Mark (Gross)",   description: "Earn 100 total points from activities",    iconName: "arrow.up.circle.fill",         requirement: 100,  category: .points),
        Achievement(id: "gross_500",     title: "Productivity Master",    description: "Earn 500 total points from activities",    iconName: "flame.fill",                   requirement: 500,  category: .points),
        Achievement(id: "gross_1000",    title: "Activity Legend",        description: "Earn 1,000 total points from activities",  iconName: "crown.fill",                   requirement: 1000, category: .points),

        // Steps
        Achievement(id: "steps_10k",     title: "10K Steps",              description: "Walk 10,000 steps in a day",               iconName: "figure.walk",                  requirement: 10000, category: .steps),
        Achievement(id: "steps_20k",     title: "20K Steps",              description: "Walk 20,000 steps in a day",               iconName: "figure.walk.motion",           requirement: 20000, category: .steps),

        // Workouts
        Achievement(id: "first_workout", title: "First Workout",          description: "Complete your first workout",              iconName: "figure.run",                   requirement: 1,   category: .workouts),
        Achievement(id: "workouts_10",   title: "Dedicated",              description: "Complete 10 workouts",                     iconName: "figure.strengthtraining.traditional", requirement: 10,  category: .workouts),
        Achievement(id: "workouts_50",   title: "Fitness Enthusiast",     description: "Complete 50 workouts",                     iconName: "heart.fill",                   requirement: 50,  category: .workouts),
        Achievement(id: "workouts_100",  title: "Workout Warrior",        description: "Complete 100 workouts",                    iconName: "bolt.fill",                    requirement: 100, category: .workouts),

        // Exercises — Pushups
        Achievement(id: "pushups_100",   title: "Push It",                description: "Do 100 total pushups",                     iconName: "hands.and.sparkles.fill",      requirement: 100,  category: .exercises),
        Achievement(id: "pushups_1000",  title: "Push Master",            description: "Do 1,000 total pushups",                   iconName: "sparkles",                     requirement: 1000, category: .exercises),

        // Exercises — Squats
        Achievement(id: "squats_100",    title: "Squat Starter",          description: "Do 100 total squats",                      iconName: "figure.strengthtraining.functional", requirement: 100,  category: .exercises),
        Achievement(id: "squats_1000",   title: "Squat Legend",           description: "Do 1,000 total squats",                    iconName: "figure.strengthtraining.functional", requirement: 1000, category: .exercises),

        // Exercises — Sit-ups
        Achievement(id: "situps_100",    title: "Core Starter",           description: "Do 100 total sit-ups",                     iconName: "figure.core.training",         requirement: 100,  category: .exercises),
        Achievement(id: "situps_1000",   title: "Core Legend",            description: "Do 1,000 total sit-ups",                   iconName: "figure.core.training",         requirement: 1000, category: .exercises),

        // Exercises — Lunges
        Achievement(id: "lunges_100",    title: "Lunge Starter",          description: "Do 100 total lunges",                      iconName: "figure.walk",                  requirement: 100,  category: .exercises),
        Achievement(id: "lunges_1000",   title: "Lunge Legend",           description: "Do 1,000 total lunges",                    iconName: "figure.walk",                  requirement: 1000, category: .exercises),

        // Exercises — Plank
        Achievement(id: "plank_60",      title: "Plank Starter",          description: "Hold a plank for 60 total minutes",        iconName: "timer",                        requirement: 3600,  category: .exercises),
        Achievement(id: "plank_600",     title: "Plank Legend",           description: "Hold a plank for 600 total minutes",       iconName: "timer.circle.fill",            requirement: 36000, category: .exercises),

        // Milestones
        Achievement(id: "week_streak",   title: "Weekly Warrior",         description: "Earn positive points for 7 days in a row",  iconName: "calendar.badge.checkmark",    requirement: 7,  category: .milestones),
        Achievement(id: "month_streak",  title: "Monthly Champion",       description: "Earn positive points for 30 days in a row", iconName: "calendar",                    requirement: 30, category: .milestones),
    ]
    
    var unlockedAchievements: Set<String> {
        Set(records.keys)
    }
    
    func isUnlocked(_ id: String) -> Bool {
        records[id] != nil
    }
    
    func record(for id: String) -> AchievementRecord? {
        records[id]
    }
    
    func checkAchievements(
        totalNetPoints: Int,
        totalGrossPoints: Int,
        stepsToday: Int,
        totalWorkouts: Int,
        totalPushups: Int,
        totalSquats: Int,
        totalSitups: Int,
        totalLunges: Int,
        totalPlankSeconds: Int,
        currentStreak: Int
    ) -> [Achievement] {
        // Skip the very first check after a fresh install so HealthKit history
        // doesn't immediately unlock achievements before the user has done anything.
        let firstCheckKey = "hasCompletedFirstAchievementCheck"
        let hasCheckedBefore = UserDefaults.standard.bool(forKey: firstCheckKey)
        if !hasCheckedBefore {
            UserDefaults.standard.set(true, forKey: firstCheckKey)
            print("ℹ️ First achievement check — skipping to prevent bulk unlock on install")
            return []
        }

        var newlyUnlocked: [Achievement] = []
        let now = Date()
        
        for achievement in allAchievements {
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
                shouldUnlock = exerciseCount(for: achievement.id,
                    pushups: totalPushups, squats: totalSquats,
                    situps: totalSitups, lunges: totalLunges,
                    plankSeconds: totalPlankSeconds) >= achievement.requirement
            case .milestones:
                shouldUnlock = currentStreak >= achievement.requirement
            }
            
            if shouldUnlock {
                if var existing = records[achievement.id] {
                    existing.lastAchievedDate = now
                    existing.timesAchieved += 1
                    records[achievement.id] = existing
                } else {
                    records[achievement.id] = AchievementRecord(
                        id: achievement.id,
                        firstAchievedDate: now,
                        lastAchievedDate: now,
                        timesAchieved: 1
                    )
                    newlyUnlocked.append(achievement)
                }
            }
        }
        
        saveRecords()
        return newlyUnlocked
    }
    
    func unlockAchievement(_ id: String) {
        let now = Date()
        if var existing = records[id] {
            existing.lastAchievedDate = now
            existing.timesAchieved += 1
            records[id] = existing
        } else {
            records[id] = AchievementRecord(id: id, firstAchievedDate: now, lastAchievedDate: now, timesAchieved: 1)
        }
        saveRecords()
    }
    
    func progress(
        for achievement: Achievement,
        totalNetPoints: Int,
        totalGrossPoints: Int,
        stepsToday: Int,
        totalWorkouts: Int,
        totalPushups: Int,
        totalSquats: Int,
        totalSitups: Int,
        totalLunges: Int,
        totalPlankSeconds: Int,
        currentStreak: Int
    ) -> Double {
        if isUnlocked(achievement.id) { return 1.0 }
        
        let current: Int
        switch achievement.category {
        case .points:
            current = achievement.id.contains("gross") ? totalGrossPoints : totalNetPoints
        case .steps:
            current = stepsToday
        case .workouts:
            current = totalWorkouts
        case .exercises:
            current = exerciseCount(for: achievement.id,
                pushups: totalPushups, squats: totalSquats,
                situps: totalSitups, lunges: totalLunges,
                plankSeconds: totalPlankSeconds)
        case .milestones:
            current = currentStreak
        }
        
        return min(Double(current) / Double(achievement.requirement), 1.0)
    }
    
    /// Routes an achievement ID to the correct exercise total
    private func exerciseCount(
        for id: String,
        pushups: Int, squats: Int, situps: Int, lunges: Int, plankSeconds: Int
    ) -> Int {
        if id.hasPrefix("pushups") { return pushups }
        if id.hasPrefix("squats")  { return squats }
        if id.hasPrefix("situps")  { return situps }
        if id.hasPrefix("lunges")  { return lunges }
        if id.hasPrefix("plank")   { return plankSeconds }
        return 0
    }
    
    // Migrate old Set<String> data to new AchievementRecord format
    private func migrateLegacyData() {
        let legacyKey = "unlockedAchievements"
        guard let data = UserDefaults.standard.data(forKey: legacyKey),
              let legacy = try? JSONDecoder().decode(Set<String>.self, from: data),
              !legacy.isEmpty else { return }
        
        let installDate = self.installDate
        for id in legacy {
            if records[id] == nil {
                records[id] = AchievementRecord(
                    id: id,
                    firstAchievedDate: installDate,
                    lastAchievedDate: installDate,
                    timesAchieved: 1
                )
            }
        }
        saveRecords()
        UserDefaults.standard.removeObject(forKey: legacyKey)
        print("✅ Migrated \(legacy.count) legacy achievements")
    }
    
    private func loadRecords() {
        if let data = UserDefaults.standard.data(forKey: recordsKey),
           let decoded = try? JSONDecoder().decode([String: AchievementRecord].self, from: data) {
            records = decoded
        }
    }
    
    private func saveRecords() {
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: recordsKey)
        }
    }
}
