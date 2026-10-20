import XCTest
@testable import Trails

@MainActor
final class SampleDataTests: XCTestCase {
    func testSampleRunsAreRoutesAroundStockholm() {
        let runs = SampleWorkoutSource.runs
        XCTAssertGreaterThanOrEqual(runs.count, 3)
        XCTAssertEqual(Set(runs.map(\.id)).count, runs.count)
        XCTAssertEqual(runs.map(\.startDate), runs.map(\.startDate).sorted(by: >))

        for run in runs {
            XCTAssertGreaterThanOrEqual(run.coordinates.count, 2)
            XCTAssertLessThan(run.startDate, run.endDate)
            XCTAssertGreaterThan(run.distanceMeters, 1_000)
            XCTAssertEqual(run.distanceMeters, RouteGeometry.distanceMeters(from: run.coordinates), accuracy: 0.01)
            XCTAssertGreaterThan(run.duration, 60)
            for coordinate in run.coordinates {
                XCTAssertTrue((55...69).contains(coordinate.latitude))
                XCTAssertTrue((10...25).contains(coordinate.longitude))
            }
        }
    }

    func testSamplePhotosFallInsideTheWorkout() {
        let runs = SampleWorkoutSource.runs
        let photos = SamplePhotoSource.makePhotos(for: runs)
        XCTAssertEqual(photos.count, runs.count)
        for run in runs {
            let runPhotos = photos[run.id] ?? []
            XCTAssertGreaterThanOrEqual(runPhotos.count, 2)
            for photo in runPhotos {
                XCTAssertGreaterThan(photo.thumbnail.size.width, 0)
                XCTAssertGreaterThan(photo.thumbnail.size.height, 0)
                XCTAssertTrue(PhotoWindow.contains(photo.capturedAt, start: run.startDate, end: run.endDate))
            }
        }
    }
}
