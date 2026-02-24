import SwiftUI
import HealthKit

struct WorkoutDetailView: View {
    let workout: WorkoutSummary
    
    @EnvironmentObject var healthStore: HealthStore
    @State private var useKilometers = false
    @State private var showingEditSheet = false
    
    private var distanceInKm: Double? {
        guard let miles = workout.distanceMiles else { return nil }
        return miles * 1.60934
    }
    
    // Pace uses full durationSeconds for accuracy
    private var paceMinPerMile: String? {
        guard let distance = workout.distanceMiles, distance > 0, workout.durationSeconds > 0 else { return nil }
        let paceSecondsPerMile = workout.durationSeconds / distance
        let minutes = Int(paceSecondsPerMile) / 60
        let seconds = Int(paceSecondsPerMile) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var paceMinPerKm: String? {
        guard let distKm = distanceInKm, distKm > 0, workout.durationSeconds > 0 else { return nil }
        let paceSecondsPerKm = workout.durationSeconds / distKm
        let minutes = Int(paceSecondsPerKm) / 60
        let seconds = Int(paceSecondsPerKm) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var displayedPace: String? {
        useKilometers ? paceMinPerKm.map { "\($0) /km" } : paceMinPerMile.map { "\($0) /mi" }
    }
    
    private var displayedDistance: String {
        if useKilometers, let km = distanceInKm {
            return String(format: "%.2f km", km)
        } else if let miles = workout.distanceMiles {
            return String(format: "%.2f mi", miles)
        }
        return "N/A"
    }
    
    private var speed: String? {
        let durationHours = workout.durationSeconds / 3600.0
        if useKilometers {
            guard let distKm = distanceInKm, distKm > 0 else { return nil }
            return String(format: "%.1f km/h", distKm / durationHours)
        } else {
            guard let distance = workout.distanceMiles, distance > 0 else { return nil }
            return String(format: "%.1f mph", distance / durationHours)
        }
    }
    
    private var caloriesPerMinute: String? {
        guard let calories = workout.caloriesBurned, calories > 0, workout.durationSeconds > 0 else { return nil }
        let rate = calories / (workout.durationSeconds / 60.0)
        return String(format: "%.1f cal/min", rate)
    }
    
    private var hasMultipleMetrics: Bool {
        var count = 0
        if workout.distanceMiles != nil { count += 1 }
        if workout.averageHeartRate != nil { count += 1 }
        if workout.caloriesBurned != nil { count += 1 }
        return count >= 2
    }
    
    var body: some View {
        List {
            // Summary Section
            Section {
                VStack(spacing: 16) {
                    Image(systemName: iconForWorkoutType(workout.activityType))
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text(workout.activityName)
                        .font(.title.bold())
                    
                    Text(workout.startDate, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            
            // Duration
            Section("Duration") {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                    Text("Time")
                    Spacer()
                    Text(workout.durationFormatted)
                        .bold()
                }
            }
            
            // Distance & Pace
            if let distance = workout.distanceMiles, distance > 0 {
                Section {
                    HStack {
                        Text("Units")
                        Spacer()
                        Picker("Units", selection: $useKilometers) {
                            Text("Miles").tag(false)
                            Text("Kilometers").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                } header: {
                    Text("Distance & Pace")
                }
                
                Section {
                    HStack {
                        Image(systemName: "figure.run")
                            .foregroundColor(.green)
                        Text("Distance")
                        Spacer()
                        Text(displayedDistance)
                            .bold()
                    }
                    
                    if let paceStr = displayedPace {
                        HStack {
                            Image(systemName: "speedometer")
                                .foregroundColor(.purple)
                            Text("Pace")
                            Spacer()
                            Text(paceStr)
                                .bold()
                        }
                    }
                    
                    if let speedStr = speed {
                        HStack {
                            Image(systemName: "gauge.high")
                                .foregroundColor(.orange)
                            Text("Speed")
                            Spacer()
                            Text(speedStr)
                                .bold()
                        }
                    }
                }
            }
            
            // Heart Rate
            if workout.averageHeartRate != nil || workout.maxHeartRate != nil {
                Section("Heart Rate") {
                    if let avgHR = workout.averageHeartRate {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text("Average")
                            Spacer()
                            Text(String(format: "%.0f bpm", avgHR))
                                .bold()
                        }
                    }
                    
                    if let maxHR = workout.maxHeartRate {
                        HStack {
                            Image(systemName: "bolt.heart.fill")
                                .foregroundColor(.pink)
                            Text("Maximum")
                            Spacer()
                            Text(String(format: "%.0f bpm", maxHR))
                                .bold()
                        }
                    }
                }
            }
            
            // Calories
            if let calories = workout.caloriesBurned, calories > 0 {
                Section("Energy") {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.red)
                        Text("Total Calories")
                        Spacer()
                        Text(String(format: "%.0f cal", calories))
                            .bold()
                    }
                    
                    if let rate = caloriesPerMinute {
                        HStack {
                            Image(systemName: "flame")
                                .foregroundColor(.orange)
                            Text("Burn Rate")
                            Spacer()
                            Text(rate)
                                .bold()
                        }
                    }
                }
            }
            
            // Elevation
            if let elevation = workout.elevationGain, elevation > 0 {
                Section("Elevation") {
                    HStack {
                        Image(systemName: "mountain.2.fill")
                            .foregroundColor(.brown)
                        Text("Elevation Gain")
                        Spacer()
                        Text(useKilometers
                             ? String(format: "%.0f m", elevation * 0.3048)
                             : String(format: "%.0f ft", elevation))
                            .bold()
                    }
                }
            }
            
            // Time Details
            Section("Time") {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.blue)
                    Text("Started")
                    Spacer()
                    Text(workout.startDate, style: .time)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundColor(.green)
                    Text("Ended")
                    Spacer()
                    Text(workout.endDate, style: .time)
                        .foregroundColor(.secondary)
                }
            }
            
            // Summary Stats
            if hasMultipleMetrics {
                Section("Summary") {
                    VStack(alignment: .leading, spacing: 12) {
                        if let distance = workout.distanceMiles, distance > 0 {
                            StatRow(icon: "figure.run", color: .green, label: "Distance", value: displayedDistance)
                        }
                        if let pace = displayedPace {
                            StatRow(icon: "speedometer", color: .purple, label: "Avg Pace", value: pace)
                        }
                        if let avgHR = workout.averageHeartRate {
                            StatRow(icon: "heart.fill", color: .red, label: "Avg HR", value: String(format: "%.0f bpm", avgHR))
                        }
                        if let calories = workout.caloriesBurned {
                            StatRow(icon: "flame.fill", color: .orange, label: "Calories", value: String(format: "%.0f", calories))
                        }
                    }
                }
            }
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEditSheet = true }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditWorkoutView(workout: workout)
                .environmentObject(healthStore)
        }
    }
    
