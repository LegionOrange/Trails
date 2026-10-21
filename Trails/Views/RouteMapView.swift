import MapKit
import SwiftUI

enum MapSheetCover: Equatable {
    case chrome
    case medium
    case large

    func height(in total: CGFloat) -> CGFloat {
        switch self {
        case .chrome: 168
        case .medium: total * 0.56
        case .large: total * 0.74
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
    let drawMode: AppModel.MapDrawMode
    let recenterToken: Int
    var onTap: (RouteCoordinate) -> Void

    @State private var camera: MapCameraPosition = .region(RouteGeometry.region(for: []))

    var body: some View {
        GeometryReader { proxy in
            let visible = visibleFraction(in: proxy.size.height)
            MapReader { mapProxy in
                Map(position: $camera) {
                    ForEach(runs) { run in
                        routeContent(for: run)
                    }
                }
                .mutedDarkMapStyle()
                .mapControlVisibility(.hidden)
                .environment(\.colorScheme, .dark)
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
        return "\(ids)|\(focusedID?.uuidString ?? "")|\(showsSummary)|\(sheetCover)|\(drawMode)|\(recenterToken)|\(Int(height.rounded()))"
    }

    private func visibleFraction(in height: CGFloat) -> Double {
        guard height > 1 else { return 0.7 }
        let covered = sheetCover.height(in: height)
        return min(0.9, max(0.2, (height - covered) / height))
    }

    /// Keeps the routes in the map area above the panel and the tab bar.
    private func fit(visibleFraction: Double) {
        let coordinates = framedCoordinates
        var region = RouteGeometry.region(for: coordinates)
        let visible = min(0.9, max(0.2, visibleFraction))
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

    @MapContentBuilder
    private func routeContent(for run: RunWorkout) -> some MapContent {
        let coordinates = run.coordinates.map(\.coordinate)
        if coordinates.count >= 2 {
            let style = stroke(for: run)
            MapPolyline(coordinates: coordinates)
                .stroke(
                    style.glow,
                    style: StrokeStyle(lineWidth: style.glowWidth, lineCap: .round, lineJoin: .round)
                )
            MapPolyline(coordinates: coordinates)
                .stroke(
                    style.core,
                    style: StrokeStyle(lineWidth: style.coreWidth, lineCap: .round, lineJoin: .round)
                )
        }
        if focusedID == run.id, let start = coordinates.first {
            Annotation(run.title, coordinate: start, anchor: .center) {
                Circle()
                    .fill(TrailTheme.routeCore)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: TrailTheme.routeGlow.opacity(0.9), radius: 6)
            }
        }
    }

    private func stroke(for run: RunWorkout) -> (glow: Color, glowWidth: CGFloat, core: Color, coreWidth: CGFloat) {
        let dimmed = isDimmed(run)
        if drawMode == .heatmap {
            let strength = dimmed ? 0.45 : 1.0
            return (
                TrailTheme.routeGlow.opacity(0.62 * strength),
                16,
                TrailTheme.routeCore.opacity(0.9 * strength),
                6.5
            )
        }
        let strength = dimmed ? 0.28 : 1.0
        let emphasized = isEmphasized(run)
        return (
            TrailTheme.routeGlow.opacity((emphasized ? 0.72 : 0.48) * strength),
            emphasized ? 12 : 8,
            TrailTheme.routeCore.opacity(strength),
            emphasized ? 5.2 : 3.4
        )
    }

    private func isEmphasized(_ run: RunWorkout) -> Bool {
        if showsSummary { return true }
        if focusedID == run.id { return true }
        if isSelecting && chosenIDs.contains(run.id) { return true }
        return false
    }

    private func isDimmed(_ run: RunWorkout) -> Bool {
        if showsSummary { return false }
        if let focusedID { return focusedID != run.id }
        if isSelecting { return !chosenIDs.contains(run.id) }
        return false
    }
}

private extension View {
    @ViewBuilder
    func mutedDarkMapStyle() -> some View {
        if #available(iOS 18.0, *) {
            self.mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        } else {
            self.mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
        }
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
            context.stroke(path, with: .color(TrailTheme.routeCore), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 44, height: 44)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityHidden(true)
    }
}
