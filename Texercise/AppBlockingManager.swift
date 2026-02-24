import Foundation
import ManagedSettings
import FamilyControls

@MainActor
final class AppBlockingManager: ObservableObject {
    
    static let shared = AppBlockingManager()
    
    @Published var isBlocking = false
    
    private let store = ManagedSettingsStore()
    private let categoryStore = ScreenTimeCategoryStore.shared
    private var lastNetPoints: Int? = nil
    
    // Points threshold below which apps get blocked
    private let blockingThreshold = 0
    
    // Warn when within this many points of blocking
    private let warningThreshold = 5
    
    private init() {}
    
    func update(netPoints: Int, screenTimeMinutesPerPenalty: Int = 15) {
        defer { lastNetPoints = netPoints }
        
        if netPoints < blockingThreshold {
            applyRestrictions()
            NotificationScheduler.cancelBlockingWarning()
        } else if netPoints <= warningThreshold {
            removeRestrictions()
            if let last = lastNetPoints, last > warningThreshold {
                NotificationScheduler.scheduleBlockingWarning(
                    netPoints: netPoints,
                    screenTimeMinutesPerPenalty: screenTimeMinutesPerPenalty
                )
            }
        } else {
            removeRestrictions()
            NotificationScheduler.cancelBlockingWarning()
        }
    }
    
    private func applyRestrictions() {
        guard FamilyControlsManager.shared.isAuthorized else {
            print("⚠️ Cannot block apps - FamilyControls not authorized")
            return
        }
        guard categoryStore.hasSelection else {
            print("⚠️ Cannot block apps - no apps selected")
            return
        }
        
        let selection = categoryStore.activitySelection
        
        // Use tokens from the FamilyActivitySelection
        let appTokens = selection.applicationTokens
        let categoryTokens = selection.categoryTokens
        
        store.shield.applications = appTokens.isEmpty ? nil : appTokens
        store.shield.applicationCategories = categoryTokens.isEmpty ? nil : .specific(categoryTokens)
        
        isBlocking = true
        print("🔒 Apps blocked - net points below threshold")
    }
    
    private func removeRestrictions() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        
        isBlocking = false
        print("🔓 Apps unblocked")
    }
    
    func clearAll() {
        removeRestrictions()
        NotificationScheduler.cancelBlockingWarning()
    }
}
