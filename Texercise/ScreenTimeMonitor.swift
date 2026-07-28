import Foundation
import DeviceActivity
import FamilyControls

final class ScreenTimeMonitor {

    static let shared = ScreenTimeMonitor()
    private let center = DeviceActivityCenter()
    private let appGroup = "group.com.samring.texercise"
    static let maxTrackedMinutes = 200

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
    func ensureMonitoring(selection: FamilyActivitySelection, minutesPerPenalty: Int) {
        StoredActivitySelection.save(selection, to: defaults)
        defaults?.set(minutesPerPenalty, forKey: SharedKeys.minutesPerPenalty)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())

        let lastStartDate = sessionDefaults.string(forKey: sessionDateKey) ?? ""
        let lastHash = sessionDefaults.integer(forKey: sessionHashKey)
        let currentHash = selectionHash(selection, minutesPerPenalty: minutesPerPenalty)

        if lastStartDate == todayString && lastHash == currentHash {
            print("✅ DeviceActivity monitoring already started today — skipping to preserve counters")
            return
        }

        let reason = lastStartDate != todayString ? "new day" : "selection changed"
        print("⚡️ Starting DeviceActivity monitoring (\(reason)) hash=\(currentHash) storedHash=\(lastHash) date=\(lastStartDate)")
        startMonitoringInternal(selection: selection, minutesPerPenalty: minutesPerPenalty, todayString: todayString, hash: currentHash)
    }

    /// Force full stop+restart. Call when user explicitly changes selection.
    func forceRestartMonitoring(selection: FamilyActivitySelection, minutesPerPenalty: Int) {
        StoredActivitySelection.save(selection, to: defaults)
        defaults?.set(minutesPerPenalty, forKey: SharedKeys.minutesPerPenalty)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        let hash = selectionHash(selection, minutesPerPenalty: minutesPerPenalty)

        print("⚡️ Force-restarting DeviceActivity monitoring (user changed selection)")
        startMonitoringInternal(selection: selection, minutesPerPenalty: minutesPerPenalty, todayString: todayString, hash: hash)
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

    func isBlocking() -> Bool {
        defaults?.bool(forKey: SharedKeys.isBlocking) ?? false
    }

    private func startMonitoringInternal(selection: FamilyActivitySelection, minutesPerPenalty: Int, todayString: String, hash: Int) {
        let events = buildEvents(selection: selection, minutesPerPenalty: minutesPerPenalty)
        do {
            center.stopMonitoring([.daily])
            try center.startMonitoring(.daily, during: schedule, events: events)
            sessionDefaults.set(todayString, forKey: sessionDateKey)
            sessionDefaults.set(hash, forKey: sessionHashKey)
            print("✅ DeviceActivity monitoring started — \(events.count) thresholds at every \(minutesPerPenalty) min")
        } catch {
            print("❌ Failed to start monitoring: \(error)")
        }
    }

    private func buildEvents(selection: FamilyActivitySelection, minutesPerPenalty: Int) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for i in 1...ScreenTimeMonitor.maxTrackedMinutes {
            let minuteMark = i * minutesPerPenalty
            events[DeviceActivityEvent.Name("screenUsage_\(minuteMark)")] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                threshold: DateComponents(minute: minuteMark)
            )
        }
        return events
    }

    /// Deterministic hash — must not use Swift.Hasher (randomized per launch).
    private func selectionHash(_ selection: FamilyActivitySelection, minutesPerPenalty: Int) -> Int {
        let appCount = selection.applicationTokens.count
        let catCount = selection.categoryTokens.count
        return (appCount * 31 + catCount) * 31 + minutesPerPenalty
    }
}
