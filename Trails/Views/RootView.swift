import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var page: SheetPage = .routes
    @State private var showsPanel = false
    @State private var detent: PresentationDetent = .medium

    static let largeDetent = PresentationDetent.fraction(0.74)

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                TrailsMap(
                    runs: model.mapRuns,
                    focusedID: model.showsSelectionSummary ? nil : model.focusedRunID,
                    chosenIDs: model.chosenRunIDs,
                    isSelecting: model.isSelecting,
                    showsSummary: model.showsSelectionSummary,
                    sheetCover: sheetCover,
                    drawMode: model.mapDrawMode,
                    recenterToken: model.recenterToken,
                    onTap: { model.handleMapTap($0) }
                )
                .ignoresSafeArea()
                .accessibilityIdentifier(model.isLoading ? "map-loading" : "map-ready")
            }
            .overlay(alignment: .bottom) {
                if showsPanel {
                    RouteSheet(page: $page, detent: $detent)
                        .padding(.bottom, 124)
                        .frame(maxWidth: .infinity)
                        .frame(height: panelHeight(in: proxy.size.height))
                        .background(panelBackground)
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(Color.white.opacity(0.35))
                                .frame(width: 42, height: 5)
                                .padding(.top, 8)
                                .accessibilityHidden(true)
                        }
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 28))
                        .ignoresSafeArea(edges: .bottom)
                        .accessibilityIdentifier("panel")
                }
            }
            .overlay(alignment: .top) { topChrome }
            .overlay(alignment: .bottom) {
                if showsPanel {
                    mapControls
                        .padding(.horizontal, 16)
                        .padding(.bottom, panelHeight(in: proxy.size.height) + 12)
                }
            }
            .overlay(alignment: .bottom) { bottomChrome }
        }
        .preferredColorScheme(.dark)
        .tint(TrailTheme.accent)
        .task {
            await model.reloadIfNeeded()
        }
        .onChange(of: model.focusedRunID) { _, focusedID in
            if focusedID != nil {
                page = .routes
                showsPanel = true
                detent = Self.largeDetent
            }
        }
    }

    private var sheetCover: MapSheetCover {
        guard showsPanel else { return .chrome }
        return detent == Self.largeDetent ? .large : .medium
    }

    private func panelHeight(in total: CGFloat) -> CGFloat {
        detent == Self.largeDetent ? total * 0.74 : total * 0.56
    }

    private var panelBackground: some View {
        UnevenRoundedRectangle(topLeadingRadius: 28, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 28)
            .fill(Color.black.opacity(0.62))
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 28, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 28)
                    .fill(.ultraThinMaterial)
            )
            .ignoresSafeArea(edges: .bottom)
    }

    private var topChrome: some View {
        HStack(alignment: .center, spacing: 10) {
            mapModeCapsule
            Spacer(minLength: 8)
            selectionControls
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var mapControls: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                recenterButton
            }
            timelinePill
        }
    }

    private var recenterButton: some View {
        Button {
            model.recenterMap()
        } label: {
            Image(systemName: "location.fill")
                .font(.body.weight(.semibold))
                .frame(width: 46, height: 46)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("recenter-button")
        .accessibilityLabel("Centrera")
    }

    private var timelinePill: some View {
        Button {
            open(.filter)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                Text(model.timelineTitle)
                Image(systemName: "chevron.up")
                    .font(.caption.weight(.bold))
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("timeline-pill")
    }

    private var bottomChrome: some View {
        VStack(spacing: 10) {
            if !showsPanel {
                mapControls
            }
            tabBar
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var mapModeCapsule: some View {
        HStack(spacing: 2) {
            modeButton("map", mode: .routes, identifier: "map-mode-routes", label: "Rutter på kartan")
            modeButton("flame.fill", mode: .heatmap, identifier: "map-mode-heatmap", label: "Värmekarta")
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func modeButton(_ symbol: String, mode: AppModel.MapDrawMode, identifier: String, label: String) -> some View {
        let selected = model.mapDrawMode == mode
        return Button {
            model.mapDrawMode = mode
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 36, height: 36)
                .background(selected ? TrailTheme.accent : Color.clear, in: Circle())
                .foregroundStyle(selected ? Color.black : Color.white)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(label)
    }

    private var selectionControls: some View {
        HStack(spacing: 8) {
            if model.isSelecting && !model.chosenRunIDs.isEmpty {
                Button("Sammanfatta") {
                    model.showSummary()
                    page = .routes
                    showsPanel = true
                    detent = Self.largeDetent
                }
                .accessibilityIdentifier("summarize-button")
                .buttonStyle(MapChromeButtonStyle())
            }
            Button {
                if model.isSelecting {
                    model.endSelection()
                } else {
                    model.beginSelection()
                    page = .routes
                    showsPanel = true
                    detent = .medium
                }
            } label: {
                if model.isSelecting {
                    Text("Klar")
                } else {
                    Image(systemName: "rectangle.dashed")
                        .font(.system(size: 17, weight: .semibold))
                        .accessibilityHidden(true)
                }
            }
            .accessibilityIdentifier("select-button")
            .accessibilityLabel(model.isSelecting ? "Klar" : "Välj")
            .buttonStyle(MapChromeButtonStyle(circular: !model.isSelecting))
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(SheetPage.allCases) { item in
                let active = isActive(item)
                Button {
                    open(item)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.symbol)
                            .font(.body.weight(.semibold))
                            .frame(width: 48, height: 28)
                            .background(active ? TrailTheme.accent : Color.clear, in: Capsule())
                            .foregroundStyle(active ? Color.black : Color.white.opacity(0.78))
                        Text(item.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(active ? TrailTheme.accent : Color.white.opacity(0.72))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(item.accessibilityID)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(.horizontal, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 0.5))
    }

    private func isActive(_ item: SheetPage) -> Bool {
        if !showsPanel { return item == .routes }
        return page == item
    }

    private func open(_ item: SheetPage) {
        let showingRoutesList = showsPanel && page == .routes && model.focusedRun == nil && !model.showsSelectionSummary
        page = item
        showsPanel = true
        switch item {
        case .routes:
            model.showsSelectionSummary = false
            model.clearFocus()
            if !showingRoutesList {
                detent = .medium
            }
        case .filter, .statistics:
            model.showsSelectionSummary = false
            detent = Self.largeDetent
        }
    }
}

private struct MapChromeButtonStyle: ButtonStyle {
    var circular = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(circular ? AnyShapeStyle(TrailTheme.accent) : AnyShapeStyle(.primary))
            .frame(minWidth: circular ? 46 : nil, minHeight: circular ? 46 : nil)
            .padding(.horizontal, circular ? 0 : 14)
            .padding(.vertical, circular ? 0 : 8)
            .background {
                if circular {
                    Circle().fill(.ultraThinMaterial)
                } else {
                    Capsule().fill(.ultraThinMaterial)
                }
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

#Preview("Karta") {
    RootView()
        .environment(AppModel.preview())
}
