import UserNotifications
import Foundation

struct NotificationScheduler {
    
    static let goalReminderID       = "daily_goal_reminder"
    static let blockingWarningID    = "blocking_warning"
    static let reminderHour         = 17  // 5 PM
    static let reminderMinute       = 0
    static let goalThreshold        = 0.8  // 80%
    
    // MARK: - Goal Reminder
    
    static func scheduleGoalReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [goalReminderID])
        
        let content = UNMutableNotificationContent()
        content.title = "Goal Check-in 💪"
        content.body = "You haven't hit 80% of your goals yet today. Time to move!"
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
                print("✅ Goal reminder scheduled for 5:00 PM daily")
            }
        }
    }
    
    static func cancelIfGoalsMet(
        stepsProgress: Double,
        pointsProgress: Double,
        workoutProgress: Double,
        exerciseProgress: Double,
        stepsEnabled: Bool,
        pointsEnabled: Bool,
        workoutEnabled: Bool,
        exerciseEnabled: Bool
    ) {
        var allGoalsMet = true
        
        if stepsEnabled    && stepsProgress    < goalThreshold { allGoalsMet = false }
        if pointsEnabled   && pointsProgress   < goalThreshold { allGoalsMet = false }
        if workoutEnabled  && workoutProgress  < goalThreshold { allGoalsMet = false }
        if exerciseEnabled && exerciseProgress < goalThreshold { allGoalsMet = false }
        
        if allGoalsMet {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: [goalReminderID])
            print("✅ All goals met - notification cancelled for today")
            scheduleGoalReminder()
        }
    }
    
    // MARK: - Blocking Warning
    
    // Call this when net points are close to 0 (within warningThreshold points)
    // pointsPerScreenMinute is used to calculate how many minutes are left
    static func scheduleBlockingWarning(netPoints: Int, screenTimeMinutesPerPenalty: Int) {
        let center = UNUserNotificationCenter.current()
        
        // Cancel any existing warning first
        center.removePendingNotificationRequests(withIdentifiers: [blockingWarningID])
        
        // Only warn if within 5 penalty points of blocking (i.e. about 5 minutes of screen time left)
        guard netPoints > 0 && netPoints <= 5 else { return }
        
        // Calculate minutes of screen time remaining before hitting 0
        let minutesLeft = netPoints * screenTimeMinutesPerPenalty
        
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Apps About to Be Restricted"
        content.body = "You have about \(minutesLeft) minute\(minutesLeft == 1 ? "" : "s") of screen time left before your selected apps are blocked. Get moving!"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        
        // Fire immediately (user is already close to blocking)
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
