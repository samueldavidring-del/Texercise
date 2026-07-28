import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject var achievementStore: AchievementStore
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var screenTimeStore: ScreenTimeStore
    @EnvironmentObject var pointSettings: PointSettingsStore
    
    @State private var selectedCategory: Achievement.AchievementCategory? = nil
    @State private var selectedAchievement: Achievement? = nil
    @State private var totalNetPoints: Int = 0
    @State private var totalGrossPoints: Int = 0
    @State private var totalWorkouts: Int = 0
    @State private var totalPushups: Int = 0
    @State private var totalSquats: Int = 0
    @State private var totalSitups: Int = 0
    @State private var totalLunges: Int = 0
    @State private var totalPlankSeconds: Int = 0
    @State private var currentStreak: Int = 0
    @State private var isCalculating = false
    
    private var achievementsByCategory: [(Achievement.AchievementCategory, [Achievement])] {
        Achievement.AchievementCategory.allCases.compactMap { category in
            let items = achievementStore.allAchievements.filter {
                $0.category == category &&
                (selectedCategory == nil || $0.category == selectedCategory)
            }
            return items.isEmpty ? nil : (category, items)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if isCalculating {
                        ProgressView("Calculating stats...")
                            .padding(.top, 40)
                    } else {
                        // Stats summary
                        HStack(spacing: 12) {
                            StatCard(title: "Net Points", value: "\(totalNetPoints)", color: .blue)
                            StatCard(title: "All-Time Earned", value: "\(totalGrossPoints)", color: .green)
                            StatCard(title: "All-Time Workouts", value: "\(totalWorkouts)", color: .orange)
                            StatCard(title: "Streak", value: "\(currentStreak)d", color: .purple)
                        }
                        .padding(.horizontal)
                        
                        // Unlocked count
                        let unlockedCount = achievementStore.unlockedAchievements.count
                        let totalCount = achievementStore.allAchievements.count
                        Text("\(unlockedCount) of \(totalCount) achievements unlocked")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Category filter
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                CategoryButton(title: "All", isSelected: selectedCategory == nil) {
                                    selectedCategory = nil
                                }
                                ForEach(Achievement.AchievementCategory.allCases, id: \.self) { cat in
                                    CategoryButton(title: cat.displayName, isSelected: selectedCategory == cat) {
                                        selectedCategory = cat
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Achievements by section
                        ForEach(achievementsByCategory, id: \.0) { category, achievements in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: category.iconName)
                                        .foregroundColor(.accentColor)
                                    Text(category.displayName)
                                        .font(.title3.bold())
                                }
                                .padding(.horizontal)
                                
                                ForEach(achievements) { achievement in
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
                                            totalSquats: totalSquats,
                                            totalSitups: totalSitups,
                                            totalLunges: totalLunges,
                                            totalPlankSeconds: totalPlankSeconds,
                                            currentStreak: currentStreak
                                        )
                                    )
                                    .padding(.horizontal)
                                    .onTapGesture {
                                        selectedAchievement = achievement
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Achievements")
            .onAppear {
                if !isCalculating {
                    calculateStats()
                }
            }
            .sheet(item: $selectedAchievement) { achievement in
                AchievementDetailView(
                    achievement: achievement,
                    isUnlocked: achievementStore.isUnlocked(achievement.id),
                    record: achievementStore.record(for: achievement.id),
                    progress: achievementStore.progress(
                        for: achievement,
                        totalNetPoints: totalNetPoints,
                        totalGrossPoints: totalGrossPoints,
                        stepsToday: healthStore.stepsToday,
                        totalWorkouts: totalWorkouts,
                        totalPushups: totalPushups,
                        totalSquats: totalSquats,
                        totalSitups: totalSitups,
                        totalLunges: totalLunges,
                        totalPlankSeconds: totalPlankSeconds,
                        currentStreak: currentStreak
                    )
                )
            }
        }
    }
    
    private func calculateStats() {
        isCalculating = true
        let health = healthStore
        let exercise = exerciseStore
        let screen = screenTimeStore
        let settings = pointSettings
        let installDate = achievementStore.installDate
        
        DispatchQueue.global(qos: .userInitiated).async {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            
            let daysSinceInstall = calendar.dateComponents([.day], from: calendar.startOfDay(for: installDate), to: today).day ?? 0
            let daysToCheck = max(daysSinceInstall, 0)
            
            let allDays = (0...daysToCheck).compactMap { offset in
                calendar.date(byAdding: .day, value: -offset, to: today)
            }
            
            var netPoints = 0
            var grossPoints = 0
            
            for date in allDays {
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
            
            // Workout count filtered to install date only
            let workouts = health.allWorkouts
                .filter { $0.startDate >= installDate }
                .count

            // Exercise totals filtered to install date — excludes pre-existing reps
            let entriesSinceInstall = exercise.entries.filter {
                guard let date = $0.timestamp ?? $0.date else { return false }
                return date >= installDate
            }
            let pushups = entriesSinceInstall
                .filter { $0.type?.lowercased().contains("push") ?? false }
                .reduce(0) { $0 + Int($1.count) }
            let squats = entriesSinceInstall
                .filter { $0.type?.lowercased().contains("squat") ?? false }
                .reduce(0) { $0 + Int($1.count) }
            let situps = entriesSinceInstall
                .filter { $0.type?.lowercased().contains("sit") ?? false }
                .reduce(0) { $0 + Int($1.count) }
            let lunges = entriesSinceInstall
                .filter { $0.type?.lowercased().contains("lunge") ?? false }
                .reduce(0) { $0 + Int($1.count) }
            let plankSeconds = entriesSinceInstall
                .filter { $0.type?.lowercased().contains("plank") ?? false }
                .reduce(0) { $0 + Int($1.count) }
            
            // Streak from today backwards
            var streak = 0
            var checkDate = today
            for _ in 0...daysToCheck {
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
            
            DispatchQueue.main.async {
                self.totalNetPoints = netPoints
                self.totalGrossPoints = grossPoints
                self.totalWorkouts = workouts
                self.totalPushups = pushups
                self.totalSquats = squats
                self.totalSitups = situps
                self.totalLunges = lunges
                self.totalPlankSeconds = plankSeconds
                self.currentStreak = streak
                
                let newlyUnlocked = self.achievementStore.checkAchievements(
                    totalNetPoints: netPoints,
                    totalGrossPoints: grossPoints,
                    stepsToday: health.stepsToday,
                    totalWorkouts: workouts,
                    totalPushups: pushups,
                    totalSquats: squats,
                    totalSitups: situps,
                    totalLunges: lunges,
                    totalPlankSeconds: plankSeconds,
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

// MARK: - Achievement Detail View

struct AchievementDetailView: View {
    let achievement: Achievement
    let isUnlocked: Bool
    let record: AchievementRecord?
    let progress: Double
    @Environment(\.dismiss) private var dismiss
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Icon
                    Image(systemName: achievement.iconName)
                        .font(.system(size: 80))
                        .foregroundColor(isUnlocked ? .yellow : .gray)
                        .padding(.top, 24)
                    
                    // Title and description
                    VStack(spacing: 8) {
                        Text(achievement.title)
                            .font(.title.bold())
                            .multilineTextAlignment(.center)
                        
                        Text(achievement.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text(achievement.category.displayName)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundColor(.accentColor)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    if let record {
                        // Achievement stats
                        VStack(spacing: 16) {
                            DetailRow(
                                icon: "calendar.badge.checkmark",
                                label: "First achieved",
                                value: dateFormatter.string(from: record.firstAchievedDate)
                            )
                            Divider()
                            DetailRow(
                                icon: "clock.arrow.circlepath",
                                label: "Last achieved",
                                value: dateFormatter.string(from: record.lastAchievedDate)
                            )
                            Divider()
                            DetailRow(
                                icon: "repeat",
                                label: "Times achieved",
                                value: "\(record.timesAchieved)"
                            )
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    } else {
                        // Not yet unlocked — show progress
                        VStack(spacing: 12) {
                            Text("Progress")
                                .font(.headline)
                            
                            ProgressView(value: progress)
                                .tint(.accentColor)
                            
                            Text("\(Int(progress * 100))% complete")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Requirement: \(achievement.requirement)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle(isUnlocked ? "Achievement Unlocked" : "Achievement Locked")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.headline.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
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
                .font(.system(size: 36))
                .foregroundColor(isUnlocked ? .yellow : .gray)
                .frame(width: 50)
            
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
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
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
