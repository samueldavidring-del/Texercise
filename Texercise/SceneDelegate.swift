import UIKit

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        print("⚡️ SceneDelegate performActionFor: \(shortcutItem.type)")
        let exerciseType: String
        switch shortcutItem.type {
        case "com.samuelring.texercise.pushups": exerciseType = "Pushups"
        case "com.samuelring.texercise.squats":  exerciseType = "Squats"
        case "com.samuelring.texercise.situps":  exerciseType = "Sit-ups"
        case "com.samuelring.texercise.lunges":  exerciseType = "Lunges"
        case "com.samuelring.texercise.plank":   exerciseType = "Plank"
        default:
            print("❌ Unknown shortcut: \(shortcutItem.type)")
            completionHandler(false)
            return
        }
        print("✅ SceneDelegate storing exercise: \(exerciseType)")
        UserDefaults.standard.set(exerciseType, forKey: "pendingQuickActionExercise")
        NotificationCenter.default.post(name: .quickActionTriggered, object: exerciseType)
        completionHandler(true)
    }
}
