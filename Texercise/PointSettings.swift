import Foundation

struct PointSettings: Codable, Equatable {
    var stepsPerPoint: Int = 100
    var workoutMinutesPerPoint: Int = 1
    var pushupsPerPoint: Int = 1
    var squatsPerPoint: Int = 1
    var situpsPerPoint: Int = 1
    var screenTimeMinutesPerPenalty: Int = 1
    var plankSecondsPerPoint: Int = 6
    var lungeRepsPerPoint: Int = 1

    /// Hard ceiling on tracked screen time per day, in minutes.
    /// 0 = no limit. When set, reaching it locks the selected apps for the
    /// rest of the day regardless of how many points are banked.
    var maxDailyScreenTimeMinutes: Int = 0

    static var `default`: PointSettings {
        PointSettings()
    }

    init() {}

    // MARK: - Codable
    //
    // Hand-written rather than synthesized. The compiler-generated decoder
    // throws when a key is missing from the stored JSON, so adding any new
    // field would make `try? JSONDecoder().decode(...)` fail for every user
    // who already has settings saved — silently resetting all their
    // preferences to defaults on upgrade. decodeIfPresent tolerates absent
    // keys, so old payloads keep working and new fields take their default.

    private enum CodingKeys: String, CodingKey {
        case stepsPerPoint
        case workoutMinutesPerPoint
        case pushupsPerPoint
        case squatsPerPoint
        case situpsPerPoint
        case screenTimeMinutesPerPenalty
        case plankSecondsPerPoint
        case lungeRepsPerPoint
        case maxDailyScreenTimeMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = PointSettings()

        stepsPerPoint = try container.decodeIfPresent(Int.self, forKey: .stepsPerPoint)
            ?? fallback.stepsPerPoint
        workoutMinutesPerPoint = try container.decodeIfPresent(Int.self, forKey: .workoutMinutesPerPoint)
            ?? fallback.workoutMinutesPerPoint
        pushupsPerPoint = try container.decodeIfPresent(Int.self, forKey: .pushupsPerPoint)
            ?? fallback.pushupsPerPoint
        squatsPerPoint = try container.decodeIfPresent(Int.self, forKey: .squatsPerPoint)
            ?? fallback.squatsPerPoint
        situpsPerPoint = try container.decodeIfPresent(Int.self, forKey: .situpsPerPoint)
            ?? fallback.situpsPerPoint
        screenTimeMinutesPerPenalty = try container.decodeIfPresent(Int.self, forKey: .screenTimeMinutesPerPenalty)
            ?? fallback.screenTimeMinutesPerPenalty
        plankSecondsPerPoint = try container.decodeIfPresent(Int.self, forKey: .plankSecondsPerPoint)
            ?? fallback.plankSecondsPerPoint
        lungeRepsPerPoint = try container.decodeIfPresent(Int.self, forKey: .lungeRepsPerPoint)
            ?? fallback.lungeRepsPerPoint
        maxDailyScreenTimeMinutes = try container.decodeIfPresent(Int.self, forKey: .maxDailyScreenTimeMinutes)
            ?? fallback.maxDailyScreenTimeMinutes
    }
}

class PointSettingsStore: ObservableObject {
    @Published var settings: PointSettings {
        didSet {
            saveSettings()
        }
    }

    private let settingsKey = "pointSettings"
    private let appGroup = "group.com.samring.texercise"

    init() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(PointSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = .default
        }
        syncSharedValues()
    }

    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
        syncSharedValues()
    }

    /// Mirrors the values the DeviceActivity extension needs into the App
    /// Group. Called on init and on every change, so the extension never
    /// reads a stale limit even if the app is killed before its next launch.
    private func syncSharedValues() {
        let shared = UserDefaults(suiteName: appGroup)
        shared?.set(max(0, settings.maxDailyScreenTimeMinutes), forKey: SharedKeys.maxDailyScreenTimeMinutes)
        shared?.set(max(1, settings.screenTimeMinutesPerPenalty), forKey: SharedKeys.minutesPerPenalty)
    }
}
