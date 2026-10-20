import Foundation
import SwiftData

@MainActor
final class FavoritesRepository {
    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
    }

    func allIDs() throws -> Set<UUID> {
        let marks = try context.fetch(FetchDescriptor<FavoriteMark>())
        return Set(marks.compactMap { UUID(uuidString: $0.workoutID) })
    }

    func setMarked(_ marked: Bool, workoutID: UUID) throws {
        let id = workoutID.uuidString
        let predicate = #Predicate<FavoriteMark> { mark in
            mark.workoutID == id
        }
        var descriptor = FetchDescriptor<FavoriteMark>(predicate: predicate)
        descriptor.fetchLimit = 1
        let existing = try context.fetch(descriptor)
        if marked {
            guard existing.isEmpty else { return }
            context.insert(FavoriteMark(workoutID: id))
        } else if let mark = existing.first {
            context.delete(mark)
        } else {
            return
        }
        try context.save()
    }
}
