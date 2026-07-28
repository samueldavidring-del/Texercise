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
    
    static var `default`: PointSettings {
        PointSettings()
    }
}

class PointSettingsStore: ObservableObject {
    @Published var settings: PointSettings {
        didSet {
            saveSettings()
        }
    }
    
    private let settingsKey = "pointSettings"
    
    init() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(PointSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = .default
        }
    }
    
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }
}
