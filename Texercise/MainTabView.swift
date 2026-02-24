import SwiftUI
import FamilyControls

struct MainTabView: View {
    @StateObject private var healthStore = HealthStore()
    @StateObject private var exerciseStore = ExerciseStore()
    @StateObject private var screenTimeStore = ScreenTimeStore()
    @StateObject private var pointSettings = PointSettingsStore()
    @StateObject private var goalSettings = GoalSettingsStore()
    @StateObject private var achievementStore = AchievementStore()
    @StateObject private var blockingManager = AppBlockingManager.shared
    
    @State private var showingSettings = false
    @State private var showingOnboarding = false
    
    private let hasOnboardedKey = "hasCompletedOnboarding"
    
    // Compute net points at the top level so we can watch for changes
    private var netPoints: Int {
        let workouts = healthStore.workouts(on: Date())
        let exercises = exerciseStore.exercises(for: Date())
        let screenMinutes = screenTimeStore.totalMinutes(on: Date())
        return Points.today(
            steps: healthStore.stepsToday,
            workouts: workouts,
            exercises: exercises,
            screenMinutes: screenMinutes,
            settings: pointSettings.settings
        )
    }
    
    var body: some View {
        TabView {
            TodayView(showingSettings: $showingSettings)
                .tabItem {
                    Label("Today", systemImage: "star.fill")
                }
            
            EarnView()
                .tabItem {
                    Label("Earn", systemImage: "plus.circle.fill")
                }
            
            HistoryView(showingSettings: $showingSettings)
                .tabItem {
                    Label("History", systemImage: "chart.bar.fill")
                }
            
            AchievementsView()
                .tabItem {
                    Label("Achievements", systemImage: "trophy.fill")
                }
        }
        .environmentObject(healthStore)
        .environmentObject(exerciseStore)
        .environmentObject(screenTimeStore)
        .environmentObject(pointSettings)
        .environmentObject(goalSettings)
        .environmentObject(achievementStore)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(pointSettings)
                .environmentObject(goalSettings)
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView()
                .environmentObject(healthStore)
                .interactiveDismissDisabled(true)
        }
        // Show blocking banner when apps are restricted
        .overlay(alignment: .top) {
            if blockingManager.isBlocking {
                BlockingBannerView()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: blockingManager.isBlocking)
        .onAppear {
            print("🚀 MainTabView appeared - fetching data")
            exerciseStore.fetchEntries()
            screenTimeStore.fetchEntries()
            
            if !UserDefaults.standard.bool(forKey: hasOnboardedKey) {
                showingOnboarding = true
            }
            
            // Initial blocking check
            AppBlockingManager.shared.update(
                netPoints: netPoints,
                screenTimeMinutesPerPenalty: pointSettings.settings.screenTimeMinutesPerPenalty
            )
        }
        // Re-evaluate blocking whenever any relevant data changes
        .onChange(of: healthStore.stepsToday) { _ in
            AppBlockingManager.shared.update(netPoints: netPoints, screenTimeMinutesPerPenalty: pointSettings.settings.screenTimeMinutesPerPenalty)
        }
        .onChange(of: healthStore.recentWorkouts.count) { _ in
            AppBlockingManager.shared.update(netPoints: netPoints, screenTimeMinutesPerPenalty: pointSettings.settings.screenTimeMinutesPerPenalty)
        }
        .onChange(of: exerciseStore.exercises(for: Date()).count) { _ in
            AppBlockingManager.shared.update(netPoints: netPoints, screenTimeMinutesPerPenalty: pointSettings.settings.screenTimeMinutesPerPenalty)
        }
        .onChange(of: screenTimeStore.totalMinutes(on: Date())) { _ in
            AppBlockingManager.shared.update(netPoints: netPoints, screenTimeMinutesPerPenalty: pointSettings.settings.screenTimeMinutesPerPenalty)
        }
    }
}

#Preview {
    MainTabView()
}