    private func iconForWorkoutType(_ type: UInt) -> String {
        switch type {
        case HKWorkoutActivityType.running.rawValue: return "figure.run"
        case HKWorkoutActivityType.cycling.rawValue: return "bicycle"
        case HKWorkoutActivityType.swimming.rawValue: return "figure.pool.swim"
        case HKWorkoutActivityType.walking.rawValue: return "figure.walk"
        case HKWorkoutActivityType.hiking.rawValue: return "figure.hiking"
        case HKWorkoutActivityType.yoga.rawValue: return "figure.yoga"
        case HKWorkoutActivityType.functionalStrengthTraining.rawValue: return "dumbbell.fill"
        case HKWorkoutActivityType.traditionalStrengthTraining.rawValue: return "dumbbell.fill"
        case HKWorkoutActivityType.elliptical.rawValue: return "figure.elliptical"
        case HKWorkoutActivityType.rowing.rawValue: return "figure.rowing"
        default: return "figure.mixed.cardio"
        }
    }
}

struct StatRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }
}

#Preview {
    NavigationView {
        WorkoutDetailView(
            workout: WorkoutSummary(
                id: UUID(),
                activityType: HKWorkoutActivityType.running.rawValue,
                activityName: "Running",
                startDate: Date().addingTimeInterval(-3600),
                endDate: Date(),
                durationSeconds: 3765,  // 62:45
                distanceMiles: 6.2,
                caloriesBurned: 450,
                averageHeartRate: 145,
                maxHeartRate: 172,
                elevationGain: 250
            )
        )
        .environmentObject(HealthStore())
    }
}
