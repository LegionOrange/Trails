import SwiftData
import SwiftUI

@main
struct TrailsApp: App {
    private let model: AppModel

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: FavoriteMark.self)
        } catch {
            fatalError("Kunde inte öppna lokal lagring: \(error.localizedDescription)")
        }
        model = AppModel(
            healthSource: HealthKitWorkoutSource(),
            sampleSource: SampleWorkoutSource(),
            healthPhotos: PhotoLibrarySource(),
            samplePhotos: SamplePhotoSource(),
            favorites: FavoritesRepository(container: container),
            healthAvailable: HealthKitWorkoutSource.isAvailable && !Self.isRunningUnitTests
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}
