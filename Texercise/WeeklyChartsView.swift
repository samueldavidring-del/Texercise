import SwiftUI
import Charts

struct WeeklyChartsView: View {
    @EnvironmentObject var screenTimeStore: ScreenTimeStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var healthStore: HealthStore

    struct DailyValue: Identifiable {
        let id = UUID()
        let date: Date
        let category: String
        let value: Int
    }

    private var last7Days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -((6 - offset)), to: today)
        }
    }

    // MARK: Screen Time Data (Stacked by Category)
    private var screenTimeData: [DailyValue] {
        var data: [DailyValue] = []
        for day in last7Days {
            let categoriesForDay = screenTimeStore.minutesByCategory(on: day)
            for (category, minutes) in categoriesForDay {
                data.append(DailyValue(date: day, category: category, value: minutes))
            }
        }
        return data
    }

    // MARK: Exercise Data (Stacked by Type)
    private var exerciseData: [DailyValue] {
        var data: [DailyValue] = []
        for day in last7Days {
            let entriesForDay = exerciseStore.exercises(for: day)
            var typeCount: [String: Int] = [:]
            
            for entry in entriesForDay {
                let type = entry.type ?? "Other"
                let normalizedType: String
                if type.lowercased().contains("push") {
                    normalizedType = "Pushups"
                } else if type.lowercased().contains("squat") {
                    normalizedType = "Squats"
                } else if type.lowercased().contains("sit") {
                    normalizedType = "Sit-ups"
                } else if type.lowercased().contains("lunge") {
                    normalizedType = "Lunges"
                } else if type.lowercased().contains("plank") {
                    continue  // Skip plank - it's in seconds, not reps
                } else {
                    normalizedType = "Other"
                }
                typeCount[normalizedType, default: 0] += Int(entry.count)
            }
            
            for (type, count) in typeCount {
                data.append(DailyValue(date: day, category: type, value: count))
            }
        }
        return data
    }

    private var stepsData: [DailyValue] {
        last7Days.map { day in
            DailyValue(date: day, category: "Steps", value: healthStore.steps(on: day))
        }
    }

    private var weekdayFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "E"
        return df
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Last 7 Days")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            // MARK: Steps Chart
            VStack(alignment: .leading, spacing: 8) {
                Text("Steps")
                    .font(.headline)

                Chart(stepsData) { item in
                    BarMark(
                        x: .value("Day", weekdayFormatter.string(from: item.date)),
                        y: .value("Steps", item.value)
                    )
                    .foregroundStyle(Color.blue)
                }
                .frame(height: 180)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }

            // MARK: Exercise Chart (Stacked by Type)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Exercises (reps)")
                        .font(.headline)
                    Spacer()
                    Text("By Type")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if exerciseData.isEmpty {
                    Text("No exercise data yet")
                        .foregroundColor(.secondary)
                        .frame(height: 180)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Chart(exerciseData) { item in
                        BarMark(
                            x: .value("Day", weekdayFormatter.string(from: item.date)),
                            y: .value("Count", item.value)
                        )
                        .foregroundStyle(by: .value("Type", item.category))
                    }
                    .frame(height: 180)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartForegroundStyleScale([
                        "Pushups": Color.green,
                        "Squats": Color.blue,
                        "Sit-ups": Color.purple,
                        "Lunges": Color.orange,
                        "Other": Color.gray
                    ])
                    .chartLegend(position: .bottom, spacing: 8)
                }
            }

            // MARK: Screen Time Chart (Stacked by Category)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Screen Time (minutes)")
                        .font(.headline)
                    Spacer()
                    Text("By Category")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if screenTimeData.isEmpty {
                    Text("No screen time logged yet")
                        .foregroundColor(.secondary)
                        .frame(height: 180)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Chart(screenTimeData) { item in
                        BarMark(
                            x: .value("Day", weekdayFormatter.string(from: item.date)),
                            y: .value("Minutes", item.value)
                        )
                        .foregroundStyle(by: .value("Category", item.category))
                    }
                    .frame(height: 180)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartForegroundStyleScale([
                        "Social Media": Color.pink,
                        "Entertainment": Color.red,
                        "Gaming": Color.purple,
                        "Productivity": Color.blue,
                        "Other": Color.gray
                    ])
                    .chartLegend(position: .bottom, spacing: 8)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .onAppear {
            print("📊 WeeklyChartsView loaded")
            print("   Steps data: \(stepsData.count) items")
            print("   Exercise data: \(exerciseData.count) items")
            print("   Screen time data: \(screenTimeData.count) items")
        }
    }
}

#Preview {
    WeeklyChartsView()
        .environmentObject(ScreenTimeStore())
        .environmentObject(ExerciseStore())
        .environmentObject(HealthStore())
}
