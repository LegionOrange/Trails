import XCTest
@testable import Trails

final class RunFormattingTests: XCTestCase {
    func testDistanceUsesKilometersPastOneThousandMeters() {
        let long = RunFormatting.distance(10_000)
        XCTAssertTrue(long.contains("10"))
        XCTAssertTrue(long.contains("km"))

        let short = RunFormatting.distance(850)
        XCTAssertTrue(short.contains("850"))
        XCTAssertTrue(short.contains("m"))
        XCTAssertFalse(short.contains("km"))
    }

    func testDurationFormatting() {
        XCTAssertEqual(RunFormatting.duration(0), "0:00")
        XCTAssertEqual(RunFormatting.duration(59), "0:59")
        XCTAssertEqual(RunFormatting.duration(125), "2:05")
        XCTAssertEqual(RunFormatting.duration(3_661), "1:01:01")
    }

    func testStockholmDateFormattingIncludesTheYear() {
        let date = SampleWorkoutSource.stockholmDate(year: 2026, month: 10, day: 18, hour: 9, minute: 15)
        XCTAssertTrue(RunFormatting.dateTime(date).contains("2026"))
        XCTAssertTrue(RunFormatting.date(date).contains("2026"))
    }

    func testPhotoWindowIncludesEndpoints() {
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 2_000)
        XCTAssertTrue(PhotoWindow.contains(start, start: start, end: end))
        XCTAssertTrue(PhotoWindow.contains(end, start: start, end: end))
        XCTAssertTrue(PhotoWindow.contains(start.addingTimeInterval(10), start: start, end: end))
        XCTAssertFalse(PhotoWindow.contains(start.addingTimeInterval(-1), start: start, end: end))
        XCTAssertFalse(PhotoWindow.contains(end.addingTimeInterval(1), start: start, end: end))
    }
}
