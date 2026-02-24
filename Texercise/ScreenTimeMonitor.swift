import Foundation
import DeviceActivity
import FamilyControls

final class ScreenTimeMonitor {

    static let shared = ScreenTimeMonitor()

    private let center = DeviceActivityCenter()

    private let schedule = DeviceActivitySchedule(
        intervalStart: DateComponents(hour: 0, minute: 0),
        intervalEnd: DateComponents(hour: 23, minute: 59),
        repeats: true
    )

    private init() {}

    // MARK: Start Monitoring

    func startMonitoring(selection: FamilyActivitySelection) {
        do {
            try center.startMonitoring(
                .daily,
                during: schedule,
                events: [
                    .usage: DeviceActivityEvent(
                        applications: selection.applicationTokens,
                        categories: selection.categoryTokens,
                        threshold: DateComponents(minute: 1)
                    )
                ]
            )
            print("✅ DeviceActivity monitoring started")
        } catch {
            print("❌ Failed to start monitoring:", error)
        }
    }
}

// MARK: - Names

extension DeviceActivityName {
    static let daily = Self("daily")
}

extension DeviceActivityEvent.Name {
    static let usage = Self("usage")
}

