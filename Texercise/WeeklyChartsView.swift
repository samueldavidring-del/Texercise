import SwiftUI
import Charts

// MARK: - Range Enum

enum ChartRange: String, CaseIterable {
    case sevenDays  = "7D"
    case thirtyDays = "30D"
    case ninetyDays = "90D"
}

// MARK: - WeeklyChartsView

struct WeeklyChartsView: View {
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var screenTimeStore: ScreenTimeStore
    @EnvironmentObject var healthStore: HealthStore

    @State private var selectedRange: ChartRange = .sevenDays
    @State private var selectedStepsLabel: String? = nil
    @State private var selectedExerciseLabel: String? = nil
    @State private var selectedScreenLabel: String? = nil

    private let calendar = Calendar.current

    // MARK: - Data Structs

    struct DayPoint: Identifiable {
        let id = UUID()
        let label: String
        let value: Int
    }

    struct StackedPoint: Identifiable {
        let id = UUID()
        let label: String
        let category: String
        let value: Int
    }

    // MARK: - Days in Range (oldest → newest)

    private var daysInRange: [Date] {
        let today = calendar.startOfDay(for: Date())
        let count: Int
        switch selectedRange {
        case .sevenDays:  count = 7
        case .thirtyDays: count = 30
        case .ninetyDays: count = 90
        }
        return (0..<count).compactMap {
            calendar.date(byAdding: .day, value: -($0), to: today)
        }.reversed()
    }

    // MARK: - Label Helpers

