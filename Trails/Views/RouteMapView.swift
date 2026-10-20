import MapKit
import SwiftUI

struct MapRoute: Identifiable {
    let id: UUID
    let coordinates: [RouteCoordinate]
    let color: Color
    var showEndpoints: Bool = false
}

struct RouteMapView: View {
    let routes: [MapRoute]
    @State private var camera: MapCameraPosition

    init(routes: [MapRoute]) {
        self.routes = routes
        let coordinates = routes.flatMap(\.coordinates)
        _camera = State(initialValue: .region(RouteGeometry.region(for: coordinates)))
    }

    var body: some View {
        Map(position: $camera) {
            ForEach(routes.filter { $0.coordinates.count >= 2 }) { route in
                MapPolyline(coordinates: route.coordinates.map(\.coordinate))
                    .stroke(route.color, lineWidth: 4)
                if route.showEndpoints, let start = route.coordinates.first?.coordinate {
                    Marker("Start", systemImage: "figure.run", coordinate: start)
                }
                if route.showEndpoints, let end = route.coordinates.last?.coordinate {
                    Marker("Mål", systemImage: "flag.fill", coordinate: end)
                }
            }
        }
        .mapStyle(.standard)
        .mapControls {
            MapScaleView()
            MapCompass()
        }
        .onAppear(perform: fit)
        .onChange(of: routes.map(\.id)) { _, _ in
            fit()
        }
    }

    private func fit() {
        camera = .region(RouteGeometry.region(for: routes.flatMap(\.coordinates)))
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
        .frame(width: 56, height: 56)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }
}
