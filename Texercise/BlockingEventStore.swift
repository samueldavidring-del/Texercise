import Foundation

class BlockingEventStore: ObservableObject {
    
    private let appGroup = "group.com.samring.texercise"
    
    private var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }
    
    /// All blocking event timestamps, newest first
    private var allTimestamps: [Date] {
        let raw = (defaults?.array(forKey: SharedKeys.blockingEvents) as? [Double]) ?? []
        return raw.map { Date(timeIntervalSince1970: $0) }.sorted(by: >)
    }
    
    var todayCount: Int {
        let calendar = Calendar.current
        return allTimestamps.filter { calendar.isDateInToday($0) }.count
    }
    
    func events(on date: Date) -> [Date] {
        let calendar = Calendar.current
        return allTimestamps.filter { calendar.isDate($0, inSameDayAs: date) }
    }
    
    var last7DaysCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return allTimestamps.filter { $0 >= cutoff }.count
    }
    
    var last30DaysCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        return allTimestamps.filter { $0 >= cutoff }.count
    }
    
    /// Call this when app foregrounds to refresh counts
    func refresh() {
        objectWillChange.send()
    }
}
