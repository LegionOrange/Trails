import XCTest
@testable import Trails

final class RouteQueryTests: XCTestCase {
    func testMarkedAndSelectedFilters() {
        let runs = SampleWorkoutSource.runs
        var filter = RouteFilter()
        filter.markedOnly = true
        let marked = runs.filter { filter.allows($0, isMarked: $0.title == "Nackareservatet", isChosen: true) }
        XCTAssertEqual(marked.map(\.title), ["Nackareservatet"])

        filter.markedOnly = false
        filter.selectedOnly = true
        let chosen = runs.filter { filter.allows($0, isMarked: false, isChosen: $0.title == "Djurgården") }
        XCTAssertEqual(chosen.map(\.title), ["Djurgården"])
    }

    func testDateRangeCoversTheWholeStockholmDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm") ?? .current
        let nacka = SampleWorkoutSource.runs[0]
        var filter = RouteFilter()
        filter.usesDateRange = true
        filter.startDate = nacka.startDate
        filter.endDate = nacka.startDate

        XCTAssertTrue(filter.allows(nacka, isMarked: false, isChosen: false, calendar: calendar))
        let earlier = SampleWorkoutSource.runs[1]
        XCTAssertFalse(filter.allows(earlier, isMarked: false, isChosen: false, calendar: calendar))
    }

    func testDistanceRangeIsInclusive() {
        let run = SampleWorkoutSource.runs[0]
        var filter = RouteFilter()
        filter.usesDistanceRange = true
        filter.minimumKilometers = 0
        filter.maximumKilometers = 0.5
        XCTAssertFalse(filter.allows(run, isMarked: false, isChosen: false))

        filter.maximumKilometers = 40
        XCTAssertTrue(filter.allows(run, isMarked: false, isChosen: false))
    }

    func testStatisticsAndPace() {
        let runs = SampleWorkoutSource.runs
        let stats = RouteStatistics.summarize(runs)
        XCTAssertEqual(stats.count, 4)
        XCTAssertEqual(stats.totalDistanceMeters, runs.reduce(0) { $0 + $1.distanceMeters }, accuracy: 0.01)
        XCTAssertEqual(stats.totalDuration, runs.reduce(0) { $0 + $1.duration }, accuracy: 0.01)
        XCTAssertEqual(stats.averageDistanceMeters, stats.totalDistanceMeters / 4, accuracy: 0.01)
        XCTAssertNotNil(stats.averagePaceSecondsPerKilometer)

        let empty = RouteStatistics.summarize([])
        XCTAssertEqual(empty.count, 0)
        XCTAssertEqual(empty.averageDistanceMeters, 0)
        XCTAssertNil(empty.averagePaceSecondsPerKilometer)
        XCTAssertEqual(RunFormatting.pace(355), "5:55 /km")
        XCTAssertEqual(RunFormatting.pace(90), "1:30 /km")
    }

    func testNearestRunMatchesTheRouteUnderTheTap() {
        let runs = SampleWorkoutSource.runs
        let nacka = runs[0]
        let onRoute = nacka.coordinates[nacka.coordinates.count / 2]
        XCTAssertEqual(RouteGeometry.nearestRunID(to: onRoute, runs: runs, within: 500), nacka.id)
        XCTAssertNil(RouteGeometry.nearestRunID(to: RouteCoordinate(latitude: 0, longitude: 0), runs: runs, within: 500))
    }
}

@MainActor
final class SelectionModelTests: XCTestCase {
    func testMapTapFocusesThenTogglesTheSameRoute() {
        let model = AppModel.preview(markedFirst: false)
        let run = model.runs[0]
        let point = run.coordinates[run.coordinates.count / 2]

        model.handleMapTap(point)
        XCTAssertEqual(model.focusedRunID, run.id)
        XCTAssertEqual(model.mapRuns.count, model.runs.count)

        model.beginSelection()
        XCTAssertNil(model.focusedRunID)
        XCTAssertTrue(model.isSelecting)

        model.handleMapTap(point)
        XCTAssertEqual(model.chosenRunIDs, [run.id])
        model.handleMapTap(point)
        XCTAssertTrue(model.chosenRunIDs.isEmpty)
    }

    func testSummaryShowsChosenRoutesAndCanBecomeTheFilter() {
        let model = AppModel.preview()
        let first = model.runs[0]
        let second = model.runs[1]
        model.beginSelection()
        model.toggleChosen(first)
        model.toggleChosen(second)
        model.showSummary()

        XCTAssertFalse(model.isSelecting)
        XCTAssertTrue(model.showsSelectionSummary)
        XCTAssertEqual(model.mapRuns.map(\.id), [first.id, second.id])
        XCTAssertEqual(model.selectionStatistics.count, 2)

        model.handleMapTap(first.coordinates[0])
        XCTAssertEqual(model.chosenRunIDs, [first.id, second.id])

        model.applySelectedOnlyFilter()
        XCTAssertFalse(model.showsSelectionSummary)
        XCTAssertTrue(model.filter.selectedOnly)
        XCTAssertEqual(model.visibleRuns.map(\.id), [first.id, second.id])
        XCTAssertEqual(model.statistics.count, 2)
        XCTAssertEqual(model.mapRuns.map(\.id), [first.id, second.id])
    }
}