    private func dayLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        switch selectedRange {
        case .sevenDays:  fmt.dateFormat = "EEE"
        case .thirtyDays: fmt.dateFormat = "d"
        case .ninetyDays: fmt.dateFormat = "MMM d"
        }
        return fmt.string(from: date)
    }

    private func weekLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: date)
    }

    private func weekStart(for date: Date) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    // MARK: - Weekly Grouping Helper
    // Takes a closure that returns an Int for a given Date.
    // Groups daysInRange into ISO weeks, summing values, one DayPoint per week.

    private func weeklySum(_ getValue: (Date) -> Int) -> [DayPoint] {
        var buckets: [(start: Date, total: Int)] = []
        for day in daysInRange {
            let ws = weekStart(for: day)
            if let idx = buckets.firstIndex(where: { calendar.isDate($0.start, inSameDayAs: ws) }) {
                buckets[idx].total += getValue(day)
            } else {
                buckets.append((start: ws, total: getValue(day)))
            }
        }
        return buckets.map { DayPoint(label: weekLabel($0.start), value: $0.total) }
    }

    // MARK: - Steps Data

    private var stepsPoints: [DayPoint] {
        switch selectedRange {
        case .sevenDays, .thirtyDays:
            return daysInRange.map { day in
                DayPoint(label: dayLabel(day), value: healthStore.historicalSteps[day] ?? 0)
            }
        case .ninetyDays:
            return weeklySum { healthStore.historicalSteps[$0] ?? 0 }
        }
    }

    // MARK: - Exercise Data

    private func exerciseReps(on day: Date) -> Int {
        exerciseStore.exercises(for: day).reduce(0) { $0 + Int($1.count) }
    }

    private var exerciseData: [StackedPoint] {
        var result: [StackedPoint] = []
        for day in daysInRange {
            let lbl = dayLabel(day)
            var typeCount: [String: Int] = [:]
            for entry in exerciseStore.exercises(for: day) {
                let t = entry.type?.lowercased() ?? ""
                let normalized: String
                if t.contains("push")       { normalized = "Pushups" }
                else if t.contains("squat") { normalized = "Squats" }
                else if t.contains("sit")   { normalized = "Sit-ups" }
                else if t.contains("lunge") { normalized = "Lunges" }
                else if t.contains("plank") { continue }
                else                        { normalized = "Other" }
                typeCount[normalized, default: 0] += Int(entry.count)
            }
            if typeCount.isEmpty {
                result.append(StackedPoint(label: lbl, category: "None", value: 0))
            } else {
                for (type, count) in typeCount {
                    result.append(StackedPoint(label: lbl, category: type, value: count))
                }
            }
        }
        return result
    }

    private var exerciseWeeklyPoints: [DayPoint] {
        weeklySum { exerciseReps(on: $0) }
    }

    private func exerciseTotalForLabel(_ lbl: String) -> Int {
        exerciseData.filter { $0.label == lbl && $0.category != "None" }.reduce(0) { $0 + $1.value }
    }

    // MARK: - Screen Time Data

    private func normalizeScreenCategory(_ raw: String) -> String {
        switch raw {
        case "Social Media", "Entertainment", "Gaming", "Productivity", "Auto-tracked": return raw
        default: return "Other"
        }
    }

    private var screenTimeData: [StackedPoint] {
        var result: [StackedPoint] = []
        for day in daysInRange {
            let lbl = dayLabel(day)
            let raw = screenTimeStore.minutesByCategory(on: day)
            if raw.isEmpty {
                result.append(StackedPoint(label: lbl, category: "None", value: 0))
            } else {
                var merged: [String: Int] = [:]
                for (cat, mins) in raw {
                    merged[normalizeScreenCategory(cat), default: 0] += mins
                }
                for (cat, mins) in merged {
                    result.append(StackedPoint(label: lbl, category: cat, value: mins))
                }
            }
        }
        return result
    }

    private var screenTimeWeeklyPoints: [DayPoint] {
        weeklySum { screenTimeStore.totalMinutes(on: $0) }
    }

    private func screenTotalForLabel(_ lbl: String) -> Int {
        screenTimeData.filter { $0.label == lbl && $0.category != "None" }.reduce(0) { $0 + $1.value }
    }

    // MARK: - X-Axis Helpers

    private func xLabels(for points: [DayPoint]) -> [String] {
        thin(points.map(\.label))
    }

    private func xLabelsStacked(for points: [StackedPoint]) -> [String] {
        var seen = Set<String>()
        let unique = points.compactMap { p -> String? in
            guard !seen.contains(p.label) else { return nil }
            seen.insert(p.label)
            return p.label
        }
        return thin(unique)
    }

    private func thin(_ labels: [String]) -> [String] {
        switch selectedRange {
        case .sevenDays:  return labels
        case .thirtyDays: return labels.enumerated().compactMap { idx, l in idx % 5 == 0 ? l : nil }
        case .ninetyDays: return labels.enumerated().compactMap { idx, l in idx % 2 == 0 ? l : nil }
        }
    }

    // MARK: - Tap Handler

    private func handleTap(location: CGPoint, proxy: ChartProxy, geo: GeometryProxy, binding: Binding<String?>) {
        let origin = geo[proxy.plotAreaFrame].origin
        let x = location.x - origin.x
        if let lbl: String = proxy.value(atX: x) {
            binding.wrappedValue = (binding.wrappedValue == lbl) ? nil : lbl
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            Picker("Range", selection: $selectedRange) {
                ForEach(ChartRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: selectedRange) {
                selectedStepsLabel = nil
                selectedExerciseLabel = nil
                selectedScreenLabel = nil
            }

            stepsCard()
            exerciseCard()
            screenTimeCard()
        }
    }

    // MARK: - Steps Card

    @ViewBuilder
    private func stepsCard() -> some View {
        let points = stepsPoints
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Steps").font(.headline)
                Spacer()
                if let lbl = selectedStepsLabel,
                   let val = points.first(where: { $0.label == lbl })?.value {
                    Text("\(lbl): \(val) steps")
                        .font(.subheadline).foregroundColor(.blue)
                } else if selectedRange == .ninetyDays {
                    Text("Weekly total").font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            Chart(points) { point in
                BarMark(
                    x: .value("Period", point.label),
                    y: .value("Steps", point.value)
                )
                .foregroundStyle(
                    selectedStepsLabel == point.label
                        ? Color.blue
                        : (point.value > 0 ? Color.blue.opacity(0.65) : Color.clear)
                )
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: xLabels(for: points)) { value in
                    AxisValueLabel {
                        if let lbl = value.as(String.self) {
                            Text(lbl).font(.caption2)
                                .rotationEffect(selectedRange == .thirtyDays ? .degrees(-45) : .zero)
                        }
                    }
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(Color.clear).contentShape(Rectangle())
                        .onTapGesture { loc in
                            handleTap(location: loc, proxy: proxy, geo: geo, binding: $selectedStepsLabel)
                        }
                }
            }
            .frame(height: 180)
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Exercise Card

    @ViewBuilder
    private func exerciseCard() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Exercise Reps").font(.headline)
                Spacer()
                if let lbl = selectedExerciseLabel {
                    let total = selectedRange == .ninetyDays
                        ? (exerciseWeeklyPoints.first(where: { $0.label == lbl })?.value ?? 0)
                        : exerciseTotalForLabel(lbl)
                    Text("\(lbl): \(total) reps")
                        .font(.subheadline).foregroundColor(.green)
                } else {
                    Text(selectedRange == .ninetyDays ? "Weekly total" : "By Type")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            if selectedRange == .ninetyDays {
                let points = exerciseWeeklyPoints
                Chart(points) { point in
                    BarMark(
                        x: .value("Week", point.label),
                        y: .value("Reps", point.value)
                    )
                    .foregroundStyle(
                        selectedExerciseLabel == point.label
                            ? Color.green
                            : (point.value > 0 ? Color.green.opacity(0.65) : Color.clear)
                    )
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: xLabels(for: points)) { value in
                        AxisValueLabel {
                            if let lbl = value.as(String.self) {
                                Text(lbl).font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(Color.clear).contentShape(Rectangle())
                            .onTapGesture { loc in
                                handleTap(location: loc, proxy: proxy, geo: geo, binding: $selectedExerciseLabel)
                            }
                    }
                }
                .frame(height: 200)
                .padding(.horizontal)
            } else {
                Chart(exerciseData) { point in
                    BarMark(
                        x: .value("Day", point.label),
                        y: .value("Reps", point.value)
                    )
                    .foregroundStyle(by: .value("Type", point.category))
                    .opacity(selectedExerciseLabel == nil || selectedExerciseLabel == point.label ? 1.0 : 0.35)
                    .cornerRadius(2)
                }
                .chartForegroundStyleScale([
                    "Pushups": Color.green,
                    "Squats":  Color.blue,
                    "Sit-ups": Color.purple,
                    "Lunges":  Color.orange,
                    "Other":   Color.gray,
                    "None":    Color.clear
                ])
                .chartXAxis {
                    AxisMarks(values: xLabelsStacked(for: exerciseData)) { value in
                        AxisValueLabel {
                            if let lbl = value.as(String.self) {
                                Text(lbl).font(.caption2)
                                    .rotationEffect(selectedRange == .thirtyDays ? .degrees(-45) : .zero)
                            }
                        }
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .chartLegend(position: .bottom, spacing: 8)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(Color.clear).contentShape(Rectangle())
                            .onTapGesture { loc in
                                handleTap(location: loc, proxy: proxy, geo: geo, binding: $selectedExerciseLabel)
                            }
                    }
                }
                .frame(height: 200)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Screen Time Card

    @ViewBuilder
    private func screenTimeCard() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Screen Time").font(.headline)
                Spacer()
                if let lbl = selectedScreenLabel {
                    let total = selectedRange == .ninetyDays
                        ? (screenTimeWeeklyPoints.first(where: { $0.label == lbl })?.value ?? 0)
                        : screenTotalForLabel(lbl)
                    Text("\(lbl): \(total) min")
                        .font(.subheadline).foregroundColor(.orange)
                } else {
                    Text(selectedRange == .ninetyDays ? "Weekly total" : "By Category")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            if selectedRange == .ninetyDays {
                let points = screenTimeWeeklyPoints
                Chart(points) { point in
                    BarMark(
                        x: .value("Week", point.label),
                        y: .value("Minutes", point.value)
                    )
                    .foregroundStyle(
                        selectedScreenLabel == point.label
                            ? Color.orange
                            : (point.value > 0 ? Color.orange.opacity(0.65) : Color.clear)
                    )
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: xLabels(for: points)) { value in
                        AxisValueLabel {
                            if let lbl = value.as(String.self) {
                                Text(lbl).font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(Color.clear).contentShape(Rectangle())
                            .onTapGesture { loc in
                                handleTap(location: loc, proxy: proxy, geo: geo, binding: $selectedScreenLabel)
                            }
                    }
                }
                .frame(height: 200)
                .padding(.horizontal)
            } else {
                Chart(screenTimeData) { point in
                    BarMark(
                        x: .value("Day", point.label),
                        y: .value("Minutes", point.value)
                    )
                    .foregroundStyle(by: .value("Category", point.category))
                    .opacity(selectedScreenLabel == nil || selectedScreenLabel == point.label ? 1.0 : 0.35)
                    .cornerRadius(2)
                }
                .chartForegroundStyleScale([
                    "Social Media":  Color.pink,
                    "Entertainment": Color.red,
                    "Gaming":        Color.purple,
                    "Productivity":  Color.blue,
                    "Auto-tracked":  Color.orange,
                    "Other":         Color.gray,
                    "None":          Color.clear
                ])
                .chartXAxis {
                    AxisMarks(values: xLabelsStacked(for: screenTimeData)) { value in
                        AxisValueLabel {
                            if let lbl = value.as(String.self) {
                                Text(lbl).font(.caption2)
                                    .rotationEffect(selectedRange == .thirtyDays ? .degrees(-45) : .zero)
                            }
                        }
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .chartLegend(position: .bottom, spacing: 8)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(Color.clear).contentShape(Rectangle())
                            .onTapGesture { loc in
                                handleTap(location: loc, proxy: proxy, geo: geo, binding: $selectedScreenLabel)
                            }
                    }
                }
                .frame(height: 200)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}
