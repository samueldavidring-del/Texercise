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
