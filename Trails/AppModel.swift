import Foundation
import SwiftData

@MainActor
@Observable
final class AppModel {
    enum DataSourceKind: String, CaseIterable, Identifiable {
        case sample
        case health

        var id: String { rawValue }

        var title: String {
            switch self {
            case .sample: "Exempel"
            case .health: "Hälsa"
            }
        }
    }

    private let healthSource: WorkoutSource
    private let sampleSource: WorkoutSource
    private let healthPhotos: WorkoutPhotoSource
    private let samplePhotos: WorkoutPhotoSource
    private let favorites: FavoritesRepository
    let healthAvailable: Bool

    private(set) var runs: [RunWorkout] = []
    private(set) var photos: [UUID: [WorkoutPhoto]] = [:]
    private(set) var favoriteIDs: Set<UUID> = []
    private(set) var isLoading = false
    private(set) var statusMessage: String?
    private(set) var dataSource: DataSourceKind
    private var didStart = false
    private var loadGeneration = 0

    init(
        healthSource: WorkoutSource,
        sampleSource: WorkoutSource,
        healthPhotos: WorkoutPhotoSource,
        samplePhotos: WorkoutPhotoSource,
        favorites: FavoritesRepository,
        healthAvailable: Bool
    ) {
        self.healthSource = healthSource
        self.sampleSource = sampleSource
        self.healthPhotos = healthPhotos
        self.samplePhotos = samplePhotos
        self.favorites = favorites
        self.healthAvailable = healthAvailable
        dataSource = healthAvailable ? .health : .sample
    }

    var markedRuns: [RunWorkout] {
        runs.filter { favoriteIDs.contains($0.id) }
    }

    func photos(for run: RunWorkout) -> [WorkoutPhoto] {
        photos[run.id] ?? []
    }

    func isFavorite(_ run: RunWorkout) -> Bool {
        favoriteIDs.contains(run.id)
    }

    func reloadIfNeeded() async {
        guard !didStart else { return }
        didStart = true
        await reload()
    }

    func setDataSource(_ kind: DataSourceKind) async {
        if kind == .health && !healthAvailable {
            statusMessage = "Hälsa finns inte i simulatorn. Exempelrutter visas i stället."
            return
        }
        guard kind != dataSource else { return }
        dataSource = kind
        await reload()
    }

    func reload() async {
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        statusMessage = nil

        let source: WorkoutSource = dataSource == .health ? healthSource : sampleSource
        let photoSource: WorkoutPhotoSource = dataSource == .health ? healthPhotos : samplePhotos
        do {
            try await source.prepare()
            let loaded = try await source.loadRuns().sorted { $0.startDate > $1.startDate }
            let loadedPhotos = await photoSource.photos(for: loaded)
            guard generation == loadGeneration else { return }
            runs = loaded
            favoriteIDs = try favorites.allIDs()
            photos = loadedPhotos
            isLoading = false
            if runs.isEmpty {
                statusMessage = dataSource == .health
                    ? "Inga löppass med GPS-rutt hittades i Hälsa."
                    : "Inga exempelrutter att visa."
            }
        } catch {
            guard generation == loadGeneration else { return }
            runs = []
            photos = [:]
            statusMessage = error.localizedDescription
            isLoading = false
        }
    }

    func toggleFavorite(_ run: RunWorkout) {
        let shouldMark = !favoriteIDs.contains(run.id)
        do {
            try favorites.setMarked(shouldMark, workoutID: run.id)
            if shouldMark {
                favoriteIDs.insert(run.id)
            } else {
                favoriteIDs.remove(run.id)
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

extension AppModel {
    static func preview(markedFirst: Bool = true) -> AppModel {
        let configuration = ModelConfiguration(UUID().uuidString, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: FavoriteMark.self, configurations: configuration)
        let model = AppModel(
            healthSource: SampleWorkoutSource(),
            sampleSource: SampleWorkoutSource(),
            healthPhotos: SamplePhotoSource(),
            samplePhotos: SamplePhotoSource(),
            favorites: FavoritesRepository(container: container),
            healthAvailable: false
        )
        model.runs = SampleWorkoutSource.runs
        model.photos = SamplePhotoSource.makePhotos(for: SampleWorkoutSource.runs)
        if markedFirst, let first = model.runs.first {
            model.toggleFavorite(first)
        }
        model.didStart = true
        return model
    }
}
