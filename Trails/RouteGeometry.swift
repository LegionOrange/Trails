import CoreGraphics
import MapKit

enum RouteGeometry {
    static let earthRadiusMeters = 6_371_000.0

    static func distanceMeters(from coordinates: [RouteCoordinate]) -> Double {
        guard coordinates.count >= 2 else { return 0 }
        return zip(coordinates, coordinates.dropFirst()).reduce(0) { partial, pair in
            partial + haversine(pair.0, pair.1)
        }
    }

    static func haversine(_ start: RouteCoordinate, _ end: RouteCoordinate) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let dLat = (end.latitude - start.latitude) * .pi / 180
        let dLon = (end.longitude - start.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadiusMeters * asin(min(1, sqrt(h)))
    }

    static func project(latitude: Double, longitude: Double, northMeters: Double, eastMeters: Double) -> RouteCoordinate {
        let lat = latitude + northMeters / 111_320
        let lon = longitude + eastMeters / (111_320 * cos(latitude * .pi / 180))
        return RouteCoordinate(latitude: lat, longitude: lon)
    }

    static func loop(centerLatitude: Double, centerLongitude: Double, radiusMeters: Double, points: Int = 72) -> [RouteCoordinate] {
        let count = max(points, 8)
        var coordinates: [RouteCoordinate] = []
        coordinates.reserveCapacity(count + 1)
        for index in 0..<count {
            let angle = Double(index) / Double(count) * 2 * .pi
            let wobble = 1 + 0.16 * sin(angle * 3) + 0.06 * cos(angle * 5)
            let north = radiusMeters * wobble * cos(angle)
            let east = radiusMeters * wobble * 0.78 * sin(angle)
            coordinates.append(project(
                latitude: centerLatitude,
                longitude: centerLongitude,
                northMeters: north,
                eastMeters: east
            ))
        }
        if let first = coordinates.first {
            coordinates.append(first)
        }
        return coordinates
    }

    static func outAndBack(startLatitude: Double, startLongitude: Double, lengthMeters: Double, points: Int = 48) -> [RouteCoordinate] {
        let half = max(points / 2, 4)
        var coordinates: [RouteCoordinate] = []
        for index in 0...half {
            let progress = Double(index) / Double(half)
            let north = lengthMeters * progress
            let east = 90 * sin(progress * .pi * 2.5)
            coordinates.append(project(
                latitude: startLatitude,
                longitude: startLongitude,
                northMeters: north,
                eastMeters: east
            ))
        }
        for index in stride(from: half - 1, through: 0, by: -1) {
            let progress = Double(index) / Double(half)
            let north = lengthMeters * progress
            let east = 90 * sin(progress * .pi * 2.5) + 22
            coordinates.append(project(
                latitude: startLatitude,
                longitude: startLongitude,
                northMeters: north,
                eastMeters: east
            ))
        }
        return coordinates
    }

    static func region(for coordinates: [RouteCoordinate]) -> MKCoordinateRegion {
        guard let first = coordinates.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            )
        }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for coordinate in coordinates.dropFirst() {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let latDelta = max((maxLat - minLat) * 1.45, 0.006)
        let lonDelta = max((maxLon - minLon) * 1.45, 0.006)
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }

    static func nearestRunID(to coordinate: RouteCoordinate, runs: [RunWorkout], within meters: Double) -> UUID? {
        var bestID: UUID?
        var bestDistance = meters
        for run in runs {
            let distance = distance(from: coordinate, toRoute: run.coordinates)
            if distance <= bestDistance {
                bestDistance = distance
                bestID = run.id
            }
        }
        return bestID
    }

    static func distance(from point: RouteCoordinate, toRoute route: [RouteCoordinate]) -> Double {
        guard let first = route.first else { return .greatestFiniteMagnitude }
        guard route.count >= 2 else { return haversine(point, first) }
        var best = Double.greatestFiniteMagnitude
        for index in route.indices.dropLast() {
            best = min(best, distanceToSegment(point, route[index], route[index + 1]))
        }
        return best
    }

    private static func distanceToSegment(_ point: RouteCoordinate, _ start: RouteCoordinate, _ end: RouteCoordinate) -> Double {
        let north = metersNorth(from: start, to: end)
        let east = metersEast(from: start, to: end)
        let lengthSquared = north * north + east * east
        if lengthSquared < 0.01 { return haversine(point, start) }
        let pointNorth = metersNorth(from: start, to: point)
        let pointEast = metersEast(from: start, to: point)
        let progress = min(1, max(0, (pointNorth * north + pointEast * east) / lengthSquared))
        let closest = project(
            latitude: start.latitude,
            longitude: start.longitude,
            northMeters: north * progress,
            eastMeters: east * progress
        )
        return haversine(point, closest)
    }

    private static func metersNorth(from start: RouteCoordinate, to end: RouteCoordinate) -> Double {
        (end.latitude - start.latitude) * 111_320
    }

    private static func metersEast(from start: RouteCoordinate, to end: RouteCoordinate) -> Double {
        (end.longitude - start.longitude) * 111_320 * cos(start.latitude * .pi / 180)
    }

    static func normalized(_ coordinates: [RouteCoordinate], in size: CGSize, padding: CGFloat = 6) -> [CGPoint] {
        guard let first = coordinates.first, size.width > padding * 2, size.height > padding * 2 else {
            return []
        }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        let latSpan = max(maxLat - minLat, 0.000_01)
        let lonSpan = max(maxLon - minLon, 0.000_01)
        let width = size.width - padding * 2
        let height = size.height - padding * 2
        return coordinates.map { coordinate in
            CGPoint(
                x: padding + CGFloat((coordinate.longitude - minLon) / lonSpan) * width,
                y: padding + CGFloat((maxLat - coordinate.latitude) / latSpan) * height
            )
        }
    }
}
