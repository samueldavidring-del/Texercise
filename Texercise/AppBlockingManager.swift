import Foundation
import ManagedSettings
import FamilyControls

@MainActor
final class AppBlockingManager: ObservableObject {

    static let shared = AppBlockingManager()

    @Published var isBlocking = false

    /// True when today's hard daily screen time limit has been reached.
    /// Distinct from `isBlocking`, which is also true when simply out of
    /// points. Use this to show "locked until tomorrow" rather than
    /// "go earn more points" — only one of those has an action attached.
    @Published var isHardBlocked = false

    private let store = ManagedSettingsStore()
    private let categoryStore = ScreenTimeCategoryStore.shared
    private let appGroup = "group.com.samring.texercise"
    private var lastNetPoints: Int? = nil

    private let blockingThreshold = 0
    private let warningThreshold = 5

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    private init() {}

    /// The configured daily ceiling in minutes. 0 means no limit.
    var dailyLimitMinutes: Int {
        HardBlock.limit(in: defaults)
    }

    /// - Parameter todayScreenTimeMinutes: minutes logged so far today, if the
    ///   caller has them. Used only as a backstop in case the extension's
    ///   threshold event was missed; safe to omit.
    func update(netPoints: Int,
                earnedPoints: Int,
                screenTimeMinutesPerPenalty: Int = 1,
                todayScreenTimeMinutes: Int? = nil) {

        defer { lastNetPoints = netPoints }

        // A lockout from a previous day must never carry over.
        if HardBlock.clearIfStale(in: defaults) {
            print("🌅 Cleared stale daily-limit lockout from a previous day")
        }

        ScreenTimeMonitor.shared.syncNetPoints(netPoints)
        ScreenTimeMonitor.shared.syncEarnedPoints(earnedPoints)

        print("🔵 AppBlockingManager.update: netPoints=\(netPoints), earnedPoints=\(earnedPoints), lastNetPoints=\(lastNetPoints ?? -999)")

        // Backstop: if the app knows more minutes have been used than the
        // ceiling allows, apply the lockout here. Covers the case where the
        // DeviceActivity event was delayed or never delivered.
        let limit = dailyLimitMinutes
        if limit > 0,
           let used = todayScreenTimeMinutes,
           used >= limit,
           !HardBlock.isActive(in: defaults) {
            print("⛔️ Daily limit reached via app-side check (\(used)/\(limit) min)")
            HardBlock.activate(in: defaults)
        }

        // The hard limit outranks the points system entirely. Checked before
        // any points arithmetic so no branch below can lift the shield.
        if HardBlock.isActive(in: defaults) {
            print("⛔️ Daily limit reached — apps locked regardless of points")
            isHardBlocked = true
            applyRestrictions()
            NotificationScheduler.cancelScreenTimeWarning()
            NotificationScheduler.cancelBlockingWarning()
            return
        }

        isHardBlocked = false

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
        if HardBlock.clearIfStale(in: defaults) {
            print("🌅 Cleared stale daily-limit lockout from a previous day")
        }

        let hardBlocked = HardBlock.isActive(in: defaults)
        isHardBlocked = hardBlocked

        if hardBlocked {
            print("🔵 syncFromExtension: daily limit lockout active")
            if !isBlocking { applyRestrictions() }
            return
        }

        let extensionIsBlocking = ScreenTimeMonitor.shared.isBlocking()
        print("🔵 syncFromExtension: extensionIsBlocking=\(extensionIsBlocking)")
        if extensionIsBlocking && !isBlocking {
            applyRestrictions()
        } else if !extensionIsBlocking && isBlocking {
            removeRestrictions()
        }
    }

    func startAutoMonitoring(selection: FamilyActivitySelection,
                             minutesPerPenalty: Int,
                             maxDailyMinutes: Int? = nil) {
        ScreenTimeMonitor.shared.forceRestartMonitoring(
            selection: selection,
            minutesPerPenalty: minutesPerPenalty,
            maxDailyMinutes: maxDailyMinutes
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
        defaults?.set(true, forKey: SharedKeys.isBlocking)
        print("🔒 Apps blocked")
    }

    private func removeRestrictions() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        isBlocking = false
        defaults?.set(false, forKey: SharedKeys.isBlocking)
        print("🔓 Apps unblocked")
    }

    func clearAll() {
        removeRestrictions()
        HardBlock.clear(in: defaults)
        isHardBlocked = false
        NotificationScheduler.cancelScreenTimeWarning()
        NotificationScheduler.cancelBlockingWarning()
    }
}
