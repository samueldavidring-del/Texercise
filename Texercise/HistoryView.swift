import SwiftUI
import HealthKit

struct HistoryView: View {
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var screenTimeStore: ScreenTimeStore
    @EnvironmentObject var pointSettings: PointSettingsStore
    @EnvironmentObject var blockingEventStore: BlockingEventStore
    
    @Binding var showingSettings: Bool
    
    @State private var errorMessage: String?
    @State private var showAllDays = false
    @State private var showAllWorkouts = false
    
    private let defaultLimit = 14
    
    private var last30Days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<30).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }
    
    private func pointsForDate(_ date: Date) -> DailyPoints {
        return PointsStore.pointsForDay(
            date: date,
            healthStore: healthStore,
            exerciseStore: exerciseStore,
            screenTimeStore: screenTimeStore,
            settings: pointSettings.settings
        )
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    Text("History")
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let error = errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            Text("Error Loading Data")
                                .font(.headline)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                    }
                    
                    // MARK: Weekly Charts
                    WeeklyChartsView()
                        .environmentObject(screenTimeStore)
                        .environmentObject(exerciseStore)
                        .environmentObject(healthStore)
                        .onAppear {
                            print("📊 WeeklyChartsView appeared")
                        }
                    
                    // MARK: Blocking Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("App Blocking")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            BlockingSummaryCard(label: "Today", count: blockingEventStore.todayCount)
                            BlockingSummaryCard(label: "Last 7 Days", count: blockingEventStore.last7DaysCount)
                            BlockingSummaryCard(label: "Last 30 Days", count: blockingEventStore.last30DaysCount)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    // MARK: Daily History
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recent Days")
                                .font(.headline)
                            Spacer()
                            Text("\(last30Days.count) days")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        let visibleDays = showAllDays ? last30Days : Array(last30Days.prefix(defaultLimit))
                        
                        LazyVStack(spacing: 8) {
                            ForEach(visibleDays, id: \.self) { date in
                                NavigationLink {
                                    DayDetailView(date: date)
                                        .environmentObject(healthStore)
                                        .environmentObject(exerciseStore)
                                        .environmentObject(screenTimeStore)
                                        .environmentObject(pointSettings)
                                        .environmentObject(blockingEventStore)
                                } label: {
                                    DayRowView(date: date, points: pointsForDate(date))
                                }
                            }
                        }
                        
                        if last30Days.count > defaultLimit {
                            Button {
                                withAnimation { showAllDays.toggle() }
                            } label: {
                                HStack {
                                    Text(showAllDays ? "Show less" : "Show all \(last30Days.count) days")
                                        .font(.subheadline)
                                    Image(systemName: showAllDays ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                }
                                .foregroundColor(.accentColor)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    // MARK: Workouts
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Workouts")
                                .font(.headline)
                            Spacer()
                            let thisMonthCount = healthStore.recentWorkouts.count
                            Text("\(thisMonthCount) this month · \(healthStore.allWorkouts.count) total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if healthStore.allWorkouts.isEmpty {
                            Text("No workouts recorded")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            let visibleWorkouts = showAllWorkouts ? healthStore.allWorkouts : Array(healthStore.allWorkouts.prefix(defaultLimit))
                            
                            LazyVStack(spacing: 8) {
                                ForEach(visibleWorkouts) { workout in
                                    NavigationLink {
                                        WorkoutDetailView(workout: workout)
                                            .environmentObject(healthStore)
                                    } label: {
                                        WorkoutHistoryRowView(workout: workout)
                                    }
                                }
                            }
                            
                            if healthStore.allWorkouts.count > defaultLimit {
                                Button {
                                    withAnimation { showAllWorkouts.toggle() }
                                } label: {
                                    HStack {
                                        Text(showAllWorkouts ? "Show less" : "Show all \(healthStore.allWorkouts.count) workouts")
                                            .font(.subheadline)
                                        Image(systemName: showAllWorkouts ? "chevron.up" : "chevron.down")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.accentColor)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 4)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                }
                .padding()
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
        }
    }
}

// MARK: - Day Row

struct DayRowView: View {
    let date: Date
    let points: DailyPoints
    
    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"
        return df
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateFormatter.string(from: date))
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Text("+\(points.earned)")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text("-\(points.screen)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            Text("\(points.net)")
                .font(.title3.bold().monospacedDigit())
                .foregroundColor(points.net >= 0 ? .green : .red)
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Workout History Row

struct WorkoutHistoryRowView: View {
    let workout: WorkoutSummary
    
    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"
        return df
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForWorkoutType(workout.activityType))
                .foregroundColor(.orange)
                .frame(width: 32)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(workout.activityName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Text(dateFormatter.string(from: workout.startDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let distance = workout.distanceMiles, distance > 0 {
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2f mi", distance))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(workout.durationMinutes) min")
                    .font(.subheadline.bold())
                Text("+\(workout.durationMinutes) pts")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
    
    private func iconForWorkoutType(_ type: UInt) -> String {
        switch type {
        case HKWorkoutActivityType.running.rawValue:  return "figure.run"
        case HKWorkoutActivityType.cycling.rawValue:  return "bicycle"
        case HKWorkoutActivityType.swimming.rawValue: return "figure.pool.swim"
        case HKWorkoutActivityType.walking.rawValue:  return "figure.walk"
        case HKWorkoutActivityType.hiking.rawValue:   return "figure.hiking"
        default:                                       return "figure.mixed.cardio"
        }
    }
}

// MARK: - Blocking Summary Card

struct BlockingSummaryCard: View {
    let label: String
    let count: Int
    
    var body: some View {
        VStack(spacing: 6) {
            Text("\(count)")
                .font(.title2.bold())
                .foregroundColor(count > 0 ? .red : .secondary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    MainTabView()
}
