import SwiftData
import XCTest
@testable import Trails

@MainActor
final class FavoritesTests: XCTestCase {
    func testRepositoryTogglesAndIgnoresDuplicates() throws {
        let repository = try makeRepository()
        let id = UUID()
        XCTAssertFalse(try repository.allIDs().contains(id))

        try repository.setMarked(true, workoutID: id)
        try repository.setMarked(true, workoutID: id)
        XCTAssertEqual(try repository.allIDs(), Set([id]))

        try repository.setMarked(false, workoutID: id)
        try repository.setMarked(false, workoutID: id)
        XCTAssertTrue(try repository.allIDs().isEmpty)
    }

    func testMarkingASampleRunSurvivesANewModel() async throws {
        let container = try makeContainer()
        let model = makeModel(container: container)
        await model.reload()
        let run = try XCTUnwrap(model.runs.first)

        XCTAssertTrue(model.markedRuns.isEmpty)
        model.toggleFavorite(run)
        XCTAssertEqual(model.markedRuns.map(\.id), [run.id])

        let reloaded = makeModel(container: container)
        await reloaded.reload()
        XCTAssertTrue(reloaded.favoriteIDs.contains(run.id))
        XCTAssertEqual(reloaded.markedRuns.map(\.id), [run.id])

        reloaded.toggleFavorite(run)
        XCTAssertTrue(reloaded.markedRuns.isEmpty)
    }

    private func makeRepository() throws -> FavoritesRepository {
        FavoritesRepository(container: try makeContainer())
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(UUID().uuidString, isStoredInMemoryOnly: true)
        return try ModelContainer(for: FavoriteMark.self, configurations: configuration)
    }

    private func makeModel(container: ModelContainer) -> AppModel {
        AppModel(
            healthSource: SampleWorkoutSource(),
            sampleSource: SampleWorkoutSource(),
            healthPhotos: SamplePhotoSource(),
            samplePhotos: SamplePhotoSource(),
            favorites: FavoritesRepository(container: container),
            healthAvailable: false
        )
    }
}
