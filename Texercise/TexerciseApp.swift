import SwiftUI
import UserNotifications

@main
struct TexerciseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    
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
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                DispatchQueue.main.async {
                    if let shortcut = appDelegate.lastShortcut {
                        appDelegate.lastShortcut = nil
                        if let exercise = exerciseType(for: shortcut.type) {
                            UserDefaults.standard.set(exercise, forKey: "pendingQuickActionExercise")
                            NotificationCenter.default.post(name: .quickActionTriggered, object: exercise)
                        }
                    }
                }
            }
        }
    }
    
    private func exerciseType(for shortcutType: String) -> String? {
        switch shortcutType {
        case "com.samuelring.texercise.pushups": return "Pushups"
        case "com.samuelring.texercise.squats":  return "Squats"
        case "com.samuelring.texercise.situps":  return "Sit-ups"
        case "com.samuelring.texercise.lunges":  return "Lunges"
        case "com.samuelring.texercise.plank":   return "Plank"
        default: return nil
        }
    }
}

struct ContentView: View {
    @State private var showingSplash = true
    
    var body: some View {
        ZStack {
            MainTabView()
            
            if showingSplash {
                SplashScreenView(onFinished: {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showingSplash = false
                    }
                })
                .zIndex(1)
                .transition(.opacity)
            }
        }
        .onAppear {
            print("✅ ContentView appeared")
        }
    }
}
