import SwiftUI

struct FavoritesOverviewView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading && model.runs.isEmpty {
                    ProgressView("Hämtar rundor…")
                } else if model.markedRuns.isEmpty {
                    ContentUnavailableView(
                        "Inga markerade rutter",
                        systemImage: "star",
                        description: Text("Markera en runda med stjärnan. Alla markerade rutter samlas här, på en karta och i en lista.")
                    )
                } else {
                    List {
                        Section {
                            RouteMapView(routes: overviewRoutes)
                                .frame(height: 340)
                                .listRowInsets(EdgeInsets())
                        }
                        Section("Markerade rundor") {
                            ForEach(Array(model.markedRuns.enumerated()), id: \.element.id) { index, run in
                                NavigationLink(value: run) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Circle()
                                                .fill(TrailTheme.routeColor(at: index))
                                                .frame(width: 10, height: 10)
                                            Text(run.title)
                                                .font(.headline)
                                        }
                                        Text(RunFormatting.dateTime(run.startDate))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Text("\(RunFormatting.distance(run.distanceMeters)) · \(RunFormatting.duration(run.duration))")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Markerade")
            .navigationDestination(for: RunWorkout.self) { run in
                RunDetailView(run: run)
            }
        }
    }

    private var overviewRoutes: [MapRoute] {
        model.markedRuns.enumerated().map { index, run in
            MapRoute(
                id: run.id,
                coordinates: run.coordinates,
                color: TrailTheme.routeColor(at: index),
                showEndpoints: false
            )
        }
    }
}

#Preview("Markerade") {
    FavoritesOverviewView()
        .environment(AppModel.preview())
}
