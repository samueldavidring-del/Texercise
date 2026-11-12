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
    @StateObject private var blockingEventStore = BlockingEventStore()
    @ObservedObject private var quickActionManager = QuickActionManager.shared

    @State private var showingSettings = false
    @State private var showingOnboarding = false
    @State private var selectedTab = 0
    @State private var screenTimePollTimer: Timer? = nil

    private let screenTimePollInterval: TimeInterval = 60
    private let hasOnboardedKey = "hasCompletedOnboarding"

    // MARK: - Feature Flags
    // Set back to `true` to restore the Achievements tab.
    // AchievementsView, AchievementStore and all achievement logic remain intact.
    private static let showAchievementsTab = false

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

    private var earnedPoints: Int {
        let workouts = healthStore.workouts(on: Date())
        let exercises = exerciseStore.exercises(for: Date())
        return Points.today(
            steps: healthStore.stepsToday,
            workouts: workouts,
            exercises: exercises,
            screenMinutes: 0,
            settings: pointSettings.settings
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(showingSettings: $showingSettings)
                .tabItem { Label("Today", systemImage: "star.fill") }
                .tag(0)

            EarnView(selectedTab: $selectedTab)
                .tabItem { Label("Earn", systemImage: "plus.circle.fill") }
                .tag(1)

            HistoryView(showingSettings: $showingSettings)
                .tabItem { Label("History", systemImage: "chart.bar.fill") }
                .tag(2)

            if Self.showAchievementsTab {
                AchievementsView()
                    .tabItem { Label("Achievements", systemImage: "trophy.fill") }
                    .tag(3)
            }
        }
        .environmentObject(healthStore)
        .environmentObject(exerciseStore)
        .environmentObject(screenTimeStore)
        .environmentObject(pointSettings)
        .environmentObject(goalSettings)
        .environmentObject(achievementStore)
        .environmentObject(blockingEventStore)
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
        // The blocking banner now lives inline at the top of TodayView, where
        // it scrolls with the content instead of covering the Settings button.
        .onAppear {
            print("🚀 MainTabView appeared - fetching data")
            NotificationScheduler.cancelScreenTimeWarning()
            exerciseStore.fetchEntries()
            screenTimeStore.fetchEntries()

            if !UserDefaults.standard.bool(forKey: hasOnboardedKey) {
                showingOnboarding = true
            }

            // Wire the store into the singleton consumer once it's available.
            ScreenTimeConsumer.shared.screenTimeStore = screenTimeStore

            ScreenTimeConsumer.shared.consume()
            AppBlockingManager.shared.update(
                netPoints: netPoints,
                earnedPoints: earnedPoints,
                screenTimeMinutesPerPenalty: pointSettings.settings.screenTimeMinutesPerPenalty
            )
            startScreenTimePollTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            print("🔵 App entering foreground - checking pending screen time")
            stopScreenTimePollTimer()
            NotificationScheduler.cancelScreenTimeWarning()
            ScreenTimeConsumer.shared.consume()
            blockingEventStore.refresh()
            AppBlockingManager.shared.syncFromExtension()
            AppBlockingManager.shared.update(
                netPoints: netPoints,
                earnedPoints: earnedPoints,
                screenTimeMinutesPerPenalty: pointSettings.settings.screenTimeMinutesPerPenalty
            )
            updateGoalNotification()
            startScreenTimePollTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            stopScreenTimePollTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickActionTriggered)) { _ in
            print("🚀 MainTabView: switching to Earn tab")
            selectedTab = 1
        }
        .onChange(of: healthStore.stepsToday) {
            AppBlockingManager.shared.update(netPoints: netPoints, earnedPoints: earnedPoints, screenTimeMinutesPerPenalty: pointSettings.settings.screenTimeMinutesPerPenalty)
        }
        .onChange(of: healthStore.recentWorkouts.count) {
            AppBlockingManager.shared.update(netPoints: netPoints, earnedPoints: earnedPoints, screenTimeMinutesPerPenalty: pointSettings.settings.screenTimeMinutesPerPenalty)
        }
        .onChange(of: exerciseStore.exercises(for: Date()).count) {
            AppBlockingManager.shared.update(netPoints: netPoints, earnedPoints: earnedPoints, screenTimeMinutesPerPenalty: pointSettings.settings.screenTimeMinutesPerPenalty)
        }
        .onChange(of: screenTimeStore.totalMinutes(on: Date())) {
            AppBlockingManager.shared.update(netPoints: netPoints, earnedPoints: earnedPoints, screenTimeMinutesPerPenalty: pointSettings.settings.screenTimeMinutesPerPenalty)
        }
    }

    // MARK: - Poll Timer

    private func startScreenTimePollTimer() {
        stopScreenTimePollTimer()
        let timer = Timer.scheduledTimer(withTimeInterval: screenTimePollInterval, repeats: true) { _ in
            ScreenTimeConsumer.shared.consume()
            if screenTimeStore.totalMinutes(on: Date()) > 0 {
                AppBlockingManager.shared.update(
                    netPoints: netPoints,
                    earnedPoints: earnedPoints,
                    screenTimeMinutesPerPenalty: pointSettings.settings.screenTimeMinutesPerPenalty
                )
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        screenTimePollTimer = timer
        print("⏱ Screen time poll timer started (every \(Int(screenTimePollInterval))s)")
    }

    private func stopScreenTimePollTimer() {
        screenTimePollTimer?.invalidate()
        screenTimePollTimer = nil
    }

    // MARK: - Goal Notification

    private func updateGoalNotification() {
        let workoutMinutes = healthStore.workouts(on: Date()).reduce(0) { $0 + $1.durationMinutes }
        let exerciseReps = exerciseStore.exercises(for: Date()).reduce(0) { $0 + Int($1.count) }
        NotificationScheduler.updateGoalReminder(
            goals: goalSettings.goals,
            stepsToday: healthStore.stepsToday,
            pointsToday: netPoints,
            workoutMinutesToday: workoutMinutes,
            exerciseRepsToday: exerciseReps
        )
    }
}

#Preview {
    MainTabView()
}
