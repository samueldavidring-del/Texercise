import SwiftUI
import HealthKit

struct TodayView: View {
    @EnvironmentObject var healthStore: HealthStore
    @EnvironmentObject var screenTimeStore: ScreenTimeStore
    @EnvironmentObject var exerciseStore: ExerciseStore
    @EnvironmentObject var pointSettings: PointSettingsStore
    @EnvironmentObject var goalSettings: GoalSettingsStore
    
    @Binding var showingSettings: Bool
    
    @State private var showingExerciseOptions = false
    @State private var showingAddWorkout = false
    @State private var showingAddScreenTime = false
    
    private var todayPoints: Int {
        let workouts = healthStore.workouts(on: Date())
        let exercises = exerciseStore.exercises(for: Date())
        let screenMinutes = screenTimeStore.totalMinutes(on: Date())
        return Points.today(
            steps: healthStore.stepsToday,
            workouts: workouts,
            exercises: exercises,
            screenMinutes: screenMinutes,
            settings: pointSettings.settings
        )
    }
    
    private var todaysWorkouts: [WorkoutSummary] {
        healthStore.workouts(on: Date())
    }
    
    private var todayWorkoutMinutes: Int {
        todaysWorkouts.reduce(0) { $0 + $1.durationMinutes }
    }
    
    private var todayExerciseReps: Int {
        exerciseStore.exercises(for: Date()).reduce(0) { $0 + Int($1.count) }
    }
    
    // Progress calculations
    private var stepsProgress: Double {
        Double(healthStore.stepsToday) / Double(goalSettings.goals.dailyStepsGoal)
    }
    
    private var pointsProgress: Double {
        Double(todayPoints) / Double(goalSettings.goals.dailyPointsGoal)
    }
    
    private var workoutProgress: Double {
        Double(todayWorkoutMinutes) / Double(goalSettings.goals.dailyWorkoutMinutesGoal)
    }
    
    private var exerciseProgress: Double {
        Double(todayExerciseReps) / Double(goalSettings.goals.dailyExerciseRepsGoal)
    }
    
    private func pointsForExerciseType(_ type: String, count: Int) -> Int {
        if type.lowercased().contains("plank") {
            return count / pointSettings.settings.plankSecondsPerPoint
        } else {
            return count
        }
    }
    
