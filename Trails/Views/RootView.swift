import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var detent: PresentationDetent = Self.smallDetent
    @State private var showsSheet = false

    static let smallDetent = PresentationDetent.height(210)
    static let largeDetent = PresentationDetent.fraction(0.80)

    var body: some View {
        ZStack {
            TrailsMap(
                runs: model.mapRuns,
                focusedID: model.showsSelectionSummary ? nil : model.focusedRunID,
                chosenIDs: model.chosenRunIDs,
                isSelecting: model.isSelecting,
                showsSummary: model.showsSelectionSummary,
                sheetCover: sheetCover,
                onTap: { model.handleMapTap($0) }
            )
            .ignoresSafeArea()
            .accessibilityIdentifier(model.isLoading ? "map-loading" : "map-ready")

            if model.isLoading && model.runs.isEmpty {
                ProgressView("Hämtar rundor…")
                    .padding(16)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .overlay(alignment: .topTrailing) {
            selectionControls
                .padding(.trailing, 16)
                .padding(.top, 8)
        }
        .sheet(isPresented: $showsSheet) {
            RouteSheet(detent: $detent)
                .presentationDetents([Self.smallDetent, .medium, Self.largeDetent], selection: $detent)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(.regularMaterial)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .interactiveDismissDisabled()
        }
        .tint(TrailTheme.accent)
        .task {
            // A sheet whose flag starts true never transitions into view.
            if !showsSheet {
                try? await Task.sleep(for: .milliseconds(300))
                showsSheet = true
            }
            await model.reloadIfNeeded()
        }
        .onChange(of: model.focusedRunID) { _, focusedID in
            if focusedID != nil {
                detent = Self.largeDetent
            }
        }
        .onChange(of: showsSheet) { _, isShown in
            if !isShown { showsSheet = true }
        }
    }

    private var sheetCover: MapSheetCover {
        if detent == Self.smallDetent { return .small }
        if detent == .medium { return .medium }
        return .large
    }

    private var selectionControls: some View {
        HStack(spacing: 8) {
            if model.isSelecting && !model.chosenRunIDs.isEmpty {
                Button("Sammanfatta") {
                    model.showSummary()
                    detent = Self.largeDetent
                }
                .accessibilityIdentifier("summarize-button")
                .buttonStyle(MapChromeButtonStyle())
            }
            Button(model.isSelecting ? "Klar" : "Välj") {
                if model.isSelecting {
                    model.endSelection()
                } else {
                    model.beginSelection()
                    detent = .medium
                }
            }
            .accessibilityIdentifier("select-button")
            .buttonStyle(MapChromeButtonStyle())
        }
    }
}

private struct MapChromeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

#Preview("Karta") {
    RootView()
        .environment(AppModel.preview())
}
