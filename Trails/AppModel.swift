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
    let seedsDemoFavorites: Bool

    private(set) var runs: [RunWorkout] = []
    private(set) var photos: [UUID: [WorkoutPhoto]] = [:]
    private(set) var favoriteIDs: Set<UUID> = []
    private(set) var isLoading = false
    private(set) var statusMessage: String?
    private(set) var dataSource: DataSourceKind
    var filter = RouteFilter()
    var mapDrawMode: MapDrawMode = .routes
    var recenterToken = 0
    var focusedRunID: UUID?
    private(set) var isSelecting = false
    private(set) var chosenRunIDs: Set<UUID> = []
    var showsSelectionSummary = false
    private var didStart = false
    private var didSeedFilterDates = false
    private var loadGeneration = 0

    init(
        healthSource: WorkoutSource,
        sampleSource: WorkoutSource,
        healthPhotos: WorkoutPhotoSource,
        samplePhotos: WorkoutPhotoSource,
        favorites: FavoritesRepository,
        healthAvailable: Bool,
        seedsDemoFavorites: Bool = false
    ) {
        self.healthSource = healthSource
        self.sampleSource = sampleSource
        self.healthPhotos = healthPhotos
        self.samplePhotos = samplePhotos
        self.favorites = favorites
        self.healthAvailable = healthAvailable
        self.seedsDemoFavorites = seedsDemoFavorites
        dataSource = healthAvailable ? .health : .sample
    }

    var markedRuns: [RunWorkout] {
        runs.filter { favoriteIDs.contains($0.id) }
    }

    var visibleRuns: [RunWorkout] {
        runs.filter {
            filter.allows($0, isMarked: isFavorite($0), isChosen: chosenRunIDs.contains($0.id))
        }
    }

    var chosenRuns: [RunWorkout] {
        runs.filter { chosenRunIDs.contains($0.id) }
    }

    var mapRuns: [RunWorkout] {
        showsSelectionSummary ? chosenRuns : visibleRuns
    }

    var focusedRun: RunWorkout? {
        guard let focusedRunID else { return nil }
        return runs.first { $0.id == focusedRunID }
    }

    var statistics: RouteStatistics {
        RouteStatistics.summarize(visibleRuns)
    }

    var selectionStatistics: RouteStatistics {
        RouteStatistics.summarize(chosenRuns)
    }

    var timelineTitle: String {
        if filter.selectedOnly { return "Endast valda" }
        if filter.markedOnly { return "Markerade" }
        if filter.usesDateRange {
            let start = RunFormatting.date(min(filter.startDate, filter.endDate))
            let end = RunFormatting.date(max(filter.startDate, filter.endDate))
            return "\(start) – \(end)"
        }
        if filter.usesDistanceRange { return "Distansfilter" }
        return "Alla rutter"
    }

    func recenterMap() {
        recenterToken += 1
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
            if seedsDemoFavorites {
                for run in runs.prefix(2) where !favoriteIDs.contains(run.id) {
                    try favorites.setMarked(true, workoutID: run.id)
                    favoriteIDs.insert(run.id)
                }
            }
            photos = loadedPhotos
            if let focusedRunID, !runs.contains(where: { $0.id == focusedRunID }) {
                self.focusedRunID = nil
            }
            chosenRunIDs.formIntersection(runs.map(\.id))
            if !didSeedFilterDates, let earliest = runs.map(\.startDate).min(), let latest = runs.map(\.startDate).max() {
                filter.startDate = earliest
                filter.endDate = latest
                didSeedFilterDates = true
            }
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

    func focus(_ run: RunWorkout) {
        focusedRunID = run.id
        showsSelectionSummary = false
    }

    func clearFocus() {
        focusedRunID = nil
    }

    func beginSelection() {
        isSelecting = true
        showsSelectionSummary = false
        focusedRunID = nil
    }

    func endSelection() {
        isSelecting = false
    }

    func toggleChosen(_ run: RunWorkout) {
        if chosenRunIDs.contains(run.id) {
            chosenRunIDs.remove(run.id)
        } else {
            chosenRunIDs.insert(run.id)
        }
    }

    func handleMapTap(_ coordinate: RouteCoordinate) {
        guard !showsSelectionSummary else { return }
        guard let id = RouteGeometry.nearestRunID(to: coordinate, runs: mapRuns, within: 500),
              let run = mapRuns.first(where: { $0.id == id }) else { return }
        if isSelecting {
            toggleChosen(run)
        } else {
            focus(run)
        }
    }

    func showSummary() {
        guard !chosenRunIDs.isEmpty else { return }
        showsSelectionSummary = true
        isSelecting = false
        focusedRunID = nil
    }

    func applySelectedOnlyFilter() {
        filter.selectedOnly = true
        showsSelectionSummary = false
        isSelecting = false
        focusedRunID = nil
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
    enum MapDrawMode: String {
        case routes
        case heatmap
    }


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
