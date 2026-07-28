import SwiftUI

struct DayDetailView: View {
    let date: Date

    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var screenTimeStore: ScreenTimeStore
    @EnvironmentObject var pointSettings: PointSettingsStore
    @EnvironmentObject var blockingEventStore: BlockingEventStore
    
    @State private var exerciseToEdit: ExerciseEntry?

    private var points: DailyPoints {
        PointsStore.pointsForDay(
            date: date,
            healthStore: healthStore,
            exerciseStore: exerciseStore,
            screenTimeStore: screenTimeStore,
            settings: pointSettings.settings
        )
    }
    
    private var workouts: [WorkoutSummary] {
        healthStore.workouts(on: date)
    }
    
    private var exercises: [ExerciseEntry] {
        exerciseStore.exercises(for: date)
    }
    
    private var screenTimeEntries: [ScreenTimeEntry] {
        screenTimeStore.entries(on: date)
    }
    
    private func pointsForExercise(_ exercise: ExerciseEntry) -> Int {
        let type = exercise.type?.lowercased() ?? ""
        let count = Int(exercise.count)
        if type.contains("plank") {
            return count / pointSettings.settings.plankSecondsPerPoint
        } else {
            return count
        }
    }
    
    private func displayUnit(_ exercise: ExerciseEntry) -> String {
        let type = exercise.type?.lowercased() ?? ""
        return type.contains("plank") ? "sec" : "reps"
    }

    /// Formats minutes into a human-readable duration string.
    /// e.g. 5 → "5 min", 60 → "1h", 75 → "1h 15m"
    private func formatDuration(_ minutes: Int32) -> String {
        guard minutes > 0 else { return "0 min" }
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hrs = minutes / 60
        let mins = minutes % 60
        return mins == 0 ? "\(hrs)h" : "\(hrs)h \(mins)m"
    }

    var body: some View {
        List {

            // MARK: Summary
            Section {
                HStack {
                    Text("Net Points")
                    Spacer()
                    Text("\(points.net)")
                        .font(.title2.monospacedDigit())
                        .foregroundColor(points.net >= 0 ? .green : .red)
                }
                HStack {
                    Text("Earned")
                    Spacer()
                    Text("+\(points.earned)")
                }
                HStack {
                    Text("Screen Time")
                    Spacer()
                    Text("−\(points.screen)")
                }
            }

            // MARK: Breakdown
            Section("Breakdown") {
                HStack {
                    Label("Steps", systemImage: "figure.walk")
                    Spacer()
                    Text("+\(points.steps)")
                }
                HStack {
                    Label("Exercises", systemImage: "dumbbell")
                    Spacer()
                    Text("+\(points.exercise)")
                }
                HStack {
                    Label("Workouts", systemImage: "clock")
                    Spacer()
                    Text("+\(points.workout)")
                }
                HStack {
                    Label("Screen Time", systemImage: "iphone")
                    Spacer()
                    Text("−\(points.screen)")
                }
            }
            
            // MARK: Workouts
            if !workouts.isEmpty {
                Section("Workouts") {
                    ForEach(workouts) { workout in
                        NavigationLink {
                            WorkoutDetailView(workout: workout)
                                .environmentObject(healthStore)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(workout.activityName)
                                        .font(.headline)
                                    Text("\(workout.durationMinutes) min")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("+\(workout.durationMinutes / pointSettings.settings.workoutMinutesPerPoint)")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            healthStore.deleteWorkout(workouts[index])
                        }
                    }
                }
            }
            
            // MARK: Exercise Sessions
            if !exercises.isEmpty {
                Section("Exercise Sessions") {
                    ForEach(exercises) { exercise in
                        Button {
                            exerciseToEdit = exercise
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.type ?? "Exercise")
                                        .font(.headline)
                                    if let timestamp = exercise.timestamp {
                                        Text(timestamp, style: .time)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(exercise.count) \(displayUnit(exercise))")
                                    .foregroundColor(.secondary)
                                Text("+\(pointsForExercise(exercise))")
                                    .foregroundColor(.green)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            exerciseStore.deleteExercise(exercises[index])
                        }
                    }
                }
            }
            
            // MARK: Screen Time
            if !screenTimeEntries.isEmpty {
                let totalMinutes = screenTimeEntries.reduce(0) { $0 + Int($1.minutes) }
                Section(
                    header: Text("Screen Time"),
                    footer: Text("Total: \(formatDuration(Int32(totalMinutes))) · −\(totalMinutes / pointSettings.settings.screenTimeMinutesPerPenalty) pts")
                        .font(.caption)
                ) {
                    ForEach(screenTimeEntries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.category ?? "Screen Time")
                                    .font(.headline)
                                if let timestamp = entry.timestamp ?? entry.date {
                                    Text(timestamp, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(formatDuration(entry.minutes))
                                .foregroundColor(.secondary)
                            Text("−\(Int(entry.minutes) / pointSettings.settings.screenTimeMinutesPerPenalty)")
                                .foregroundColor(.red)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            screenTimeStore.deleteEntry(screenTimeEntries[index])
                        }
                    }
                }
            }
            
            // MARK: Blocking Events
            let blockingEvents = blockingEventStore.events(on: date)
            if !blockingEvents.isEmpty {
                Section("App Blocking (\(blockingEvents.count) times)") {
                    ForEach(blockingEvents, id: \.self) { event in
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            Text("Blocked at")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(event, style: .time)
                                .font(.subheadline.monospacedDigit())
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .navigationTitle(date.formatted(date: .abbreviated, time: .omitted))
        .sheet(item: $exerciseToEdit) { exercise in
            EditExerciseView(exercise: exercise)
                .environmentObject(exerciseStore)
        }
    }
}

#Preview {
    MainTabView()
}
