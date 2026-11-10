import SwiftUI

/// Drop-in Settings section for the hard daily screen time ceiling.
///
/// Used inside the Form in PointSettingsView:
///
///     MaxDailyLimitSection(settings: $pointSettings.settings)
///
/// Changing the value writes straight through to the App Group via
/// PointSettingsStore.saveSettings(), but the registered DeviceActivity
/// threshold events only change on the next call to ensureMonitoring or
/// forceRestartMonitoring.
struct MaxDailyLimitSection: View {

    @Binding var settings: PointSettings

    private let options: [Int] = [0, 30, 60, 90, 120, 150, 180, 240, 300, 360, 480]

    var body: some View {
        Section {
            Picker("Max daily screen time", selection: $settings.maxDailyScreenTimeMinutes) {
                ForEach(options, id: \.self) { minutes in
                    Text(Self.label(for: minutes)).tag(minutes)
                }
            }
        } header: {
            Text("Daily Limit")
        } footer: {
            if settings.maxDailyScreenTimeMinutes > 0 {
                Text("Once you reach \(Self.label(for: settings.maxDailyScreenTimeMinutes)) of tracked screen time, your selected apps lock until midnight — even if you still have points left.")
            } else {
                Text("No hard limit. Apps only lock when you run out of points.")
            }
        }
    }

    static func label(for minutes: Int) -> String {
        guard minutes > 0 else { return "No limit" }
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 {
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
        return "\(hours) hr \(remainder) min"
    }
}
