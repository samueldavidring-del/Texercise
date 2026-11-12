import Foundation

/// Consumes screen time events by comparing what DeviceActivity has fired
/// against what has already been logged in Core Data today.
///
/// Logic:
///   totalFiredToday  = number of distinct event names in screenTimeEventLog (each = 1 threshold)
///   totalLoggedToday = sum of all Auto-tracked screen time minutes in Core Data for today
///   delta            = max(0, totalFiredToday - totalLoggedToday)
///
/// If delta > 0, log it. This naturally handles:
///   - Normal case: delta = 1 (one new threshold fired since last check)
///   - Catch-up case: delta = N (app was closed, N thresholds fired in background)
///   - Re-fire case: delta = 0 (startMonitoring reset counters, re-fires don't
///     increase totalFiredToday beyond what was already logged)
///
/// The only requirement is that screenTimeStore reflects today's logged minutes
/// accurately — which it does since addEntry saves to Core Data and fetchEntries
/// keeps the in-memory array current.
final class ScreenTimeConsumer {

    static let shared = ScreenTimeConsumer()
    private init() {}

    private let appGroup = "group.com.samring.texercise"
    private var isConsuming = false

    weak var screenTimeStore: ScreenTimeStore?

    func consume() {
        guard !isConsuming else {
            print("🔵 ScreenTimeConsumer: skipped — already consuming")
            return
        }
        guard let store = screenTimeStore else {
            print("🔵 ScreenTimeConsumer: no screenTimeStore reference")
            return
        }
        isConsuming = true

        let defaults = UserDefaults(suiteName: appGroup)
        defaults?.synchronize()

        let minutesPerPenalty = max(1, defaults?.integer(forKey: SharedKeys.minutesPerPenalty) ?? 1)

        // How many threshold events has DeviceActivity fired today?
        // Count each event name once. A screenUsage_N name can only genuinely
        // fire once per day; duplicates in the log are re-fires from a
        // monitoring restart. This also corrects any duplicates that were
        // logged before the extension started filtering them.
        let eventLog = (defaults?.array(forKey: SharedKeys.screenTimeEventLog) as? [String]) ?? []
        let uniqueEventNames = Set(eventLog.compactMap { entry in
            entry.split(separator: "|").first.map(String.init)
        })
        let totalFiredToday = uniqueEventNames.count
        if uniqueEventNames.count != eventLog.count {
            appendDebugLog("MAIN_CONSUME dedup raw=\(eventLog.count) unique=\(uniqueEventNames.count)")
        }

        // How many minutes have already been logged in Core Data today?
        let totalLoggedToday = store.totalMinutes(on: Date())

        // Each event = minutesPerPenalty minutes
        let totalFiredMinutes = totalFiredToday * minutesPerPenalty
        let delta = max(0, totalFiredMinutes - totalLoggedToday)

        guard delta > 0 else {
            print("🔵 ScreenTimeConsumer: no new minutes (fired=\(totalFiredToday) events=\(totalFiredMinutes)min, logged=\(totalLoggedToday)min)")
            appendDebugLog("MAIN_CONSUME no_new fired=\(totalFiredToday)(\(totalFiredMinutes)min) logged=\(totalLoggedToday)min")
            isConsuming = false
            return
        }

        print("📱 ScreenTimeConsumer: logging \(delta) min (fired=\(totalFiredToday) events=\(totalFiredMinutes)min, logged=\(totalLoggedToday)min)")
        appendDebugLog("MAIN_CONSUME delta=\(delta)min fired=\(totalFiredToday)(\(totalFiredMinutes)min) logged=\(totalLoggedToday)min")

        store.addEntry(date: Date(), minutes: delta, category: "Auto-tracked")

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.isConsuming = false
            print("🔵 ScreenTimeConsumer: lock released")
        }
    }

    // MARK: - Debug Log

    private func appendDebugLog(_ message: String) {
        let defaults = UserDefaults(suiteName: appGroup)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timeStr = formatter.string(from: Date())
        let line = "[\(timeStr)] \(message)\n"
        var log = defaults?.string(forKey: SharedKeys.debugLog) ?? ""
        log += line
        if log.count > 20_000 {
            let trimmed = String(log.suffix(15_000))
            log = String(trimmed.drop(while: { $0 != "\n" }).dropFirst())
        }
        defaults?.set(log, forKey: SharedKeys.debugLog)
    }
}
