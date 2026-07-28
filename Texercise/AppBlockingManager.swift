import Foundation
import ManagedSettings
import FamilyControls

@MainActor
final class AppBlockingManager: ObservableObject {
    
    static let shared = AppBlockingManager()
    
    @Published var isBlocking = false
    
    private let store = ManagedSettingsStore()
    private let categoryStore = ScreenTimeCategoryStore.shared
    private let appGroup = "group.com.samring.texercise"
    private var lastNetPoints: Int? = nil
    
    private let blockingThreshold = 0
    private let warningThreshold = 5
    
    private init() {}
    
    func update(netPoints: Int, earnedPoints: Int, screenTimeMinutesPerPenalty: Int = 1) {
        defer { lastNetPoints = netPoints }
        
        ScreenTimeMonitor.shared.syncNetPoints(netPoints)
        ScreenTimeMonitor.shared.syncEarnedPoints(earnedPoints)
        
        print("🔵 AppBlockingManager.update: netPoints=\(netPoints), earnedPoints=\(earnedPoints), lastNetPoints=\(lastNetPoints ?? -999)")
        
        if netPoints < blockingThreshold {
            print("🔴 Below threshold — applying restrictions")
            applyRestrictions()
            NotificationScheduler.cancelScreenTimeWarning()
            NotificationScheduler.cancelBlockingWarning()

        } else if netPoints <= warningThreshold {
            print("🟡 Warning zone (\(netPoints) pts) — removing restrictions")
            removeRestrictions()
            if let last = lastNetPoints, last > warningThreshold {
                print("⚠️ Crossed into warning zone — firing warning notification")
                NotificationScheduler.scheduleScreenTimeWarning(minutesLeft: netPoints)
            }

        } else {
            print("🟢 Above warning (\(netPoints) pts) — removing restrictions")
            removeRestrictions()
            NotificationScheduler.cancelBlockingWarning()
            NotificationScheduler.cancelScreenTimeWarning()
        }
    }
    
    func syncFromExtension() {
        let extensionIsBlocking = ScreenTimeMonitor.shared.isBlocking()
        print("🔵 syncFromExtension: extensionIsBlocking=\(extensionIsBlocking)")
        if extensionIsBlocking && !isBlocking {
            applyRestrictions()
        } else if !extensionIsBlocking && isBlocking {
            removeRestrictions()
        }
    }
    
    func startAutoMonitoring(selection: FamilyActivitySelection, minutesPerPenalty: Int) {
        ScreenTimeMonitor.shared.forceRestartMonitoring(
            selection: selection,
            minutesPerPenalty: minutesPerPenalty
        )
    }
    
    private func applyRestrictions() {
        guard FamilyControlsManager.shared.isAuthorized else {
            print("⚠️ Cannot block - FamilyControls not authorized")
            return
        }
        guard categoryStore.hasSelection else {
            print("⚠️ Cannot block - no apps selected")
            return
        }
        
        let selection = categoryStore.activitySelection
        let appTokens = selection.applicationTokens
        let categoryTokens = selection.categoryTokens
        
        store.shield.applications = appTokens.isEmpty ? nil : appTokens
        store.shield.applicationCategories = categoryTokens.isEmpty ? nil : .specific(categoryTokens)
        
        isBlocking = true
        UserDefaults(suiteName: appGroup)?.set(true, forKey: SharedKeys.isBlocking)
        print("🔒 Apps blocked")
    }
    
    private func removeRestrictions() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        isBlocking = false
        UserDefaults(suiteName: appGroup)?.set(false, forKey: SharedKeys.isBlocking)
        print("🔓 Apps unblocked")
    }
    
    func clearAll() {
        removeRestrictions()
        NotificationScheduler.cancelScreenTimeWarning()
        NotificationScheduler.cancelBlockingWarning()
    }
}
