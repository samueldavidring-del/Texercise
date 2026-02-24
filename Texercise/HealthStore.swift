import Foundation
import HealthKit

final class HealthStore: ObservableObject {
    
    let store = HKHealthStore()
    
    @Published var isAuthorized = false
    @Published var stepsToday = 0
    @Published var distanceTodayMiles: Double = 0.0
    @Published var recentWorkouts: [WorkoutSummary] = []
    @Published var historicalSteps: [Date: Int] = [:]
    
    private let hasRequestedAuthKey = "hasRequestedHealthAuthorization"
    
    var hasRequestedAuthorization: Bool {
        UserDefaults.standard.bool(forKey: hasRequestedAuthKey)
    }
    
    init() {
        DispatchQueue.main.async {
            self.checkAuthorizationStatus()
        }
    }
    
    private func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ Health data not available on this device")
            self.isAuthorized = false
            return
        }
        
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            self.isAuthorized = false
            return
        }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error checking authorization: \(error.localizedDescription)")
                    self.isAuthorized = false
                    return
                }
                print("✅ Health data is accessible - authorized")
                self.isAuthorized = true
                self.loadToday()
                self.loadRecentWorkouts()
                self.loadLast30DaysSteps()
            }
        }
        store.execute(query)
    }
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ Health data not available")
            return
        }
        
        print("🔐 Requesting Health authorization...")
        
        let stepType      = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let distanceType  = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let workoutType   = HKObjectType.workoutType()
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        
        let typesToRead: Set<HKObjectType>  = [stepType, distanceType, workoutType, heartRateType]
        let typesToWrite: Set<HKSampleType> = [workoutType]
        
        store.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                UserDefaults.standard.set(true, forKey: self.hasRequestedAuthKey)
                if let error = error {
                    print("❌ Health authorization error: \(error.localizedDescription)")
                }
                self.checkAuthorizationStatus()
            }
        }
    }
    
    func loadToday() {
        guard isAuthorized else {
            print("⚠️ Cannot load data - not authorized")
            return
        }
        loadStepsToday()
        loadDistanceToday()
    }
    
    private func loadStepsToday() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("❌ Error loading steps: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.stepsToday = 0
                    self.historicalSteps[Calendar.current.startOfDay(for: Date())] = 0
                }
                return
            }
            let steps: Int
            if let quantity = result?.sumQuantity() {
                steps = Int(quantity.doubleValue(for: .count()))
            } else {
                steps = 0
            }
            DispatchQueue.main.async {
                self.stepsToday = steps
                self.historicalSteps[Calendar.current.startOfDay(for: Date())] = steps
                print("📊 Steps today: \(steps)")
            }
        }
        store.execute(query)
    }
    
    private func loadDistanceToday() {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("❌ Error loading distance: \(error.localizedDescription)")
                return
            }
            let meters = result?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
            let miles = meters * 0.000621371
            DispatchQueue.main.async {
                self.distanceTodayMiles = miles
                print("📊 Distance today: \(String(format: "%.2f", miles)) miles")
            }
        }
        store.execute(query)
    }
    
    func loadLast30DaysSteps() {
        guard isAuthorized else { return }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -30, to: endDate) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        var interval = DateComponents()
        interval.day = 1
        let anchorDate = calendar.startOfDay(for: endDate)
        
        let query = HKStatisticsCollectionQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: anchorDate,
            intervalComponents: interval
        )
        
        query.initialResultsHandler = { _, results, error in
            if let error = error {
                print("❌ Error loading historical steps: \(error.localizedDescription)")
                return
            }
            guard let results = results else { return }
            
            var stepsCache: [Date: Int] = [:]
            results.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                let day = calendar.startOfDay(for: stats.startDate)
                let steps: Int
                if let quantity = stats.sumQuantity() {
                    steps = Int(quantity.doubleValue(for: .count()))
                } else {
                    steps = 0
                }
                stepsCache[day] = steps
            }
            
            DispatchQueue.main.async {
                for (date, steps) in stepsCache {
                    self.historicalSteps[date] = steps
                }
                print("✅ Loaded historical steps for \(stepsCache.count) days")
            }
        }
        store.execute(query)
    }
    
    func steps(on date: Date) -> Int {
        let day = Calendar.current.startOfDay(for: date)
        return historicalSteps[day] ?? 0
    }
    
    func fetchHistoricalSteps(for date: Date, completion: @escaping (Int) -> Void) {
        guard isAuthorized else { completion(0); return }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { completion(0); return }
        
        let calendar   = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay   = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate  = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            let steps: Int
            if let quantity = result?.sumQuantity() {
                steps = Int(quantity.doubleValue(for: .count()))
            } else {
                steps = 0
            }
            DispatchQueue.main.async {
                self.historicalSteps[startOfDay] = steps
                completion(steps)
            }
        }
        store.execute(query)
    }
    
    private func fetchHeartRateStats(for workout: HKWorkout, completion: @escaping (Double?, Double?) -> Void) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion(nil, nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: [.discreteAverage, .discreteMax]) { _, result, error in
            if let error = error {
                print("❌ Error fetching heart rate: \(error.localizedDescription)")
                completion(nil, nil)
                return
            }
            let unit = HKUnit(from: "count/min")
            let avg  = result?.averageQuantity()?.doubleValue(for: unit)
            let max  = result?.maximumQuantity()?.doubleValue(for: unit)
            completion(avg, max)
        }
        store.execute(query)
    }
    
    func loadRecentWorkouts() {
        guard isAuthorized else {
            print("⚠️ Cannot load workouts - not authorized")
            return
        }
        
        let workoutType    = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let last30Days     = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        let predicate      = HKQuery.predicateForSamples(withStart: last30Days, end: Date(), options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: 100, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let error = error {
                print("❌ Error loading workouts: \(error.localizedDescription)")
                return
            }
            guard let workouts = samples as? [HKWorkout] else {
                print("⚠️ No workouts found")
                return
            }
            
            let group = DispatchGroup()
            var summaries: [WorkoutSummary] = []
            
            for workout in workouts {
                group.enter()
                self.fetchHeartRateStats(for: workout) { avgHR, maxHR in
                    let summary = WorkoutSummary(workout: workout, averageHeartRate: avgHR, maxHeartRate: maxHR)
                    summaries.append(summary)
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                self.recentWorkouts = summaries.sorted { $0.startDate > $1.startDate }
                print("✅ Loaded \(summaries.count) workouts with stats")
            }
        }
        store.execute(query)
    }
    
    func workouts(on date: Date) -> [WorkoutSummary] {
        let calendar = Calendar.current
        return recentWorkouts.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
    }
    
    func logWorkout(activityType: HKWorkoutActivityType, durationSeconds: Double, distanceMiles: Double?, date: Date) {
        guard isAuthorized else {
            print("⚠️ Cannot log workout - not authorized")
            return
        }
        
        let startDate = date
        let endDate   = date.addingTimeInterval(durationSeconds)
        let builder   = HKWorkoutBuilder(healthStore: store, configuration: HKWorkoutConfiguration(), device: .local())
        
        builder.beginCollection(withStart: startDate) { success, error in
            if let error = error {
                print("❌ Error beginning workout collection: \(error.localizedDescription)")
                return
            }
            
            var samples: [HKSample] = []
            
            if let miles = distanceMiles, miles > 0 {
                let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
                let distanceQuantity = HKQuantity(unit: .mile(), doubleValue: miles)
                let distanceSample = HKQuantitySample(
                    type: distanceType,
                    quantity: distanceQuantity,
                    start: startDate,
                    end: endDate
                )
                samples.append(distanceSample)
            }
            
            builder.add(samples) { success, error in
                if let error = error {
                    print("❌ Error adding samples: \(error.localizedDescription)")
                }
                
                builder.endCollection(withEnd: endDate) { success, error in
                    if let error = error {
                        print("❌ Error ending workout collection: \(error.localizedDescription)")
                        return
                    }
                    
                    builder.finishWorkout { workout, error in
                        if let error = error {
                            print("❌ Error finishing workout: \(error.localizedDescription)")
                            return
                        }
                        if workout != nil {
                            print("✅ Workout saved successfully")
                            DispatchQueue.main.async {
                                self.loadRecentWorkouts()
                            }
                        }
                    }
                }
            }
        }
    }
    
    func deleteWorkout(_ workout: WorkoutSummary) {
        guard isAuthorized else {
            print("⚠️ Cannot delete workout - not authorized")
            return
        }
        
        let predicate = HKQuery.predicateForObject(with: workout.id)
        let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
            if let error = error {
                print("❌ Error finding workout to delete: \(error.localizedDescription)")
                return
            }
            guard let workoutToDelete = samples?.first else {
                print("⚠️ Workout not found")
                return
            }
            self.store.delete(workoutToDelete) { success, error in
                if let error = error {
                    print("❌ Error deleting workout: \(error.localizedDescription)")
                    return
                }
                if success {
                    print("✅ Workout deleted successfully")
                    DispatchQueue.main.async { self.loadRecentWorkouts() }
                }
            }
        }
        store.execute(query)
    }
    
    private func activityName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running:                     return "Running"
        case .walking:                     return "Walking"
        case .cycling:                     return "Cycling"
        case .swimming:                    return "Swimming"
        case .hiking:                      return "Hiking"
        case .yoga:                        return "Yoga"
        case .functionalStrengthTraining:  return "Strength Training"
        case .traditionalStrengthTraining: return "Weight Lifting"
        case .elliptical:                  return "Elliptical"
        case .rowing:                      return "Rowing"
        default:                           return "Workout"
        }
    }
}
