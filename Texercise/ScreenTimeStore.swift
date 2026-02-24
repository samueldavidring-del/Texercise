import Foundation
import CoreData

class ScreenTimeStore: ObservableObject {
    private let viewContext: NSManagedObjectContext
    
    @Published var entries: [ScreenTimeEntry] = []
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.viewContext = context
    }
    
    func fetchEntries() {
        let request = NSFetchRequest<ScreenTimeEntry>(entityName: "ScreenTimeEntry")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ScreenTimeEntry.date, ascending: false)]
        
        do {
            entries = try viewContext.fetch(request)
        } catch {
            print("❌ Failed to fetch screen time entries: \(error)")
        }
    }
    
    func addEntry(date: Date, minutes: Int, category: String? = nil) {
        let context = PersistenceController.shared.container.newBackgroundContext()
        
        context.perform {
            let entry = ScreenTimeEntry(context: context)
            entry.id = UUID()
            entry.date = date
            entry.timestamp = date
            entry.minutes = Int32(minutes)
            entry.category = category
            entry.notes = nil
            
            do {
                try context.save()
                DispatchQueue.main.async {
                    self.fetchEntries()
                }
            } catch {
                print("❌ Failed to save screen time: \(error)")
            }
        }
    }
    
    func deleteEntry(_ entry: ScreenTimeEntry) {
        let objectID = entry.objectID
        let context = PersistenceController.shared.container.newBackgroundContext()
        
        context.perform {
            do {
                let entryToDelete = try context.existingObject(with: objectID)
                context.delete(entryToDelete)
                try context.save()
                
                DispatchQueue.main.async {
                    self.fetchEntries()
                }
            } catch {
                print("❌ Failed to delete screen time: \(error)")
            }
        }
    }
    
    func entries(on date: Date) -> [ScreenTimeEntry] {
        let calendar = Calendar.current
        return entries.filter { entry in
            guard let entryDate = entry.date else { return false }
            return calendar.isDate(entryDate, inSameDayAs: date)
        }
    }
    
    func totalMinutes(on date: Date) -> Int {
        entries(on: date).reduce(0) { $0 + Int($1.minutes) }
    }
    
    func minutesByCategory(on date: Date) -> [String: Int] {
        let entriesForDay = entries(on: date)
        var categoryMinutes: [String: Int] = [:]
        
        for entry in entriesForDay {
            let category = entry.category ?? "Other"
            categoryMinutes[category, default: 0] += Int(entry.minutes)
        }
        
        return categoryMinutes
    }
}
