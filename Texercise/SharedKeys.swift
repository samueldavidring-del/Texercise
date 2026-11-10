import Foundation
import ManagedSettings
import FamilyControls
import DeviceActivity

enum SharedKeys {
    static let netPoints = "sharedNetPoints"
    static let earnedPoints = "sharedEarnedPoints"
    static let lastUpdated = "sharedLastUpdated"
    static let isBlocking = "sharedIsBlocking"
    static let activitySelection = "sharedActivitySelection"
    static let minutesPerPenalty = "sharedMinutesPerPenalty"

    // MARK: - Screen Time Event Log
    // Extension appends "eventName|timestamp" for every threshold fired.
    // Main app compares log count against Core Data total to find the delta.
    static let screenTimeEventLog = "sharedScreenTimeEventLog"     // [String]

    // MARK: - Max Daily Screen Time Limit
    /// Hard ceiling in minutes. 0 = no limit.
    static let maxDailyScreenTimeMinutes = "sharedMaxDailyScreenTimeMinutes"
    /// Set true once the ceiling is hit. Date-stamped so it self-expires.
    static let isHardBlocked = "sharedIsHardBlocked"
    static let hardBlockDate = "sharedHardBlockDate"

    // MARK: - Legacy keys (no longer written, kept so old data isn't orphaned)
    static let lastConsumedTimestamp    = "sharedLastConsumedTimestamp"
    static let lastConsumedDate         = "sharedLastConsumedDate"
    static let highWaterMark            = "sharedHighWaterMark"
    static let highWaterMarkDate        = "sharedHighWaterMarkDate"
    static let minuteWatermark          = "sharedMinuteWatermark"
    static let minuteWatermarkDate      = "sharedMinuteWatermarkDate"
    static let consumedEventNames       = "sharedConsumedEventNames"
    static let consumedEventNamesDate   = "sharedConsumedEventNamesDate"
    static let pendingScreenTimeMinutes = "sharedPendingScreenTimeMinutes"
    static let pendingScreenTimeDate    = "sharedPendingScreenTimeDate"

    // MARK: - Blocking
    static let blockingEvents = "sharedBlockingEvents"

    // MARK: - Daily counters (extension)
    static let screenTimeEventsTodayCount = "sharedScreenTimeEventsTodayCount"
    static let screenTimeEventsTodayDate  = "sharedScreenTimeEventsTodayDate"
    static let lastIntervalStartDate      = "lastIntervalStartDate"

    // MARK: - Debug log
    static let debugLog = "sharedDebugLog"
}

/// Event names shared between the main app (which registers them) and the
/// monitor extension (which receives them). Defined once so the two processes
/// can never drift apart on a string literal.
enum SharedEventNames {
    static let screenUsagePrefix = "screenUsage_"
    static let dailyLimitReached = "dailyLimitReached"
}

/// Single source of truth for the "yyyy-MM-dd" day key used across processes.
///
/// Pinned to en_US_POSIX and the Gregorian calendar: a device set to a
/// non-Gregorian calendar would otherwise produce a different string in the
/// app than in the extension, and every day comparison would silently fail.
enum SharedDate {
    static func todayString(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

/// The hard daily-limit lockout, readable and writable from every target.
///
/// Deliberately date-stamped rather than reset on a lifecycle callback:
/// `intervalDidStart` fires on *every* `startMonitoring` call, not only at
/// midnight, so anything cleared there can be wiped mid-day. Comparing a
/// stored date against today is immune to that.
enum HardBlock {

    /// True only if the lockout was set today.
    static func isActive(in defaults: UserDefaults?) -> Bool {
        guard let defaults else { return false }
        guard defaults.bool(forKey: SharedKeys.isHardBlocked) else { return false }
        return defaults.string(forKey: SharedKeys.hardBlockDate) == SharedDate.todayString()
    }

    static func activate(in defaults: UserDefaults?) {
        defaults?.set(true, forKey: SharedKeys.isHardBlocked)
        defaults?.set(SharedDate.todayString(), forKey: SharedKeys.hardBlockDate)
    }

    static func clear(in defaults: UserDefaults?) {
        defaults?.set(false, forKey: SharedKeys.isHardBlocked)
        defaults?.set("", forKey: SharedKeys.hardBlockDate)
    }

    /// Clears a lockout left over from a previous day. Safe to call often.
    /// Returns true if something was actually cleared.
    @discardableResult
    static func clearIfStale(in defaults: UserDefaults?) -> Bool {
        guard let defaults else { return false }
        guard defaults.bool(forKey: SharedKeys.isHardBlocked) else { return false }
        guard defaults.string(forKey: SharedKeys.hardBlockDate) != SharedDate.todayString() else {
            return false
        }
        clear(in: defaults)
        return true
    }

    /// The configured ceiling in minutes. 0 means no limit.
    static func limit(in defaults: UserDefaults?) -> Int {
        max(0, defaults?.integer(forKey: SharedKeys.maxDailyScreenTimeMinutes) ?? 0)
    }
}

extension DeviceActivityName {
    static let daily = Self("daily")
}

struct StoredActivitySelection {
    static func save(_ selection: FamilyActivitySelection, to defaults: UserDefaults?) {
        if let data = try? JSONEncoder().encode(selection) {
            defaults?.set(data, forKey: SharedKeys.activitySelection)
        }
    }
    static func load(from defaults: UserDefaults?) -> FamilyActivitySelection? {
        guard let data = defaults?.data(forKey: SharedKeys.activitySelection) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }
}
