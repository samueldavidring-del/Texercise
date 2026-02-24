import Foundation
import FamilyControls
import ManagedSettings

final class ScreenTimeCategoryStore: ObservableObject {
    
    static let shared = ScreenTimeCategoryStore()
    
    // The user's selected apps/categories from FamilyActivityPicker
    @Published var activitySelection: FamilyActivitySelection {
        didSet { save() }
    }
    
    // Whether tracking is enabled at all
    @Published var isTrackingEnabled: Bool {
        didSet { UserDefaults.standard.set(isTrackingEnabled, forKey: Keys.trackingEnabled) }
    }
    
    private enum Keys {
        static let activitySelection = "screenTimeActivitySelection"
        static let trackingEnabled   = "screenTimeTrackingEnabled"
    }
    
    private init() {
        self.isTrackingEnabled = UserDefaults.standard.bool(forKey: Keys.trackingEnabled)
        
        if let data = UserDefaults.standard.data(forKey: Keys.activitySelection),
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            self.activitySelection = decoded
        } else {
            self.activitySelection = FamilyActivitySelection()
        }
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(activitySelection) {
            UserDefaults.standard.set(encoded, forKey: Keys.activitySelection)
        }
    }
    
    // True if the user has selected at least one app or category
    var hasSelection: Bool {
        !activitySelection.applications.isEmpty || !activitySelection.categories.isEmpty
    }
    
    // Human-readable summary of what's being tracked
    var selectionSummary: String {
        let appCount = activitySelection.applications.count
        let catCount = activitySelection.categories.count
        
        if appCount == 0 && catCount == 0 {
            return "Nothing selected"
        }
        
        var parts: [String] = []
        if appCount > 0 { parts.append("\(appCount) app\(appCount == 1 ? "" : "s")") }
        if catCount > 0 { parts.append("\(catCount) categor\(catCount == 1 ? "y" : "ies")") }
        return parts.joined(separator: ", ")
    }
}
