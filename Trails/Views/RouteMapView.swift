import MapKit
import SwiftUI

enum MapSheetCover: Equatable {
    case small
    case medium
    case large

    func height(in total: CGFloat) -> CGFloat {
        switch self {
        case .small: 210
        case .medium: total * 0.5
        case .large: total * 0.80
        }
    }
}

struct TrailsMap: View {
    let runs: [RunWorkout]
    let focusedID: UUID?
    let chosenIDs: Set<UUID>
    let isSelecting: Bool
    let showsSummary: Bool
    let sheetCover: MapSheetCover
    var onTap: (RouteCoordinate) -> Void

    @State private var camera: MapCameraPosition = .region(RouteGeometry.region(for: []))

    var body: some View {
        GeometryReader { proxy in
            let visible = visibleFraction(in: proxy.size.height)
            MapReader { mapProxy in
                Map(position: $camera) {
                    ForEach(runs) { run in
                        let style = emphasis(for: run)
                        if run.coordinates.count >= 2 {
                            MapPolyline(coordinates: run.coordinates.map(\.coordinate))
                                .stroke(
                                    color(for: run).opacity(style.opacity),
                                    style: StrokeStyle(lineWidth: style.width, lineCap: .round, lineJoin: .round)
                                )
                        }
                        if focusedID == run.id, let start = run.coordinates.first?.coordinate {
                            Marker(run.title, systemImage: "figure.run", coordinate: start)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .mapControlVisibility(.hidden)
                .simultaneousGesture(
                    SpatialTapGesture().onEnded { value in
                        guard let coordinate = mapProxy.convert(value.location, from: .local) else { return }
                        onTap(RouteCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude))
                    }
                )
            }
            .onAppear { fit(visibleFraction: visible) }
            .onChange(of: cameraKey(height: proxy.size.height)) { _, _ in
                fit(visibleFraction: visible)
            }
        }
    }

    private func cameraKey(height: CGFloat) -> String {
        let ids = runs.map(\.id.uuidString).joined(separator: ",")
        return "\(ids)|\(focusedID?.uuidString ?? "")|\(showsSummary)|\(sheetCover)|\(Int(height.rounded()))"
    }

    private func visibleFraction(in height: CGFloat) -> Double {
        guard height > 1 else { return 0.55 }
        let covered = sheetCover.height(in: height)
        return min(0.92, max(0.16, (height - covered) / height))
    }

    /// Keeps the routes in the map area above the bottom sheet.
    private func fit(visibleFraction: Double) {
        let coordinates = framedCoordinates
        var region = RouteGeometry.region(for: coordinates)
        let visible = min(0.92, max(0.16, visibleFraction))
        region.span.latitudeDelta /= visible
        region.center.latitude -= region.span.latitudeDelta * (1 - visible) / 2
        camera = .region(region)
    }

    private var framedCoordinates: [RouteCoordinate] {
        if let focusedID, let run = runs.first(where: { $0.id == focusedID }) {
            return run.coordinates
        }
        return runs.flatMap(\.coordinates)
    }

    private func color(for run: RunWorkout) -> Color {
        let index = runs.firstIndex(where: { $0.id == run.id }) ?? 0
        return TrailTheme.routeColor(at: index)
    }

    private func emphasis(for run: RunWorkout) -> (width: CGFloat, opacity: Double) {
        if showsSummary { return (6, 1) }
        if let focusedID {
            return focusedID == run.id ? (7, 1) : (3, 0.3)
        }
        if isSelecting && chosenIDs.contains(run.id) { return (6, 1) }
        if isSelecting { return (3, 0.35) }
        return (4.5, 0.95)
    }
}

struct RouteBadge: View {
    let coordinates: [RouteCoordinate]

    var body: some View {
        Canvas { context, size in
            let points = RouteGeometry.normalized(coordinates, in: size, padding: 8)
            guard let first = points.first else { return }
            var path = Path()
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            context.stroke(path, with: .color(TrailTheme.accent), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 44, height: 44)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityHidden(true)
    }
}
