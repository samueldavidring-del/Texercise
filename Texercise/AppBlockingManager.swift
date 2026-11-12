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

    /// Distinct threshold events the extension has recorded today. Each one
    /// is one point deducted, and the App Group log is always readable
    /// synchronously — unlike Core Data, which can briefly report fewer
    /// minutes while it reloads.
    private var firedPenaltyPointsToday: Int {
        let log = (defaults?.array(forKey: SharedKeys.screenTimeEventLog) as? [String]) ?? []
        let names = Set(log.compactMap { $0.split(separator: "|").first.map(String.init) })
        return names.count
    }

    /// - Parameter todayScreenTimeMinutes: minutes logged so far today, if the
    ///   caller has them. Used only as a backstop in case the extension's
    ///   threshold event was missed; safe to omit.
    func update(netPoints: Int,
                earnedPoints: Int,
                screenTimeMinutesPerPenalty: Int = 1,
                todayScreenTimeMinutes: Int? = nil) {

        // The debug log showed blocks being lifted moments after they were
        // applied, by update calls that briefly computed points >= 0 from
        // half-loaded data. Never trust a number more generous than what the
        // extension has actually recorded.
        let floorPoints = earnedPoints - firedPenaltyPointsToday
        let effectivePoints = min(netPoints, floorPoints)

        defer { lastNetPoints = effectivePoints }

        // A lockout from a previous day must never carry over.
        if HardBlock.clearIfStale(in: defaults) {
            print("🌅 Cleared stale daily-limit lockout from a previous day")
        }

        ScreenTimeMonitor.shared.syncNetPoints(effectivePoints)
        ScreenTimeMonitor.shared.syncEarnedPoints(earnedPoints)

        print("🔵 AppBlockingManager.update: netPoints=\(netPoints), floor=\(floorPoints), earned=\(earnedPoints), last=\(lastNetPoints ?? -999)")

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

        if effectivePoints < blockingThreshold {
            applyRestrictions()
            NotificationScheduler.cancelScreenTimeWarning()
            NotificationScheduler.cancelBlockingWarning()

        } else if effectivePoints <= warningThreshold {
            removeRestrictions(reason: "warning zone net=\(netPoints) floor=\(floorPoints) earned=\(earnedPoints)")
            if let last = lastNetPoints, last > warningThreshold {
                print("⚠️ Crossed into warning zone — firing warning notification")
                NotificationScheduler.scheduleScreenTimeWarning(minutesLeft: effectivePoints)
            }

        } else {
            removeRestrictions(reason: "above warning net=\(netPoints) floor=\(floorPoints) earned=\(earnedPoints)")
            NotificationScheduler.cancelBlockingWarning()
            NotificationScheduler.cancelScreenTimeWarning()
        }
    }

    /// Picks up a block the extension applied while the app was closed.
    /// Only ever adds a block — lifting one is update()'s job, because the
    /// extension's flag also goes false when iOS stops monitoring mid-day.
    func syncFromExtension() {
        if HardBlock.clearIfStale(in: defaults) {
            print("🌅 Cleared stale daily-limit lockout from a previous day")
        }

        let hardBlocked = HardBlock.isActive(in: defaults)
        isHardBlocked = hardBlocked

        if hardBlocked {
            print("🔵 syncFromExtension: daily limit lockout active")
            applyRestrictions()
            return
        }

        let extensionIsBlocking = ScreenTimeMonitor.shared.isBlocking()
        print("🔵 syncFromExtension: extensionIsBlocking=\(extensionIsBlocking)")
        if extensionIsBlocking && !isBlocking {
            applyRestrictions()
        }
    }

    /// Rewrites the shield if we think we're blocking. Shield writes made
    /// while iOS considered the app unauthorized are silently dropped, so
    /// call this once authorization is confirmed.
    func reassertIfBlocking() {
        guard isBlocking || isHardBlocked else { return }
        appendDebugLog("MAIN_BLOCK reassert after authorization confirmed")
        applyRestrictions()
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
        // No authorization guard: the cached flag can be wrong. But if iOS
        // says we're not approved right now, the write below will be ignored,
        // so ask for a silent re-confirm (reassertIfBlocking runs after it).
        let liveStatus = AuthorizationCenter.shared.authorizationStatus
        if liveStatus != .approved {
            FamilyControlsManager.shared.confirmAuthorizationSilently(reason: "block attempted while status=\(liveStatus)")
        }

        // Prefer the in-memory selection; fall back to the copy saved in the
        // App Group (the same one the extension blocks with).
        var selection = categoryStore.activitySelection
        if selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty,
           let stored = StoredActivitySelection.load(from: defaults) {
            selection = stored
        }

        let appTokens = selection.applicationTokens
        let categoryTokens = selection.categoryTokens

        guard !appTokens.isEmpty || !categoryTokens.isEmpty else {
            print("⚠️ Cannot block - no apps selected")
            appendDebugLog("MAIN_BLOCK skipped — no apps or categories selected")
            return
        }

        store.shield.applications = appTokens.isEmpty ? nil : appTokens
        store.shield.applicationCategories = categoryTokens.isEmpty ? nil : .specific(categoryTokens)

        let wasBlocking = isBlocking
        isBlocking = true
        defaults?.set(true, forKey: SharedKeys.isBlocking)
        if !wasBlocking {
            appendDebugLog("MAIN_BLOCK applied apps=\(appTokens.count) cats=\(categoryTokens.count) auth=\(liveStatus)")
        }
        print("🔒 Apps blocked")
    }

    private func removeRestrictions(reason: String) {
        let wasBlocking = isBlocking || (defaults?.bool(forKey: SharedKeys.isBlocking) ?? false)
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        isBlocking = false
        defaults?.set(false, forKey: SharedKeys.isBlocking)
        if wasBlocking {
            appendDebugLog("MAIN_UNBLOCK \(reason)")
        }
        print("🔓 Apps unblocked (\(reason))")
    }

    func clearAll() {
        removeRestrictions(reason: "clearAll")
        HardBlock.clear(in: defaults)
        isHardBlocked = false
        NotificationScheduler.cancelScreenTimeWarning()
        NotificationScheduler.cancelBlockingWarning()
    }

    // MARK: - Debug Log

    private func appendDebugLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        var log = defaults?.string(forKey: SharedKeys.debugLog) ?? ""
        log += line
        if log.count > 20_000 {
            let trimmed = String(log.suffix(15_000))
            log = String(trimmed.drop(while: { $0 != "\n" }).dropFirst())
        }
        defaults?.set(log, forKey: SharedKeys.debugLog)
    }
}
