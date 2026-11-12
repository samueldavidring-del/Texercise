import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation
import UserNotifications

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let appGroup = "group.com.samring.texercise"
    private let store = ManagedSettingsStore()

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    /// How many log entries to retain. Scales with the configured limit so a
    /// long day is never truncated, with a floor for the no-limit case.
    private var eventLogCap: Int {
        let limit = HardBlock.limit(in: defaults)
        let tracked = limit > 0 ? limit : ScreenTimeMonitorConstants.defaultTrackedMinutes
        return max(400, tracked * 2)
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        // The hard daily limit is handled first and independently of the
        // counting path. It only has to fire once to be correct, so it is not
        // affected by the re-fire bursts that complicate screenUsage_ events.
        if event.rawValue == SharedEventNames.dailyLimitReached {
            handleDailyLimitReached()
            return
        }

        guard event.rawValue.hasPrefix(SharedEventNames.screenUsagePrefix) else {
            print("⚠️ Ignoring unknown event: \(event.rawValue)")
            return
        }

        let now = Date()
        let nowTimestamp = now.timeIntervalSince1970
        let todayString = SharedDate.todayString(now)

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now).timeIntervalSince1970

        var eventLog = (defaults?.array(forKey: SharedKeys.screenTimeEventLog) as? [String]) ?? []
        eventLog = eventLog.filter { entry in
            guard let tsStr = entry.split(separator: "|").last,
                  let ts = Double(tsStr) else { return false }
            return ts >= startOfToday
        }
        let countBeforeAppend = eventLog.count
        let logEntry = "\(event.rawValue)|\(Int(nowTimestamp))"
        eventLog.append(logEntry)
        let logCap = eventLogCap
        if eventLog.count > logCap {
            eventLog = Array(eventLog.suffix(logCap))
        }
        defaults?.set(eventLog, forKey: SharedKeys.screenTimeEventLog)

        appendDebugLog("EXT_EVENT event=\(event.rawValue) logBefore=\(countBeforeAppend) logAfter=\(eventLog.count) ts=\(Int(nowTimestamp))")

        print("⚡️ eventDidReachThreshold — event=\(event.rawValue) | log count before: \(countBeforeAppend)")
        print("📱 Event logged at \(Int(nowTimestamp)) — \(eventLog.count) entries today total")

        let currentPoints = defaults?.integer(forKey: SharedKeys.netPoints) ?? 0
        let newPoints = currentPoints - 1
        defaults?.set(newPoints, forKey: SharedKeys.netPoints)
        defaults?.set(now, forKey: SharedKeys.lastUpdated)

        let eventsDate = defaults?.string(forKey: SharedKeys.screenTimeEventsTodayDate) ?? ""
        let existingEventCount = eventsDate == todayString
            ? (defaults?.integer(forKey: SharedKeys.screenTimeEventsTodayCount) ?? 0)
            : 0
        let totalEventsToday = existingEventCount + 1
        defaults?.set(totalEventsToday, forKey: SharedKeys.screenTimeEventsTodayCount)
        defaults?.set(todayString, forKey: SharedKeys.screenTimeEventsTodayDate)

        print("📱 Points: \(currentPoints) → \(newPoints) | Events today: \(totalEventsToday)")

        // If today's ceiling has already been reached, the shield stays on
        // regardless of the points arithmetic. Re-assert it in case anything
        // in the main app lifted it, and skip the warning logic entirely —
        // there is nothing the user can do to earn their way out today.
        if HardBlock.isActive(in: defaults) {
            print("⛔️ Daily limit already reached — keeping apps locked")
            NotificationScheduler.cancelScreenTimeWarning()
            applyBlocking()
            return
        }

        if newPoints <= 0 {
            print("🔴 Points at or below 0 — blocking")
            NotificationScheduler.cancelScreenTimeWarning()
            let wasBlocking = defaults?.bool(forKey: SharedKeys.isBlocking) ?? false
            applyBlocking()
            if !wasBlocking {
                logBlockingEvent()
                print("📋 Blocking transition logged (was unblocked → now blocked)")
            } else {
                print("📋 Already blocked — skipping duplicate blocking event log")
            }
        } else {
            let earnedPoints = defaults?.integer(forKey: SharedKeys.earnedPoints) ?? 0
            let accuratePoints = earnedPoints > 0 ? earnedPoints - totalEventsToday : newPoints
            let previousAccuratePoints = accuratePoints + 1
            if accuratePoints <= 5 && accuratePoints > 0 && previousAccuratePoints > 5 {
                print("⏳ Crossed into warning zone — \(accuratePoints) pts remaining")
                NotificationScheduler.scheduleScreenTimeWarning(minutesLeft: accuratePoints)
            }
        }
    }

    // MARK: - Daily Limit

    private func handleDailyLimitReached() {
        let limit = HardBlock.limit(in: defaults)

        // Fires once per interval, but guard anyway — startMonitoring resets
        // cumulative counters, so this event can re-fire like any other.
        if HardBlock.isActive(in: defaults) {
            print("⛔️ Daily limit event re-fired — already locked out today")
            appendDebugLog("EXT_DAILY_LIMIT re-fire ignored limit=\(limit)min")
            applyBlocking()
            return
        }

        print("⛔️ Daily screen time limit reached (\(limit) min) — locking until tomorrow")
        appendDebugLog("EXT_DAILY_LIMIT reached limit=\(limit)min — hard lockout applied")

        HardBlock.activate(in: defaults)
        NotificationScheduler.cancelScreenTimeWarning()

        let wasBlocking = defaults?.bool(forKey: SharedKeys.isBlocking) ?? false
        applyBlocking()
        if !wasBlocking {
            logBlockingEvent()
        }

        sendDailyLimitNotification(limit: limit)
    }

    private func sendDailyLimitNotification(limit: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Daily limit reached"
        content.body = limit > 0
            ? "You've used your \(limit) minute daily screen time limit. Your apps are locked until tomorrow."
            : "You've reached your daily screen time limit. Your apps are locked until tomorrow."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "dailyLimitReached",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("⚠️ Failed to post daily limit notification: \(error)")
            }
        }
    }

    // MARK: - Interval Lifecycle

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        let todayString = SharedDate.todayString()

        let lastResetDate = defaults?.string(forKey: SharedKeys.lastIntervalStartDate) ?? ""
        guard lastResetDate != todayString else {
            print("🌅 intervalDidStart fired but already reset today — skipping")
            appendDebugLog("EXT_INTERVAL_START skipped — already reset today")
            return
        }

        print("🌅 New day interval started — resetting daily counters")
        appendDebugLog("EXT_INTERVAL_START new day reset")
        NotificationScheduler.cancelScreenTimeWarning()

        defaults?.set(todayString, forKey: SharedKeys.lastIntervalStartDate)
        defaults?.set(0, forKey: SharedKeys.screenTimeEventsTodayCount)
        defaults?.set("", forKey: SharedKeys.screenTimeEventsTodayDate)
        defaults?.set([String](), forKey: SharedKeys.screenTimeEventLog)

        // Release yesterday's daily-limit lockout. This is guarded by the date
        // check above, so a mid-day startMonitoring cannot reach it — but the
        // lockout is also date-stamped, so even if it did the stamp would
        // still read as today and HardBlock.isActive would stay true.
        HardBlock.clear(in: defaults)

        // IMPORTANT: Do NOT clear consumedEventNames here.
        // After midnight, startMonitoring will be called on the next app launch,
        // which triggers a re-fire of all previously-fired events with fresh
        // timestamps. ScreenTimeConsumer resets consumedEventNames itself at
        // consume time when it detects a new day (consumedEventNamesDate != today).
        // If we clear it here, the set is empty when the re-fire burst arrives
        // and all re-fired events get counted as new minutes.

        let earnedPoints = defaults?.integer(forKey: SharedKeys.earnedPoints) ?? 0
        defaults?.set(earnedPoints, forKey: SharedKeys.netPoints)
        print("🌅 Daily reset — earnedPoints=\(earnedPoints), event log cleared, daily limit lockout released")

        removeBlocking()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        print("🌙 Monitoring interval ended")
        appendDebugLog("EXT_INTERVAL_END")
        NotificationScheduler.cancelScreenTimeWarning()
        HardBlock.clear(in: defaults)
        removeBlocking()
    }

    // MARK: - Blocking

    private func applyBlocking() {
        guard let selection = StoredActivitySelection.load(from: defaults) else {
            print("⚠️ No activity selection found for blocking")
            appendDebugLog("EXT_BLOCK FAILED — no stored activity selection in App Group")
            return
        }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        let wasBlocking = defaults?.bool(forKey: SharedKeys.isBlocking) ?? false
        defaults?.set(true, forKey: SharedKeys.isBlocking)
        if !wasBlocking {
            let points = defaults?.integer(forKey: SharedKeys.netPoints) ?? 0
            appendDebugLog("EXT_BLOCK applied apps=\(selection.applicationTokens.count) cats=\(selection.categoryTokens.count) points=\(points)")
        }
        print("🔒 Apps blocked by extension")
    }

    private func logBlockingEvent() {
        var timestamps = (defaults?.array(forKey: SharedKeys.blockingEvents) as? [Double]) ?? []
        timestamps.append(Date().timeIntervalSince1970)
        let cutoff = Date().addingTimeInterval(-31 * 24 * 60 * 60).timeIntervalSince1970
        timestamps = timestamps.filter { $0 >= cutoff }
        defaults?.set(timestamps, forKey: SharedKeys.blockingEvents)
        print("📋 Blocking event logged — total events: \(timestamps.count)")
    }

    private func removeBlocking() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        defaults?.set(false, forKey: SharedKeys.isBlocking)
        print("🔓 Apps unblocked by extension")
    }

    // MARK: - Persistent Debug Log

    private func appendDebugLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
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

/// Constants the extension needs that would otherwise live on ScreenTimeMonitor,
/// which is main-app only. Keep the default in sync with
/// `ScreenTimeMonitor.defaultTrackedMinutes`.
enum ScreenTimeMonitorConstants {
    static let defaultTrackedMinutes = 480
}
