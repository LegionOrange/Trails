import SwiftUI

enum SheetPage: String, CaseIterable, Identifiable {
    case routes
    case filter
    case statistics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .routes: "Rutter"
        case .filter: "Filter"
        case .statistics: "Statistik"
        }
    }

    var symbol: String {
        switch self {
        case .routes: "map"
        case .filter: "line.3.horizontal.decrease"
        case .statistics: "chart.bar.xaxis"
        }
    }

    var accessibilityID: String {
        switch self {
        case .routes: "tab-rutter"
        case .filter: "tab-filter"
        case .statistics: "tab-statistik"
        }
    }
}

struct RouteSheet: View {
    @Environment(AppModel.self) private var model
    @Binding var page: SheetPage
    @Binding var detent: PresentationDetent
    @State private var selectedPhoto: WorkoutPhoto?

    var body: some View {
        pageContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 12)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("sheet")
            .sheet(item: $selectedPhoto) { photo in
                PhotoDetailView(photo: photo)
            }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case .routes:
            if model.showsSelectionSummary {
                summaryPage
            } else if let run = model.focusedRun {
                detailPage(run)
            } else {
                routesPage
            }
        case .filter:
            filterPage
        case .statistics:
            statisticsPage
        }
    }

    private var routesPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sheetTitle(model.isSelecting ? "Välj rutter" : "Rutter", count: model.visibleRuns.count)
                if let statusMessage = model.statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if model.visibleRuns.isEmpty {
                    ContentUnavailableView(
                        "Inga rutter",
                        systemImage: "map",
                        description: Text("Inga rutter matchar filtret.")
                    )
                    .frame(height: 220)
                } else {
                    ForEach(model.visibleRuns) { run in
                        routeRow(run)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("routes-list")
    }

    private func routeRow(_ run: RunWorkout) -> some View {
        HStack(spacing: 12) {
            if model.isSelecting {
                Image(systemName: model.chosenRunIDs.contains(run.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(model.chosenRunIDs.contains(run.id) ? TrailTheme.accent : Color.secondary)
            }
            Button {
                if model.isSelecting {
                    model.toggleChosen(run)
                } else {
                    model.focus(run)
                    detent = RootView.largeDetent
                }
            } label: {
                HStack(spacing: 12) {
                    RouteBadge(coordinates: run.coordinates)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(run.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(RunFormatting.dateTime(run.startDate))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(RunFormatting.distance(run.distanceMeters)) · \(RunFormatting.duration(run.duration))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(model.isSelecting ? "choose-\(run.title)" : "run-\(run.title)")

            Button {
                model.toggleFavorite(run)
            } label: {
                Image(systemName: model.isFavorite(run) ? "star.fill" : "star")
                    .foregroundStyle(model.isFavorite(run) ? TrailTheme.clay : Color.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(model.isFavorite(run) ? "Ta bort markering" : "Markera rutt")
        }
        .padding(.vertical, 6)
    }

    private func detailPage(_ run: RunWorkout) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    model.clearFocus()
                    detent = .medium
                } label: {
                    Label("Rutter", systemImage: "chevron.left")
                        .font(.body.weight(.semibold))
                }
                .accessibilityIdentifier("detail-back")

                Text(run.title)
                    .font(.largeTitle.bold())
                Text(RunFormatting.dateTime(run.startDate))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                photoSection(for: run)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    statTile("Distans", RunFormatting.distance(run.distanceMeters))
                    statTile("Tid", RunFormatting.duration(run.duration))
                    statTile("Tempo", paceText(for: run))
                }

                Button {
                    model.toggleFavorite(run)
                } label: {
                    Label(
                        model.isFavorite(run) ? "Ta bort markering" : "Markera rutt",
                        systemImage: model.isFavorite(run) ? "star.fill" : "star"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(model.isFavorite(run) ? TrailTheme.clay : TrailTheme.accent)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("route-detail")
    }

    private func photoSection(for run: RunWorkout) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Foton från passet")
                .font(.title3.weight(.semibold))
            let photos = model.photos(for: run)
            if photos.isEmpty {
                Text(model.dataSource == .sample
                    ? "Inga exempelbilder för det här passet."
                    : "Inga foton hittades mellan start och mål. Tillåt åtkomst till bilder om appen ska söka i biblioteket.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                            Button {
                                selectedPhoto = photo
                            } label: {
                                Image(uiImage: photo.thumbnail)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 112, height: 112)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("photo-\(index)")
                            .accessibilityLabel("Foto från \(RunFormatting.dateTime(photo.capturedAt))")
                        }
                    }
                }
            }
        }
    }

    private var filterPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sheetTitle("Filter", count: nil)
                Text("\(model.visibleRuns.count) rutter visas på kartan")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Toggle("Endast markerade", isOn: binding(\.markedOnly))
                    .accessibilityIdentifier("filter-marked")
                Toggle("Visa endast valda", isOn: binding(\.selectedOnly))
                    .disabled(model.chosenRunIDs.isEmpty && !model.filter.selectedOnly)
                    .accessibilityIdentifier("filter-selected")
                if model.chosenRunIDs.isEmpty {
                    Text("Välj rutter med Välj för att kunna filtrera på urvalet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Toggle("Datumintervall", isOn: binding(\.usesDateRange))
                    .accessibilityIdentifier("filter-dates")
                if model.filter.usesDateRange {
                    DatePicker("Från", selection: binding(\.startDate), displayedComponents: .date)
                    DatePicker("Till", selection: binding(\.endDate), displayedComponents: .date)
                }

                Toggle("Distans", isOn: binding(\.usesDistanceRange))
                    .accessibilityIdentifier("filter-distance")
                if model.filter.usesDistanceRange {
                    Text("Minst \(RunFormatting.distance(model.filter.minimumKilometers * 1_000))")
                        .font(.subheadline)
                    Slider(value: minimumDistance, in: 0...40, step: 0.5)
                    Text("Högst \(RunFormatting.distance(model.filter.maximumKilometers * 1_000))")
                        .font(.subheadline)
                    Slider(value: maximumDistance, in: 0...40, step: 0.5)
                }

                Picker("Källa", selection: sourceBinding) {
                    ForEach(AppModel.DataSourceKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("source-picker")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("filter-screen")
    }

    private var statisticsPage: some View {
        let stats = model.statistics
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sheetTitle("Statistik", count: nil)
                Text("Baserat på rutterna som filtret visar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statTile("Antal", "\(stats.count)")
                    statTile("Total distans", RunFormatting.distance(stats.totalDistanceMeters))
                    statTile("Total tid", RunFormatting.duration(stats.totalDuration))
                    statTile("Snittempo", stats.averagePaceSecondsPerKilometer.map(RunFormatting.pace) ?? "–")
                    statTile("Snittdistans", RunFormatting.distance(stats.averageDistanceMeters))
                    statTile("Markerade", "\(model.visibleRuns.filter { model.isFavorite($0) }.count)")
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stats-screen")
    }

    private var summaryPage: some View {
        let stats = model.selectionStatistics
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sammanfattning")
                    .font(.largeTitle.bold())
                Text("\(stats.count) valda rutter")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statTile("Total distans", RunFormatting.distance(stats.totalDistanceMeters))
                    statTile("Total tid", RunFormatting.duration(stats.totalDuration))
                    statTile("Snittempo", stats.averagePaceSecondsPerKilometer.map(RunFormatting.pace) ?? "–")
                    statTile("Snittdistans", RunFormatting.distance(stats.averageDistanceMeters))
                }
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(model.chosenRuns) { run in
                        Text(run.title)
                            .font(.body.weight(.semibold))
                    }
                }
                Button("Visa endast valda") {
                    model.applySelectedOnlyFilter()
                    page = .routes
                    detent = .medium
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("apply-selected-filter")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("summary-screen")
    }

    private func sheetTitle(_ title: String, count: Int?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.largeTitle.bold())
            Spacer()
            if let count {
                Text("\(count)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statTile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func paceText(for run: RunWorkout) -> String {
        guard run.distanceMeters >= 1 else { return "–" }
        return RunFormatting.pace(run.duration / (run.distanceMeters / 1_000))
    }

    private func binding(_ keyPath: WritableKeyPath<RouteFilter, Bool>) -> Binding<Bool> {
        Binding(
            get: { model.filter[keyPath: keyPath] },
            set: { model.filter[keyPath: keyPath] = $0 }
        )
    }

    private func binding(_ keyPath: WritableKeyPath<RouteFilter, Date>) -> Binding<Date> {
        Binding(
            get: { model.filter[keyPath: keyPath] },
            set: { model.filter[keyPath: keyPath] = $0 }
        )
    }

    private var minimumDistance: Binding<Double> {
        Binding(
            get: { model.filter.minimumKilometers },
            set: { model.filter.minimumKilometers = min($0, model.filter.maximumKilometers) }
        )
    }

    private var maximumDistance: Binding<Double> {
        Binding(
            get: { model.filter.maximumKilometers },
            set: { model.filter.maximumKilometers = max($0, model.filter.minimumKilometers) }
        )
    }

    private var sourceBinding: Binding<AppModel.DataSourceKind> {
        Binding(
            get: { model.dataSource },
            set: { kind in
                Task { await model.setDataSource(kind) }
            }
        )
    }
}

struct PhotoDetailView: View {
    let photo: WorkoutPhoto
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Image(uiImage: photo.fullImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .accessibilityIdentifier("photo-detail")
                .accessibilityLabel("Exempelfoto")
                .navigationTitle(RunFormatting.dateTime(photo.capturedAt))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Stäng") { dismiss() }
                    }
                }
        }
    }
}
