import CoreGraphics
import XCTest
@testable import Trails

final class RouteGeometryTests: XCTestCase {
    func testHaversineOfOneDegreeLatitude() {
        let start = RouteCoordinate(latitude: 0, longitude: 0)
        let end = RouteCoordinate(latitude: 1, longitude: 0)
        let expected = RouteGeometry.earthRadiusMeters * .pi / 180
        XCTAssertEqual(RouteGeometry.distanceMeters(from: [start, end]), expected, accuracy: 0.01)
    }

    func testDistanceOfIdenticalPointsIsZero() {
        let point = RouteCoordinate(latitude: 59.33, longitude: 18.07)
        XCTAssertEqual(RouteGeometry.distanceMeters(from: [point, point]), 0, accuracy: 0.001)
        XCTAssertEqual(RouteGeometry.distanceMeters(from: [point]), 0, accuracy: 0.001)
    }

    func testLoopClosesAndHasLength() {
        let loop = RouteGeometry.loop(centerLatitude: 59.33, centerLongitude: 18.07, radiusMeters: 500)
        XCTAssertGreaterThanOrEqual(loop.count, 3)
        XCTAssertEqual(loop.first, loop.last)
        XCTAssertGreaterThan(RouteGeometry.distanceMeters(from: loop), 1_000)
    }

    func testRegionCenterSitsInsideTheRoute() {
        let coordinates = RouteGeometry.outAndBack(startLatitude: 59.3, startLongitude: 18.16, lengthMeters: 2_000)
        let region = RouteGeometry.region(for: coordinates)
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        XCTAssertGreaterThanOrEqual(region.center.latitude, latitudes.min() ?? 0)
        XCTAssertLessThanOrEqual(region.center.latitude, latitudes.max() ?? 0)
        XCTAssertGreaterThanOrEqual(region.center.longitude, longitudes.min() ?? 0)
        XCTAssertLessThanOrEqual(region.center.longitude, longitudes.max() ?? 0)
        XCTAssertGreaterThan(region.span.latitudeDelta, 0)
        XCTAssertGreaterThan(region.span.longitudeDelta, 0)
    }

    func testNormalizedPointsStayInsideTheCanvas() {
        let coordinates = RouteGeometry.loop(centerLatitude: 59.32, centerLongitude: 18.10, radiusMeters: 800)
        let size = CGSize(width: 56, height: 56)
        let points = RouteGeometry.normalized(coordinates, in: size, padding: 8)
        XCTAssertEqual(points.count, coordinates.count)
        for point in points {
            XCTAssertGreaterThanOrEqual(point.x, 0)
            XCTAssertLessThanOrEqual(point.x, size.width)
            XCTAssertGreaterThanOrEqual(point.y, 0)
            XCTAssertLessThanOrEqual(point.y, size.height)
        }
    }
}
