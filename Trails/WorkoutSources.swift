import CoreLocation
import Foundation
import HealthKit

protocol WorkoutSource {
    func prepare() async throws
    func loadRuns() async throws -> [RunWorkout]
}

enum WorkoutSourceError: LocalizedError {
    case healthUnavailable

    var errorDescription: String? {
        switch self {
        case .healthUnavailable:
            "Hälsa är inte tillgängligt på den här enheten."
        }
    }
}

struct SampleWorkoutSource: WorkoutSource {
    func prepare() async throws {}

    func loadRuns() async throws -> [RunWorkout] {
        Self.runs
    }

    static let runs: [RunWorkout] = [
        make(
            id: "A6B1C2D3-4E5F-4678-9ABC-DEF012345678",
            title: "Nackareservatet",
            year: 2026, month: 10, day: 18, hour: 9, minute: 15,
            paceSecondsPerKilometer: 355,
            coordinates: RouteGeometry.outAndBack(
                startLatitude: 59.2965,
                startLongitude: 18.1630,
                lengthMeters: 4_200
            )
        ),
        make(
            id: "B7C2D3E4-5F60-4789-ABCD-EF0123456789",
            title: "Djurgården",
            year: 2026, month: 10, day: 12, hour: 8, minute: 40,
            paceSecondsPerKilometer: 325,
            coordinates: RouteGeometry.loop(
                centerLatitude: 59.3260,
                centerLongitude: 18.1180,
                radiusMeters: 1_450
            )
        ),
        make(
            id: "C8D3E4F5-6071-489A-BCDE-F01234567890",
            title: "Södermalm",
            year: 2026, month: 10, day: 4, hour: 17, minute: 5,
            paceSecondsPerKilometer: 315,
            coordinates: RouteGeometry.loop(
                centerLatitude: 59.3155,
                centerLongitude: 18.0710,
                radiusMeters: 900,
                points: 64
            )
        ),
        make(
            id: "D9E4F506-7182-49AB-8DEF-012345678901",
            title: "Hagaparken",
            year: 2026, month: 9, day: 27, hour: 10, minute: 0,
            paceSecondsPerKilometer: 340,
            coordinates: RouteGeometry.loop(
                centerLatitude: 59.3625,
                centerLongitude: 18.0330,
                radiusMeters: 780,
                points: 60
            )
        )
    ]

    static func stockholmDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm") ?? .current
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    private static func make(
        id: String,
        title: String,
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        paceSecondsPerKilometer: Double,
        coordinates: [RouteCoordinate]
    ) -> RunWorkout {
        let start = stockholmDate(year: year, month: month, day: day, hour: hour, minute: minute)
        let distance = RouteGeometry.distanceMeters(from: coordinates)
        let duration = (distance / 1_000) * paceSecondsPerKilometer
        return RunWorkout(
            id: UUID(uuidString: id) ?? UUID(),
            title: title,
            startDate: start,
            endDate: start.addingTimeInterval(duration),
            distanceMeters: distance,
            coordinates: coordinates
        )
    }
}

final class HealthKitWorkoutSource: WorkoutSource {
    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private let store = HKHealthStore()

    func prepare() async throws {
        guard Self.isAvailable else { throw WorkoutSourceError.healthUnavailable }
        let readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func loadRuns() async throws -> [RunWorkout] {
        let workouts = try await fetchWorkouts()
        var runs: [RunWorkout] = []
        for workout in workouts {
            let coordinates = try await routeCoordinates(for: workout)
            guard coordinates.count >= 2 else { continue }
            let meters = workout.totalDistance?.doubleValue(for: .meter())
                ?? RouteGeometry.distanceMeters(from: coordinates)
            let title = workout.workoutActivityType == .trailRunning ? "Terränglöpning" : "Löpning"
            runs.append(RunWorkout(
                id: workout.uuid,
                title: title,
                startDate: workout.startDate,
                endDate: workout.endDate,
                distanceMeters: meters,
                coordinates: coordinates
            ))
        }
        return runs
    }

    private func fetchWorkouts() async throws -> [HKWorkout] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                HKQuery.predicateForWorkouts(with: .running),
                HKQuery.predicateForWorkouts(with: .trailRunning)
            ])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 40,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
    }

    private func routeCoordinates(for workout: HKWorkout) async throws -> [RouteCoordinate] {
        let routes = try await fetchRoutes(for: workout)
        var coordinates: [RouteCoordinate] = []
        for route in routes {
            let locations = try await locations(for: route)
            for location in locations {
                let coordinate = location.coordinate
                guard CLLocationCoordinate2DIsValid(coordinate) else { continue }
                let nearNullIsland = abs(coordinate.latitude) < 0.01 && abs(coordinate.longitude) < 0.01
                if nearNullIsland { continue }
                coordinates.append(RouteCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude))
            }
        }
        return coordinates
    }

    private func fetchRoutes(for workout: HKWorkout) async throws -> [HKWorkoutRoute] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKSeriesType.workoutRoute(),
                predicate: HKQuery.predicateForObjects(from: workout),
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }
            store.execute(query)
        }
    }

    /// `HKWorkoutRouteQuery` delivers locations in several batches and then sets `done`.
    private func locations(for route: HKWorkoutRoute) async throws -> [CLLocation] {
        let accumulator = LocationAccumulator()
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKWorkoutRouteQuery(route: route) { _, batch, done, error in
                accumulator.handle(batch: batch, done: done, error: error, continuation: continuation)
            }
            store.execute(query)
        }
    }
}

private final class LocationAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var locations: [CLLocation] = []
    private var resumed = false

    func handle(
        batch: [CLLocation]?,
        done: Bool,
        error: Error?,
        continuation: CheckedContinuation<[CLLocation], Error>
    ) {
        lock.lock()
        if let batch {
            locations.append(contentsOf: batch)
        }
        let shouldResume = !resumed && (done || error != nil)
        if shouldResume {
            resumed = true
        }
        let snapshot = locations
        lock.unlock()

        guard shouldResume else { return }
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume(returning: snapshot)
        }
    }
}
