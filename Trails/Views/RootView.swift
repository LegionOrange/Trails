import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TabView {
            RunListView()
                .tabItem {
                    Label("Rundor", systemImage: "figure.run")
                }
            FavoritesOverviewView()
                .tabItem {
                    Label("Markerade", systemImage: "star.fill")
                }
        }
        .tint(TrailTheme.accent)
        .task {
            await model.reloadIfNeeded()
        }
    }
}

#Preview("Rundor") {
    RootView()
        .environment(AppModel.preview())
}
