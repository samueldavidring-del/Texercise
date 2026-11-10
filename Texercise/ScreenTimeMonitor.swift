import Foundation
import DeviceActivity
import FamilyControls

final class ScreenTimeMonitor {

    static let shared = ScreenTimeMonitor()
    private let center = DeviceActivityCenter()
    private let appGroup = "group.com.samring.texercise"

    /// How far to keep counting when no daily limit is configured.
    /// Replaces the old fixed 200, which caused tracking to stop dead after
    /// 200 minutes of usage because no further threshold events existed.
    static let defaultTrackedMinutes = 480

    /// Safety ceiling on the number of threshold events registered in one
    /// call. There is no documented upper bound in DeviceActivity and large
    /// sets are slow to install, so this stays deliberately conservative.
    static let maxEventCount = 500

    // Session guard stored in STANDARD UserDefaults (main app only).
    // The app group UserDefaults is shared with the extension and can be
    // affected by extension writes — using standard avoids any cross-process
    // interference with the session guard.
    private let sessionDefaults = UserDefaults.standard
    private let sessionDateKey = "monitoringSessionDate"
    private let sessionHashKey = "monitoringSessionHash"

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    private var schedule: DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true,
            warningTime: DateComponents(minute: 1)
        )
    }

    private init() {}

    /// Call on every app launch. Skips startMonitoring if already started today
    /// with the same selection — preserving DeviceActivity's cumulative counters.
    ///
    /// - Parameter maxDailyMinutes: hard ceiling in minutes, 0 for none.
    ///   Pass nil to reuse whatever is already stored in the App Group.
    func ensureMonitoring(selection: FamilyActivitySelection,
                          minutesPerPenalty: Int,
                          maxDailyMinutes: Int? = nil) {

        let limit = resolvedLimit(maxDailyMinutes)

        StoredActivitySelection.save(selection, to: defaults)
        defaults?.set(max(1, minutesPerPenalty), forKey: SharedKeys.minutesPerPenalty)
        defaults?.set(limit, forKey: SharedKeys.maxDailyScreenTimeMinutes)

        // A lockout from a previous day must not survive into today.
        if HardBlock.clearIfStale(in: defaults) {
            print("🌅 Cleared stale daily-limit lockout from a previous day")
        }

        let todayString = SharedDate.todayString()

        let lastStartDate = sessionDefaults.string(forKey: sessionDateKey) ?? ""
        let lastHash = sessionDefaults.integer(forKey: sessionHashKey)
        let currentHash = selectionHash(selection,
                                        minutesPerPenalty: minutesPerPenalty,
                                        maxDailyMinutes: limit)

        if lastStartDate == todayString && lastHash == currentHash {
            print("✅ DeviceActivity monitoring already started today — skipping to preserve counters")
            return
        }

        let reason = lastStartDate != todayString ? "new day" : "settings changed"
        print("⚡️ Starting DeviceActivity monitoring (\(reason)) hash=\(currentHash) storedHash=\(lastHash) date=\(lastStartDate)")
        startMonitoringInternal(selection: selection,
                                minutesPerPenalty: minutesPerPenalty,
                                maxDailyMinutes: limit,
                                todayString: todayString,
                                hash: currentHash)
    }

    /// Force full stop+restart. Call when the user explicitly changes the app
    /// selection, the penalty rate, or the daily limit.
    func forceRestartMonitoring(selection: FamilyActivitySelection,
                                minutesPerPenalty: Int,
                                maxDailyMinutes: Int? = nil) {

        let limit = resolvedLimit(maxDailyMinutes)

        StoredActivitySelection.save(selection, to: defaults)
        defaults?.set(max(1, minutesPerPenalty), forKey: SharedKeys.minutesPerPenalty)
        defaults?.set(limit, forKey: SharedKeys.maxDailyScreenTimeMinutes)

        let todayString = SharedDate.todayString()
        let hash = selectionHash(selection,
                                 minutesPerPenalty: minutesPerPenalty,
                                 maxDailyMinutes: limit)

        print("⚡️ Force-restarting DeviceActivity monitoring (user changed settings)")
        startMonitoringInternal(selection: selection,
                                minutesPerPenalty: minutesPerPenalty,
                                maxDailyMinutes: limit,
                                todayString: todayString,
                                hash: hash)
    }

    func stopMonitoring() {
        center.stopMonitoring([.daily])
        sessionDefaults.removeObject(forKey: sessionDateKey)
        sessionDefaults.removeObject(forKey: sessionHashKey)
        print("🛑 DeviceActivity monitoring stopped")
    }

    func syncNetPoints(_ points: Int) {
        defaults?.set(points, forKey: SharedKeys.netPoints)
        defaults?.synchronize()
        print("🔵 Synced net points to App Group: \(points)")
    }

    func syncEarnedPoints(_ points: Int) {
        defaults?.set(points, forKey: SharedKeys.earnedPoints)
        defaults?.synchronize()
        print("🔵 Synced earned points to App Group: \(points)")
    }

    /// Writes the limit through without touching monitoring. Use when you only
    /// need the extension to see a new value; use forceRestartMonitoring when
    /// the registered threshold events themselves need to change.
    func syncMaxDailyLimit(_ minutes: Int) {
        defaults?.set(max(0, minutes), forKey: SharedKeys.maxDailyScreenTimeMinutes)
        defaults?.synchronize()
        print("🔵 Synced max daily screen time limit: \(max(0, minutes)) min")
    }

    var maxDailyLimitMinutes: Int {
        HardBlock.limit(in: defaults)
    }

    func isBlocking() -> Bool {
        defaults?.bool(forKey: SharedKeys.isBlocking) ?? false
    }

    /// True if today's hard daily limit has been reached.
    func isHardBlockedToday() -> Bool {
        HardBlock.isActive(in: defaults)
    }

    // MARK: - Internals

    private func resolvedLimit(_ explicit: Int?) -> Int {
        if let explicit { return max(0, explicit) }
        return HardBlock.limit(in: defaults)
    }

    private func startMonitoringInternal(selection: FamilyActivitySelection,
                                         minutesPerPenalty: Int,
                                         maxDailyMinutes: Int,
                                         todayString: String,
                                         hash: Int) {

        let events = buildEvents(selection: selection,
                                 minutesPerPenalty: minutesPerPenalty,
                                 maxDailyMinutes: maxDailyMinutes)
        do {
            center.stopMonitoring([.daily])
            try center.startMonitoring(.daily, during: schedule, events: events)
            sessionDefaults.set(todayString, forKey: sessionDateKey)
            sessionDefaults.set(hash, forKey: sessionHashKey)

            let limitDescription = maxDailyMinutes > 0 ? "\(maxDailyMinutes) min" : "none"
            print("✅ DeviceActivity monitoring started — \(events.count) events, every \(minutesPerPenalty) min, daily limit: \(limitDescription)")
        } catch {
            print("❌ Failed to start monitoring: \(error)")
        }
    }

    private func buildEvents(selection: FamilyActivitySelection,
                             minutesPerPenalty: Int,
                             maxDailyMinutes: Int) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        let step = max(1, minutesPerPenalty)

        // Register per-minute counting events all the way to the ceiling.
        // When a limit is set, running out of events and hitting the lockout
        // now coincide, so counting can no longer stop early while usage
        // continues unrecorded.
        let trackedMinutes = maxDailyMinutes > 0 ? maxDailyMinutes : ScreenTimeMonitor.defaultTrackedMinutes
        let eventCount = min(ScreenTimeMonitor.maxEventCount,
                             max(1, Int(ceil(Double(trackedMinutes) / Double(step)))))

        for i in 1...eventCount {
            let minuteMark = i * step
            let name = DeviceActivityEvent.Name("\(SharedEventNames.screenUsagePrefix)\(minuteMark)")
            events[name] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                threshold: DateComponents(minute: minuteMark)
            )
        }

        // A dedicated lockout event. Kept separate from the screenUsage_ series
        // on purpose: the counting path depends on sequential ordering and is
        // vulnerable to re-fire bursts, whereas this one only has to fire once
        // to be correct.
        if maxDailyMinutes > 0 {
            let name = DeviceActivityEvent.Name(SharedEventNames.dailyLimitReached)
            events[name] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                threshold: DateComponents(minute: maxDailyMinutes)
            )
        }

        return events
    }

    /// Deterministic hash — must not use Swift.Hasher (randomized per launch).
    /// Includes the daily limit so changing it restarts monitoring and
    /// re-registers the threshold events.
    private func selectionHash(_ selection: FamilyActivitySelection,
                               minutesPerPenalty: Int,
                               maxDailyMinutes: Int) -> Int {
        let appCount = selection.applicationTokens.count
        let catCount = selection.categoryTokens.count
        var hash = appCount * 31 + catCount
        hash = hash * 31 + minutesPerPenalty
        hash = hash * 31 + maxDailyMinutes
        return hash
    }
}
