import Foundation

// Shared notification name for quick action events
extension Notification.Name {
    static let quickActionTriggered = Notification.Name("quickActionTriggered")
}

/// Bridges UIKit quick action callbacks into SwiftUI via ObservableObject.
class QuickActionManager: ObservableObject {
    static let shared = QuickActionManager()
    private let key = "pendingQuickActionExercise"
    
    private init() {}
    
    func consumePendingExercise() -> String? {
        guard let exercise = UserDefaults.standard.string(forKey: key) else { return nil }
        UserDefaults.standard.removeObject(forKey: key)
        return exercise
    }
}
