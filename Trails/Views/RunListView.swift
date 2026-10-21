import SwiftUI

struct RunListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading && model.runs.isEmpty {
                    ProgressView("Hämtar rundor…")
                } else if model.runs.isEmpty {
                    ContentUnavailableView {
                        Label("Inga rundor", systemImage: "map")
                    } description: {
                        Text(model.statusMessage ?? "Löppass med GPS-rutt visas här.")
                    } actions: {
                        Button("Försök igen") {
                            Task { await model.reload() }
                        }
                    }
                } else {
                    List(model.runs) { run in
                        NavigationLink(value: run) {
                            RunRow(run: run, isFavorite: model.isFavorite(run)) {
                                model.toggleFavorite(run)
                            }
                        }
                        .accessibilityIdentifier("run-\(run.title)")
                    }
                    .listStyle(.insetGrouped)
                    .accessibilityIdentifier("run-list")
                }
            }
            .navigationTitle("Trackin' Trails")
            .navigationDestination(for: RunWorkout.self) { run in
                RunDetailView(run: run)
            }
            .refreshable {
                await model.reload()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if model.isLoading {
                        ProgressView()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Källa", selection: sourceBinding) {
                            ForEach(AppModel.DataSourceKind.allCases) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                    } label: {
                        Label(model.dataSource.title, systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                if let statusMessage = model.statusMessage, !model.runs.isEmpty {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(.bar)
                }
            }
        }
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

struct RunRow: View {
    let run: RunWorkout
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RouteBadge(coordinates: run.coordinates)
            VStack(alignment: .leading, spacing: 4) {
                Text(run.title)
                    .font(.headline)
                Text(RunFormatting.dateTime(run.startDate))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(RunFormatting.distance(run.distanceMeters)) · \(RunFormatting.duration(run.duration))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isFavorite ? TrailTheme.clay : Color.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isFavorite ? "Ta bort markering" : "Markera rutt")
        }
        .padding(.vertical, 4)
    }
}

#Preview("Lista") {
    RunListView()
        .environment(AppModel.preview())
}
