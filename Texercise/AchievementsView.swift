import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject var achievementStore: AchievementStore
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var screenTimeStore: ScreenTimeStore
    @EnvironmentObject var pointSettings: PointSettingsStore
    
    @State private var selectedCategory: Achievement.AchievementCategory?
    @State private var totalNetPoints: Int = 0
    @State private var totalGrossPoints: Int = 0
    @State private var totalWorkouts: Int = 0
    @State private var totalPushups: Int = 0
    @State private var currentStreak: Int = 0
    @State private var isCalculating = false
    
    private var filteredAchievements: [Achievement] {
        if let category = selectedCategory {
            return achievementStore.allAchievements.filter { $0.category == category }
        }
        return achievementStore.allAchievements
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    if isCalculating {
                        ProgressView("Calculating stats...")
                            .padding()
                    } else {
                        // Stats Summary
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                StatCard(title: "Net Points", value: "\(totalNetPoints)", color: .blue)
                                StatCard(title: "Earned", value: "\(totalGrossPoints)", color: .green)
                            }
                            
                            HStack(spacing: 16) {
                                StatCard(title: "Workouts", value: "\(totalWorkouts)", color: .orange)
                                StatCard(title: "Streak", value: "\(currentStreak) days", color: .purple)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Category Filter
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                CategoryButton(title: "All", isSelected: selectedCategory == nil) {
                                    selectedCategory = nil
                                }
                                CategoryButton(title: "Points", isSelected: selectedCategory == .points) {
                                    selectedCategory = .points
                                }
                                CategoryButton(title: "Steps", isSelected: selectedCategory == .steps) {
                                    selectedCategory = .steps
                                }
                                CategoryButton(title: "Workouts", isSelected: selectedCategory == .workouts) {
                                    selectedCategory = .workouts
                                }
                                CategoryButton(title: "Exercises", isSelected: selectedCategory == .exercises) {
                                    selectedCategory = .exercises
                                }
                                CategoryButton(title: "Milestones", isSelected: selectedCategory == .milestones) {
                                    selectedCategory = .milestones
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Achievements List
                        LazyVStack(spacing: 12) {
                            ForEach(filteredAchievements) { achievement in
                                AchievementCard(
                                    achievement: achievement,
                                    isUnlocked: achievementStore.isUnlocked(achievement.id),
                                    progress: achievementStore.progress(
                                        for: achievement,
                                        totalNetPoints: totalNetPoints,
                                        totalGrossPoints: totalGrossPoints,
                                        stepsToday: healthStore.stepsToday,
                                        totalWorkouts: totalWorkouts,
                                        totalPushups: totalPushups,
                                        currentStreak: currentStreak
                                    )
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Achievements")
            .onAppear {
                if totalNetPoints == 0 && !isCalculating {
                    calculateStats()
                }
            }
        }
    }
    
    private func calculateStats() {
        isCalculating = true
        
        // Capture values we need
        let health = healthStore
        let exercise = exerciseStore
        let screen = screenTimeStore
        let settings = pointSettings
        
        DispatchQueue.global(qos: .userInitiated).async {
            let calendar = Calendar.current
            let last30Days = (0..<30).compactMap { offset in
                calendar.date(byAdding: .day, value: -offset, to: Date())
            }
            
            var netPoints = 0
            var grossPoints = 0
            
            for date in last30Days {
                let points = PointsStore.pointsForDay(
                    date: date,
                    healthStore: health,
                    exerciseStore: exercise,
                    screenTimeStore: screen,
                    settings: settings.settings
                )
                netPoints += points.net
                grossPoints += points.earned
            }
            
            let workouts = health.recentWorkouts.count
            
            let pushups = exercise.entries
                .filter { $0.type?.lowercased().contains("push") ?? false }
                .reduce(0) { $0 + Int($1.count) }
            
            // Calculate streak
            var streak = 0
            var checkDate = calendar.startOfDay(for: Date())
            
            for _ in 0..<365 {
                let points = PointsStore.pointsForDay(
                    date: checkDate,
                    healthStore: health,
                    exerciseStore: exercise,
                    screenTimeStore: screen,
                    settings: settings.settings
                )
                
                if points.net > 0 {
                    streak += 1
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
                } else {
                    break
                }
            }
            
            // Update state on main thread
            DispatchQueue.main.async {
                self.totalNetPoints = netPoints
                self.totalGrossPoints = grossPoints
                self.totalWorkouts = workouts
                self.totalPushups = pushups
                self.currentStreak = streak
                
                // Check for newly unlocked achievements
                let newlyUnlocked = self.achievementStore.checkAchievements(
                    totalNetPoints: netPoints,
                    totalGrossPoints: grossPoints,
                    stepsToday: health.stepsToday,
                    totalWorkouts: workouts,
                    totalPushups: pushups,
                    currentStreak: streak
                )
                
                if !newlyUnlocked.isEmpty {
                    print("🎉 Unlocked \(newlyUnlocked.count) new achievements!")
                }
                
                self.isCalculating = false
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                .cornerRadius(20)
        }
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    let isUnlocked: Bool
    let progress: Double
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: achievement.iconName)
                .font(.system(size: 40))
                .foregroundColor(isUnlocked ? .yellow : .gray)
                .frame(width: 60)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.headline)
                    .foregroundColor(isUnlocked ? .primary : .secondary)
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !isUnlocked {
                    ProgressView(value: progress)
                        .tint(.accentColor)
                        .frame(height: 4)
                }
            }
            
            Spacer()
            
            if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .opacity(isUnlocked ? 1.0 : 0.7)
    }
}

#Preview {
    AchievementsView()
        .environmentObject(AchievementStore())
        .environmentObject(HealthStore())
        .environmentObject(ExerciseStore())
        .environmentObject(ScreenTimeStore())
        .environmentObject(PointSettingsStore())
}
