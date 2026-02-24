import Foundation
import AuthenticationServices
import HealthKit

class StravaAPI: ObservableObject {
    
    // Strava API credentials
    private let clientID = "194178"
    private let clientSecret = "a15b9672a768349e2aac5b1bd8d7b900c9f40b21"
    
    @Published var isAuthenticated = false
    @Published var athleteName: String = ""
    
    private var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "strava_access_token") }
        set { UserDefaults.standard.set(newValue, forKey: "strava_access_token") }
    }
    
    private var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "strava_refresh_token") }
        set { UserDefaults.standard.set(newValue, forKey: "strava_refresh_token") }
    }
    
    init() {
        checkAuthentication()
    }
    
    // MARK: - Authentication
    
    func checkAuthentication() {
        isAuthenticated = accessToken != nil
    }
    
    func getManualAuthorizationURL() -> URL? {
        var components = URLComponents(string: "https://www.strava.com/oauth/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: "http://localhost"),
            URLQueryItem(name: "scope", value: "activity:read_all"),
            URLQueryItem(name: "approval_prompt", value: "force")
        ]
        
        return components?.url
    }
    
    func handleAuthCallback(code: String) async throws {
        let url = URL(string: "https://www.strava.com/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code"
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📝 Strava response: \(jsonString)")
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let token = json["access_token"] as? String,
               let refresh = json["refresh_token"] as? String {
                
                await MainActor.run {
                    self.accessToken = token
                    self.refreshToken = refresh
                    self.isAuthenticated = true
                }
                
                print("✅ Strava authenticated successfully")
                await fetchAthleteInfo()
            } else if let error = json["message"] as? String {
                print("❌ Strava error: \(error)")
                throw NSError(domain: "Strava", code: 0, userInfo: [NSLocalizedDescriptionKey: error])
            }
        }
    }
    
    func disconnect() {
        accessToken = nil
        refreshToken = nil
        isAuthenticated = false
        athleteName = ""
    }
    
    // MARK: - Fetch Athlete Info
    
    private func fetchAthleteInfo() async {
        guard let token = accessToken else { return }
        
        let url = URL(string: "https://www.strava.com/api/v3/athlete")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let firstname = json["firstname"] as? String,
               let lastname = json["lastname"] as? String {
                
                await MainActor.run {
                    self.athleteName = "\(firstname) \(lastname)"
                }
            }
        } catch {
            print("❌ Failed to fetch athlete info: \(error)")
        }
    }
    
    // MARK: - Fetch Activities
    
    func fetchActivities(before: Date? = nil, after: Date? = nil) async -> [StravaActivity] {
        guard let token = accessToken else {
            print("❌ No access token available")
            return []
        }
        
        var components = URLComponents(string: "https://www.strava.com/api/v3/athlete/activities")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "per_page", value: "100")
        ]
        
        if let after = after {
            queryItems.append(URLQueryItem(name: "after", value: "\(Int(after.timeIntervalSince1970))"))
        }
        
        if let before = before {
            queryItems.append(URLQueryItem(name: "before", value: "\(Int(before.timeIntervalSince1970))"))
        }
        
        components.queryItems = queryItems
        
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let activities = try decoder.decode([StravaActivity].self, from: data)
            
            print("✅ Fetched \(activities.count) Strava activities")
            return activities
        } catch {
            print("❌ Failed to fetch Strava activities: \(error)")
            return []
        }
    }
    
    // MARK: - Import to HealthKit
    
    func importActivitiesToHealthKit(_ activities: [StravaActivity]) async throws -> Int {
        let healthStore = HKHealthStore()
        
        print("🔐 Requesting HealthKit authorization...")
        
        // Request write permission for workouts AND distance
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        
        // Use continuation to properly wait for authorization
        let authorized = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            healthStore.requestAuthorization(toShare: typesToShare, read: []) { success, error in
                print("📋 Authorization result: success=\(success), error=\(String(describing: error))")
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
        
        guard authorized else {
            print("❌ HealthKit authorization denied")
            throw NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Authorization denied"])
        }
        
        print("✅ HealthKit authorization granted")
        
        // Check for existing workouts to avoid duplicates
        print("🔍 Checking for existing Strava workouts...")
        let existingWorkouts = try await fetchExistingStravaWorkouts(healthStore: healthStore)
        let existingStravaIDs = Set(existingWorkouts.compactMap { workout -> String? in
            guard let metadata = workout.metadata,
                  let externalUUID = metadata[HKMetadataKeyExternalUUID] as? String,
                  externalUUID.hasPrefix("strava-") else {
                return nil
            }
            return externalUUID
        })
        
        print("📦 Found \(existingStravaIDs.count) existing Strava workouts in HealthKit")
        
        var importedCount = 0
        var skippedCount = 0
        
        for activity in activities {
            let workoutUUID = "strava-\(activity.id)"
            
            // Skip if already exists
            if existingStravaIDs.contains(workoutUUID) {
                print("⏭️  Skipping \(activity.name) - already exists")
                skippedCount += 1
                continue
            }
            
            print("📝 Processing: \(activity.name)")
            print("   - Type: \(activity.type)")
            print("   - Start: \(activity.startDate)")
            print("   - Duration: \(activity.duration) seconds")
            print("   - Distance: \(activity.distance) meters")
            
            do {
                // Create workout using the simple initializer
                let workout = HKWorkout(
                    activityType: activity.healthKitActivityType,
                    start: activity.startDate,
                    end: activity.endDate,
                    duration: activity.duration,
                    totalEnergyBurned: nil,
                    totalDistance: activity.distance > 0 ? HKQuantity(unit: .meter(), doubleValue: activity.distance) : nil,
                    metadata: [HKMetadataKeyExternalUUID: workoutUUID]
                )
                
                // Save to HealthKit
                try await healthStore.save(workout)
                
                importedCount += 1
                print("✅ Saved: \(activity.name)")
                
            } catch {
                print("❌ Failed to import \(activity.name): \(error)")
                print("   Error details: \(error.localizedDescription)")
            }
        }
        
        print("✅ Successfully imported \(importedCount) of \(activities.count) workouts to HealthKit")
        if skippedCount > 0 {
            print("⏭️  Skipped \(skippedCount) duplicate workouts")
        }
        return importedCount
    }
    
    // MARK: - Check for Existing Workouts
    
    private func fetchExistingStravaWorkouts(healthStore: HKHealthStore) async throws -> [HKWorkout] {
        return try await withCheckedThrowingContinuation { continuation in
            let workoutType = HKObjectType.workoutType()
            
            // Query for workouts in the last year with Strava metadata
            let startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date())
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
            
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let workouts = (samples as? [HKWorkout]) ?? []
                    continuation.resume(returning: workouts)
                }
            }
            
            healthStore.execute(query)
        }
    }
}

