import Foundation
import CoreData

class ExerciseStore: ObservableObject {
    private let viewContext: NSManagedObjectContext
    
    @Published var entries: [ExerciseEntry] = []
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.viewContext = context
    }
    
    func fetchEntries() {
        let request = NSFetchRequest<ExerciseEntry>(entityName: "ExerciseEntry")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ExerciseEntry.timestamp, ascending: false)]
        
        do {
            entries = try viewContext.fetch(request)
        } catch {
            print("❌ Failed to fetch exercise entries: \(error)")
        }
    }
    
    func addExercise(type: String, count: Int, date: Date = Date()) {
        let context = PersistenceController.shared.container.newBackgroundContext()
        
        context.perform {
            let entry = ExerciseEntry(context: context)
            entry.id = UUID()
            entry.type = type
            entry.count = Int32(count)
            entry.date = date
            entry.timestamp = date
            entry.notes = nil
            
            do {
                try context.save()
                DispatchQueue.main.async {
                    self.fetchEntries()
                }
            } catch {
                print("❌ Failed to save exercise: \(error)")
            }
        }
    }
    
    func logExercise(type: String, count: Int, date: Date = Date()) {
        addExercise(type: type, count: count, date: date)
    }
    
    func updateExercise(_ exercise: ExerciseEntry, type: String, count: Int, date: Date) {
        let objectID = exercise.objectID
        let context = PersistenceController.shared.container.newBackgroundContext()
        
        context.perform {
            do {
                let exerciseToUpdate = try context.existingObject(with: objectID) as! ExerciseEntry
                exerciseToUpdate.type = type
                exerciseToUpdate.count = Int32(count)
                exerciseToUpdate.date = date
                exerciseToUpdate.timestamp = date
                
                try context.save()
                
                DispatchQueue.main.async {
                    self.fetchEntries()
                }
            } catch {
                print("❌ Failed to update exercise: \(error)")
            }
        }
    }
    
    func deleteExercise(_ exercise: ExerciseEntry) {
        let objectID = exercise.objectID
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
                print("❌ Failed to delete exercise: \(error)")
            }
        }
    }
    
    func exercises(for date: Date) -> [ExerciseEntry] {
        let calendar = Calendar.current
        return entries.filter { entry in
            guard let timestamp = entry.timestamp else { return false }
            return calendar.isDate(timestamp, inSameDayAs: date)
        }
    }
    
    func entries(on date: Date) -> [ExerciseEntry] {
        return exercises(for: date)
    }
}