    private func checkAndCancelNotification() {
        NotificationScheduler.cancelIfGoalsMet(
            stepsProgress: stepsProgress,
            pointsProgress: pointsProgress,
            workoutProgress: workoutProgress,
            exerciseProgress: exerciseProgress,
            stepsEnabled: goalSettings.goals.stepsGoalEnabled,
            pointsEnabled: goalSettings.goals.pointsGoalEnabled,
            workoutEnabled: goalSettings.goals.workoutGoalEnabled,
            exerciseEnabled: goalSettings.goals.exerciseGoalEnabled
        )
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - Progress Rings with Net Points (Only if goals enabled)
                    if goalSettings.goals.anyGoalEnabled {
                        ZStack {
                            MultiRingView(
                                stepsProgress: stepsProgress,
                                pointsProgress: pointsProgress,
                                workoutProgress: workoutProgress,
                                exerciseProgress: exerciseProgress,
                                stepsEnabled: goalSettings.goals.stepsGoalEnabled,
                                pointsEnabled: goalSettings.goals.pointsGoalEnabled,
                                workoutEnabled: goalSettings.goals.workoutGoalEnabled,
                                exerciseEnabled: goalSettings.goals.exerciseGoalEnabled
                            )
                            
                            // Net Points in center of rings
                            VStack(spacing: 4) {
                                Text("\(todayPoints)")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(todayPoints >= 0 ? .green : .red)
                                
                                Text("Net Points")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical)
                        .padding(.horizontal)
                        
                        // Legend (only show enabled goals)
                        HStack(spacing: 20) {
                            if goalSettings.goals.stepsGoalEnabled {
                                VStack(spacing: 4) {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 8, height: 8)
                                        Text("Steps")
                                            .font(.caption2)
                                    }
                                    Text("\(healthStore.stepsToday)/\(goalSettings.goals.dailyStepsGoal)")
                                        .font(.caption2.bold())
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if goalSettings.goals.pointsGoalEnabled {
                                VStack(spacing: 4) {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 8, height: 8)
                                        Text("Points")
                                            .font(.caption2)
                                    }
                                    Text("\(todayPoints)/\(goalSettings.goals.dailyPointsGoal)")
                                        .font(.caption2.bold())
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if goalSettings.goals.workoutGoalEnabled {
                                VStack(spacing: 4) {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.orange)
                                            .frame(width: 8, height: 8)
                                        Text("Workout")
                                            .font(.caption2)
                                    }
                                    Text("\(todayWorkoutMinutes)/\(goalSettings.goals.dailyWorkoutMinutesGoal)")
                                        .font(.caption2.bold())
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if goalSettings.goals.exerciseGoalEnabled {
                                VStack(spacing: 4) {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.purple)
                                            .frame(width: 8, height: 8)
                                        Text("Exercise")
                                            .font(.caption2)
                                    }
                                    Text("\(todayExerciseReps)/\(goalSettings.goals.dailyExerciseRepsGoal)")
                                        .font(.caption2.bold())
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.bottom)
                        .padding(.horizontal)
                    } else {
                        // Show net points card if no goals enabled
                        VStack(spacing: 8) {
                            Text("Today's Net Points")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("\(todayPoints)")
                                .font(.system(size: 72, weight: .bold))
                                .foregroundColor(todayPoints >= 0 ? .green : .red)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 10)
                        .padding(.horizontal)
                    }
                    
                    // MARK: - Health Stats
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Health")
                            .font(.title2.bold())
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "figure.walk")
                                    .foregroundColor(.green)
                                    .frame(width: 30)
                                Text("Steps")
                                Spacer()
                                Text("\(healthStore.stepsToday)")
                                    .bold()
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            
                            HStack {
                                Image(systemName: "figure.run")
                                    .foregroundColor(.orange)
                                    .frame(width: 30)
                                Text("Distance")
                                Spacer()
                                Text(String(format: "%.1f mi", healthStore.distanceTodayMiles))
                                    .bold()
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    // MARK: - Workouts Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Workouts")
                                .font(.title2.bold())
                            Spacer()
                            Button {
                                showingAddWorkout = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                            }
                        }
                        .padding(.horizontal)
                        
                        if todaysWorkouts.isEmpty {
                            Text("No workouts yet today")
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(todaysWorkouts) { workout in
                                    NavigationLink {
                                        WorkoutDetailView(workout: workout)
                                            .environmentObject(healthStore)
                                    } label: {
                                        WorkoutRowView(workout: workout)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // MARK: - Exercises (Pushups, Squats, Sit-ups, Lunges, Plank)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Exercises")
                                .font(.title2.bold())
                            Spacer()
                            Button {
                                showingExerciseOptions = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                            }
                        }
                        .padding(.horizontal)
                        
                        let todaysExercises = exerciseStore.exercises(for: Date())
                        
                        if todaysExercises.isEmpty {
                            Text("No exercises logged yet")
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else {
                            let exerciseSummary = Dictionary(grouping: todaysExercises) { entry -> String in
                                let type = entry.type ?? "Other"
                                if type.lowercased().contains("push") {
                                    return "Pushups"
                                } else if type.lowercased().contains("squat") {
                                    return "Squats"
                                } else if type.lowercased().contains("sit") {
                                    return "Sit-ups"
                                } else if type.lowercased().contains("lunge") {
                                    return "Lunges"
                                } else if type.lowercased().contains("plank") {
                                    return "Plank"
                                } else {
                                    return "Other"
                                }
                            }
                            .mapValues { exercises in
                                exercises.reduce(0) { $0 + Int($1.count) }
                            }
                            .sorted { $0.key < $1.key }
                            
                            VStack(spacing: 8) {
                                ForEach(exerciseSummary, id: \.key) { type, total in
                                    HStack {
                                        Image(systemName: iconForExerciseType(type))
                                            .foregroundColor(.purple)
                                            .frame(width: 30)
                                        
                                        Text(type)
                                            .font(.headline)
                                        
                                        Spacer()
                                        
                                        if type.lowercased().contains("plank") {
                                            Text("\(total) sec")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text("\(total) reps")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Text("+\(pointsForExerciseType(type, count: total))")
                                            .font(.headline)
                                            .foregroundColor(.green)
                                    }
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // MARK: - Screen Time
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Screen Time")
                                .font(.title2.bold())
                            Spacer()
                            Button {
                                showingAddScreenTime = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                            }
                        }
                        .padding(.horizontal)
                        
                        let todaysScreenTime = screenTimeStore.entries(on: Date())
                        let totalMinutes = screenTimeStore.totalMinutes(on: Date())
                        
                        if todaysScreenTime.isEmpty {
                            Text("No screen time logged yet")
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else {
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "iphone")
                                        .foregroundColor(.red)
                                        .frame(width: 30)
                                    Text("Total Screen Time")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(totalMinutes) min")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                    Text("-\(totalMinutes / pointSettings.settings.screenTimeMinutesPerPenalty)")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .onAppear {
                checkAndCancelNotification()
            }
            .onChange(of: todayPoints) { _ in
                checkAndCancelNotification()
            }
            .sheet(isPresented: $showingExerciseOptions) {
                ExerciseOptionsView()
                    .environmentObject(exerciseStore)
            }
            .sheet(isPresented: $showingAddWorkout) {
                AddWorkoutView()
                    .environmentObject(healthStore)
            }
            .sheet(isPresented: $showingAddScreenTime) {
                AddScreenTimeView()
                    .environmentObject(screenTimeStore)
            }
        }
    }
    
    private func iconForExerciseType(_ type: String) -> String {
        let t = type.lowercased()
        if t.contains("push") {
            return "figure.strengthtraining.traditional"
        } else if t.contains("squat") {
            return "figure.strengthtraining.functional"
        } else if t.contains("sit") {
            return "figure.core.training"
        } else if t.contains("lunge") {
            return "figure.walk"
        } else if t.contains("plank") {
            return "figure.core.training"
        } else {
            return "figure.strengthtraining.traditional"
        }
    }
}

// MARK: - Workout Row View
struct WorkoutRowView: View {
    let workout: WorkoutSummary
    
    var body: some View {
        HStack {
            Image(systemName: iconForWorkoutType(workout.activityType))
                .foregroundColor(.orange)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.activityName)
                    .font(.headline)
                
                HStack {
                    Text("\(workout.durationMinutes) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let distance = workout.distanceMiles, distance > 0 {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2f mi", distance))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Text("+\(workout.durationMinutes)")
                .font(.headline)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func iconForWorkoutType(_ type: UInt) -> String {
        switch type {
        case HKWorkoutActivityType.running.rawValue: return "figure.run"
        case HKWorkoutActivityType.cycling.rawValue: return "bicycle"
        case HKWorkoutActivityType.swimming.rawValue: return "figure.pool.swim"
        case HKWorkoutActivityType.walking.rawValue: return "figure.walk"
        case HKWorkoutActivityType.hiking.rawValue: return "figure.hiking"
        default: return "figure.mixed.cardio"
        }
    }
}

#Preview {
    MainTabView()
}