// MARK: - Models

struct StravaActivity: Codable, Identifiable {
    let id: Int
    let name: String
    let type: String
    let startDate: Date
    let distance: Double
    let movingTime: Int
    let elapsedTime: Int
    let totalElevationGain: Double?
    let averageSpeed: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case startDate = "start_date"
        case distance
        case movingTime = "moving_time"
        case elapsedTime = "elapsed_time"
        case totalElevationGain = "total_elevation_gain"
        case averageSpeed = "average_speed"
    }
    
    var durationMinutes: Int {
        movingTime / 60
    }
    
    var distanceMiles: Double {
        distance * 0.000621371
    }
    
    var duration: TimeInterval {
        TimeInterval(movingTime)
    }
    
    var endDate: Date {
        startDate.addingTimeInterval(duration)
    }
    
    var healthKitActivityType: HKWorkoutActivityType {
        switch type.lowercased() {
        case "run":
            return .running
        case "ride", "virtualride", "ebikeride":
            return .cycling
        case "swim":
            return .swimming
        case "walk":
            return .walking
        case "hike":
            return .hiking
        case "alpineski", "backcountryski", "nordicski":
            return .crossCountrySkiing
        case "workout", "weighttraining":
            return .traditionalStrengthTraining
        case "yoga":
            return .yoga
        default:
            return .other
        }
    }
}
