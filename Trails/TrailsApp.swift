import SwiftData
import SwiftUI

@main
struct TrailsApp: App {
    private let model: AppModel

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// `-demo-data` forces the sample routes and bundled photos, with no Health or Photos prompt.
    private static var usesDemoData: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo-data")
    }

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: FavoriteMark.self)
        } catch {
            fatalError("Kunde inte öppna lokal lagring: \(error.localizedDescription)")
        }
        let demoData = Self.usesDemoData
        model = AppModel(
            healthSource: HealthKitWorkoutSource(),
            sampleSource: SampleWorkoutSource(),
            healthPhotos: PhotoLibrarySource(),
            samplePhotos: SamplePhotoSource(),
            favorites: FavoritesRepository(container: container),
            healthAvailable: HealthKitWorkoutSource.isAvailable && !demoData && !Self.isRunningUnitTests,
            seedsDemoFavorites: demoData
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}
