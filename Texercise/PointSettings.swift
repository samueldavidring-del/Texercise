import Foundation

struct PointSettings: Codable, Equatable {
    var stepsPerPoint: Int = 100
    var workoutMinutesPerPoint: Int = 1
    var repsPerPoint: Int = 10  // Default for pushups, squats, sit-ups
    var screenTimeMinutesPerPenalty: Int = 15
    var plankSecondsPerPoint: Int = 6
    var lungeRepsPerPoint: Int = 10
    
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
