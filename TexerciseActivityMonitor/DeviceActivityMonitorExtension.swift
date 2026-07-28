import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation
import UserNotifications

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    
    private let appGroup = "group.com.samring.texercise"
    private let store = ManagedSettingsStore()
    private let maxTrackedMinutes = 200

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        
        guard event.rawValue.hasPrefix("screenUsage_") else {
            print("⚠️ Ignoring unknown event: \(event.rawValue)")
            return
        }
        
        let now = Date()
        let nowTimestamp = now.timeIntervalSince1970
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: now)
        
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
        let logCap = maxTrackedMinutes * 2
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
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        
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

        // IMPORTANT: Do NOT clear consumedEventNames here.
        // After midnight, startMonitoring will be called on the next app launch,
        // which triggers a re-fire of all previously-fired events with fresh
        // timestamps. ScreenTimeConsumer resets consumedEventNames itself at
        // consume time when it detects a new day (consumedEventNamesDate != today).
        // If we clear it here, the set is empty when the re-fire burst arrives
        // and all re-fired events get counted as new minutes.
        
        let earnedPoints = defaults?.integer(forKey: SharedKeys.earnedPoints) ?? 0
        defaults?.set(earnedPoints, forKey: SharedKeys.netPoints)
        print("🌅 Daily reset — earnedPoints=\(earnedPoints), event log cleared (consumed names preserved until first consume)")
        
        removeBlocking()
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        print("🌙 Monitoring interval ended")
        appendDebugLog("EXT_INTERVAL_END")
        NotificationScheduler.cancelScreenTimeWarning()
        removeBlocking()
    }
    
    // MARK: - Blocking
    
    private func applyBlocking() {
        guard let selection = StoredActivitySelection.load(from: defaults) else {
            print("⚠️ No activity selection found for blocking")
            return
        }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        defaults?.set(true, forKey: SharedKeys.isBlocking)
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
