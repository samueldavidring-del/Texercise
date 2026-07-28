import Foundation
import HealthKit

final class HealthStore: ObservableObject {
    
    let store = HKHealthStore()
    
    @Published var isAuthorized = false
    @Published var stepsToday = 0
    @Published var distanceTodayMiles: Double = 0.0
    @Published var recentWorkouts: [WorkoutSummary] = []
    @Published var allWorkouts: [WorkoutSummary] = []
    @Published var historicalSteps: [Date: Int] = [:]
    @Published var totalWorkoutsCount: Int = 0
    
    private let hasRequestedAuthKey = "hasRequestedHealthAuthorization"
    private var stepObserverQuery: HKObserverQuery?
    
    var hasRequestedAuthorization: Bool {
        UserDefaults.standard.bool(forKey: hasRequestedAuthKey)
    }
    
    init() {
        DispatchQueue.main.async {
            self.checkAuthorizationStatus()
        }
    }
    
    // MARK: - Authorization
    // Runs a today query to check access. Proceeds regardless of whether data
    // exists — an empty result (0 steps at 5 AM) is not an access denial.
    // Only a genuine authorization error stops loading.

    private func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ Health data not available on this device")
            isAuthorized = false
            return
        }
        
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            isAuthorized = false
            return
        }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        // Use a wide predicate (start of day to now) but treat ANY result —
        // including nil sumQuantity with no error — as authorized.
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: [])
        
        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, _, error in
            DispatchQueue.main.async {
                // Only block on a real authorization error, not "no data" errors.
                // HealthKit returns specific error codes for auth failures.
                if let error = error as? HKError, error.code == .errorAuthorizationDenied {
                    print("❌ HealthKit authorization denied: \(error.localizedDescription)")
                    self.isAuthorized = false
                    return
                }
                // Any other result (including "no data available") means we have access
                print("✅ Health data is accessible - authorized")
                self.isAuthorized = true
                self.loadToday()
                self.loadRecentWorkouts()
                self.loadAllWorkouts()
                self.loadSteps(days: 90)
                self.startStepObserver()
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
    
    // MARK: - Load Today

    func loadToday() {
        guard isAuthorized else { return }
        loadStepsToday()
        loadDistanceToday()
    }
    
    private func loadStepsToday() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("❌ Error loading steps today: \(error.localizedDescription)")
                return
            }
            let steps = Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            DispatchQueue.main.async {
                self.stepsToday = steps
                self.historicalSteps[calendar.startOfDay(for: now)] = steps
                print("📊 Steps today: \(steps)")
            }
        }
        store.execute(query)
    }
    
    // MARK: - Step Observer
    
    private func startStepObserver() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        if let existing = stepObserverQuery {
            store.stop(existing)
        }
        
        let observer = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in
            if let error = error {
                print("❌ Step observer error: \(error.localizedDescription)")
                completionHandler()
                return
            }
            print("🔄 Step observer fired — refreshing steps")
            self?.loadStepsToday()
            self?.loadSteps(days: 90)
            completionHandler()
        }
        
        stepObserverQuery = observer
        store.execute(observer)
        
        store.enableBackgroundDelivery(for: stepType, frequency: .immediate) { success, error in
            if success {
                print("✅ Step background delivery enabled")
            } else if let error = error {
                print("⚠️ Step background delivery failed: \(error.localizedDescription)")
            }
        }
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
            let miles = (result?.sumQuantity()?.doubleValue(for: .meter()) ?? 0) * 0.000621371
            DispatchQueue.main.async {
                self.distanceTodayMiles = miles
                print("📊 Distance today: \(String(format: "%.2f", miles)) miles")
            }
        }
        store.execute(query)
    }
    
    // MARK: - Historical Steps

    func loadSteps(days: Int) {
        guard isAuthorized else { return }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let endDate = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: todayStart) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        var interval = DateComponents()
        interval.day = 1

        var anchorComponents = DateComponents()
        anchorComponents.hour = 0
        anchorComponents.minute = 0
        anchorComponents.second = 0
        let anchorDate = calendar.date(from: anchorComponents) ?? startDate

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
            guard let results = results else {
                print("❌ Historical steps results were nil")
                return
            }

            var stepsCache: [Date: Int] = [:]
            var cursor = startDate
            while cursor < endDate {
                stepsCache[calendar.startOfDay(for: cursor)] = 0
                cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86400)
            }

            var nonZeroDays = 0
            results.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                let day = calendar.startOfDay(for: stats.startDate)
                let steps = Int(stats.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                stepsCache[day] = steps
                if steps > 0 { nonZeroDays += 1 }
            }

            print("✅ Loaded historical steps for \(stepsCache.count) days (\(days)d range) — \(nonZeroDays) days with steps")

            DispatchQueue.main.async {
                var merged = self.historicalSteps
                for (date, steps) in stepsCache {
                    merged[date] = steps
                }
                self.historicalSteps = merged
            }
        }
        store.execute(query)
    }
    
    func loadLast30DaysSteps() {
        loadSteps(days: 90)
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
            let steps = Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            DispatchQueue.main.async {
                self.historicalSteps[startOfDay] = steps
                completion(steps)
            }
        }
        store.execute(query)
    }
    
    // MARK: - Heart Rate
    
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
    
    // MARK: - Workouts
    // Limited to 500 to prevent freeze on large workout histories
    
    func loadAllWorkouts() {
        guard isAuthorized else { return }
        
        let workoutType    = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: workoutType,
            predicate: nil,
            limit: 500,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            if let error = error {
                print("❌ Error loading all workouts: \(error.localizedDescription)")
                return
            }
            guard let workouts = samples as? [HKWorkout] else { return }
            let summaries = workouts.map { WorkoutSummary(workout: $0) }
            DispatchQueue.main.async {
                self.allWorkouts = summaries
                self.totalWorkoutsCount = summaries.count
                print("✅ Loaded \(summaries.count) total workouts (no HR)")
            }
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
                print("✅ Loaded \(summaries.count) recent workouts with stats")
            }
        }
        store.execute(query)
    }
    
    func loadTotalWorkoutsCount(from installDate: Date) {
        guard isAuthorized else { return }
        
        let workoutType    = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let predicate      = HKQuery.predicateForSamples(withStart: installDate, end: Date(), options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let error = error {
                print("❌ Error loading total workouts: \(error.localizedDescription)")
                return
            }
            let count = (samples as? [HKWorkout])?.count ?? 0
            DispatchQueue.main.async {
                self.totalWorkoutsCount = count
                print("✅ Workouts since install: \(count)")
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
                                self.loadAllWorkouts()
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
                    DispatchQueue.main.async {
                        self.loadRecentWorkouts()
                        self.loadAllWorkouts()
                    }
                }
            }
        }
        store.execute(query)
    }
}
