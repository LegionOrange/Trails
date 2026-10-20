import CoreLocation
import SwiftData
import UIKit

struct RouteCoordinate: Hashable, Sendable {
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct RunWorkout: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let startDate: Date
    let endDate: Date
    let distanceMeters: Double
    let coordinates: [RouteCoordinate]

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}

struct WorkoutPhoto: Identifiable {
    let id: String
    let capturedAt: Date
    let thumbnail: UIImage
    let fullImage: UIImage
}

@Model
final class FavoriteMark {
    @Attribute(.unique) var workoutID: String
    var createdAt: Date

    init(workoutID: String, createdAt: Date = .now) {
        self.workoutID = workoutID
        self.createdAt = createdAt
    }
}
