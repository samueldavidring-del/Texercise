import Foundation
import FamilyControls
import ManagedSettings

final class ScreenTimeCategoryStore: ObservableObject {

    static let shared = ScreenTimeCategoryStore()

    @Published var activitySelection: FamilyActivitySelection {
        didSet {
            guard activitySelection != oldValue else { return }
            save()
            // Selection changed — force full restart so new apps are tracked
            forceRestartMonitoring()
        }
    }

    @Published var isTrackingEnabled: Bool {
        didSet {
            guard isTrackingEnabled != oldValue else { return }
            UserDefaults.standard.set(isTrackingEnabled, forKey: Keys.trackingEnabled)
            if isTrackingEnabled {
                forceRestartMonitoring()
            } else {
                ScreenTimeMonitor.shared.stopMonitoring()
            }
        }
    }

    private enum Keys {
        static let activitySelection     = "screenTimeActivitySelection"
        static let trackingEnabled       = "screenTimeTrackingEnabled"
        static let hasSetTrackingDefault = "hasSetTrackingDefault"
    }

    private init() {
        let hasSetDefault = UserDefaults.standard.bool(forKey: Keys.hasSetTrackingDefault)
        if hasSetDefault {
            self.isTrackingEnabled = UserDefaults.standard.bool(forKey: Keys.trackingEnabled)
        } else {
            self.isTrackingEnabled = true
            UserDefaults.standard.set(true, forKey: Keys.trackingEnabled)
            UserDefaults.standard.set(true, forKey: Keys.hasSetTrackingDefault)
        }

        if let data = UserDefaults.standard.data(forKey: Keys.activitySelection),
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            self.activitySelection = decoded
        } else {
            self.activitySelection = FamilyActivitySelection()
        }

        // On launch: only starts monitoring if not already started today with
        // this selection. Skipping prevents the re-fire burst that resets
        // DeviceActivity's cumulative threshold counters.
        if isTrackingEnabled && hasSelection {
            ensureMonitoring()
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(activitySelection) {
            UserDefaults.standard.set(encoded, forKey: Keys.activitySelection)
        }
    }

    private func ensureMonitoring() {
        guard isTrackingEnabled && hasSelection else { return }
        ScreenTimeMonitor.shared.ensureMonitoring(
            selection: activitySelection,
            minutesPerPenalty: loadMinutesPerPenalty()
        )
    }

    private func forceRestartMonitoring() {
        guard isTrackingEnabled && hasSelection else { return }
        ScreenTimeMonitor.shared.forceRestartMonitoring(
            selection: activitySelection,
            minutesPerPenalty: loadMinutesPerPenalty()
        )
    }

    func startMonitoringIfNeeded() {
        guard isTrackingEnabled && hasSelection else { return }
        ScreenTimeMonitor.shared.ensureMonitoring(
            selection: activitySelection,
            minutesPerPenalty: loadMinutesPerPenalty()
        )
    }

    private func loadMinutesPerPenalty() -> Int {
        guard let data = UserDefaults.standard.data(forKey: "pointSettings"),
              let settings = try? JSONDecoder().decode(PointSettings.self, from: data) else {
            return 1
        }
        return max(1, settings.screenTimeMinutesPerPenalty)
    }

    var hasSelection: Bool {
        !activitySelection.applications.isEmpty || !activitySelection.categories.isEmpty
    }

    var selectionSummary: String {
        let appCount = activitySelection.applications.count
        let catCount = activitySelection.categories.count
        if appCount == 0 && catCount == 0 { return "Nothing selected" }
        var parts: [String] = []
        if appCount > 0 { parts.append("\(appCount) app\(appCount == 1 ? "" : "s")") }
        if catCount > 0 { parts.append("\(catCount) categor\(catCount == 1 ? "y" : "ies")") }
        return parts.joined(separator: ", ")
    }
}
