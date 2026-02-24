import SwiftUI

struct DayDetailView: View {
    let date: Date

    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var screenTimeStore: ScreenTimeStore
    @EnvironmentObject var pointSettings: PointSettingsStore
    
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
            // Plank uses threshold
            return count / pointSettings.settings.plankSecondsPerPoint
        } else {
            // All other exercises: 1 rep = 1 point (no threshold)
            return count
        }
    }
    
    private func displayUnit(_ exercise: ExerciseEntry) -> String {
        let type = exercise.type?.lowercased() ?? ""
        if type.contains("plank") {
            return "sec"
        } else {
            return "reps"
        }
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
                            let workout = workouts[index]
                            healthStore.deleteWorkout(workout)
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
                            let exercise = exercises[index]
                            exerciseStore.deleteExercise(exercise)
                        }
                    }
                }
            }
            
            // MARK: Screen Time
            if !screenTimeEntries.isEmpty {
                Section("Screen Time") {
                    ForEach(screenTimeEntries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.category ?? "Screen Time")
                                    .font(.headline)
                            }
                            Spacer()
                            Text("\(entry.minutes) min")
                                .foregroundColor(.secondary)
                            Text("-\(Int(entry.minutes) / pointSettings.settings.screenTimeMinutesPerPenalty)")
                                .foregroundColor(.red)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let entry = screenTimeEntries[index]
                            screenTimeStore.deleteEntry(entry)
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
