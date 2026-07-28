import UserNotifications
import Foundation

struct NotificationScheduler {
    
    static let goalReminderID      = "daily_goal_reminder"
    static let blockingWarningID   = "blocking_warning"
    static let screenTimeWarningID = "screen_time_warning"
    static let reminderHour        = 17  // 5 PM
    static let reminderMinute      = 0
    static let goalThreshold       = 0.8 // 80%
    
    // MARK: - Goal Reminder
    
    /// Call this whenever app becomes active with current progress values.
    /// Schedules or cancels the 5pm notification based on actual goal progress.
    static func updateGoalReminder(
        goals: GoalSettings,
        stepsToday: Int,
        pointsToday: Int,
        workoutMinutesToday: Int,
        exerciseRepsToday: Int
    ) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [goalReminderID])
        
        // If no goals are enabled, don't notify
        guard goals.anyGoalEnabled else {
            print("ℹ️ No goals enabled — skipping notification")
            return
        }
        
        // Check if all enabled goals are at least 80% met
        var allMet = true
        var unmetGoals: [String] = []
        
        if goals.stepsGoalEnabled {
            let progress = Double(stepsToday) / Double(goals.dailyStepsGoal)
            if progress < goalThreshold {
                allMet = false
                let remaining = goals.dailyStepsGoal - stepsToday
                unmetGoals.append("\(remaining) steps")
            }
        }
        if goals.pointsGoalEnabled {
            let progress = Double(pointsToday) / Double(goals.dailyPointsGoal)
            if progress < goalThreshold {
                allMet = false
                let remaining = goals.dailyPointsGoal - pointsToday
                unmetGoals.append("\(remaining) points")
            }
        }
        if goals.workoutGoalEnabled {
            let progress = Double(workoutMinutesToday) / Double(goals.dailyWorkoutMinutesGoal)
            if progress < goalThreshold {
                allMet = false
                let remaining = goals.dailyWorkoutMinutesGoal - workoutMinutesToday
                unmetGoals.append("\(remaining) workout min")
            }
        }
        if goals.exerciseGoalEnabled {
            let progress = Double(exerciseRepsToday) / Double(goals.dailyExerciseRepsGoal)
            if progress < goalThreshold {
                allMet = false
                let remaining = goals.dailyExerciseRepsGoal - exerciseRepsToday
                unmetGoals.append("\(remaining) reps")
            }
        }
        
        // All goals met — no need to notify
        if allMet {
            print("✅ All goals met — notification cancelled for today")
            return
        }
        
        // Build specific message about what's still needed
        let body: String
        if unmetGoals.isEmpty {
            body = "Keep going — you're almost at your goals for today!"
        } else if unmetGoals.count == 1 {
            body = "You still need \(unmetGoals[0]) to hit your goal today. Time to move!"
        } else {
            let list = unmetGoals.dropLast().joined(separator: ", ") + " and " + unmetGoals.last!
            body = "You still need \(list) to hit your goals today. Let's go!"
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Goal Check-in 💪"
        content.body = body
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = reminderHour
        dateComponents.minute = reminderMinute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: goalReminderID, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule goal reminder: \(error.localizedDescription)")
            } else {
                print("✅ Goal reminder scheduled for 5:00 PM — needs: \(unmetGoals.joined(separator: ", "))")
            }
        }
    }
    
    /// Legacy method — kept for compatibility
    static func scheduleGoalReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [goalReminderID])
        
        let content = UNMutableNotificationContent()
        content.title = "Goal Check-in 💪"
        content.body = "Open Texercise to see how you're doing on your goals today!"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = reminderHour
        dateComponents.minute = reminderMinute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: goalReminderID, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule goal reminder: \(error.localizedDescription)")
            } else {
                print("✅ Generic goal reminder scheduled for 5:00 PM daily")
            }
        }
    }
    
    // MARK: - Screen Time Warning (5 minutes left before blocking)
    
    /// Schedule a screen time warning notification.
    /// - Parameters:
    ///   - minutesLeft: Points remaining to show in the message.
    ///   - fireAfterMinutes: Delay before firing. Pass 0 or omit to fire immediately.
    static func scheduleScreenTimeWarning(minutesLeft: Int, fireAfterMinutes: Int = 0) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [screenTimeWarningID])
        
        let content = UNMutableNotificationContent()
        content.title = "⏳ Screen Time Almost Up"
        content.body = "You have about \(minutesLeft) minute\(minutesLeft == 1 ? "" : "s") of screen time left before your apps are blocked. Time to earn some points!"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        
        let interval = max(1, fireAfterMinutes * 60)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(interval), repeats: false)
        let request = UNNotificationRequest(identifier: screenTimeWarningID, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule screen time warning: \(error.localizedDescription)")
            } else {
                if fireAfterMinutes > 0 {
                    print("⏳ Screen time warning scheduled to fire in \(fireAfterMinutes) min (\(minutesLeft) min left message)")
                } else {
                    print("⏳ Screen time warning fired immediately — \(minutesLeft) min left")
                }
            }
        }
    }
    
    static func cancelScreenTimeWarning() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [screenTimeWarningID])
    }
    
    // MARK: - Blocking Warning (points-based, fired from main app)
    
    static func scheduleBlockingWarning(netPoints: Int, screenTimeMinutesPerPenalty: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [blockingWarningID])
        
        guard netPoints > 0 && netPoints <= 5 else { return }
        
        let minutesLeft = netPoints * screenTimeMinutesPerPenalty
        
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Apps About to Be Restricted"
        content.body = "You have about \(minutesLeft) minute\(minutesLeft == 1 ? "" : "s") of screen time left before your selected apps are blocked. Get moving!"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: blockingWarningID, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule blocking warning: \(error.localizedDescription)")
            } else {
                print("⚠️ Blocking warning sent - \(minutesLeft) minutes left")
            }
        }
    }
    
    static func cancelBlockingWarning() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [blockingWarningID])
    }
}
