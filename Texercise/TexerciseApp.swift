import SwiftUI
import UserNotifications

@main
struct TexerciseApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        print("🚀 App initialized, Core Data ready")
        requestNotificationPermission()
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
                NotificationScheduler.scheduleGoalReminder()
            } else {
                print("❌ Notification permission denied: \(error?.localizedDescription ?? "unknown")")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        MainTabView()
            .onAppear {
                print("✅ ContentView appeared")
            }
    }
}
