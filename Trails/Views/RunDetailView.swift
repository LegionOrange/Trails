import SwiftUI

struct RunDetailView: View {
    @Environment(AppModel.self) private var model
    let run: RunWorkout
    @State private var selectedPhoto: WorkoutPhoto?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RouteMapView(routes: [
                    MapRoute(
                        id: run.id,
                        coordinates: run.coordinates,
                        color: TrailTheme.accent,
                        showEndpoints: true
                    )
                ])
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityIdentifier("route-map")

                HStack(spacing: 12) {
                    StatPill(title: "Distans", value: RunFormatting.distance(run.distanceMeters))
                    StatPill(title: "Tid", value: RunFormatting.duration(run.duration))
                    StatPill(title: "Datum", value: RunFormatting.date(run.startDate))
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

                photoSection
            }
            .padding(16)
        }
        .navigationTitle(run.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo)
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Foton från passet")
                .font(.title3.weight(.semibold))
            let photos = model.photos(for: run)
            if photos.isEmpty {
                Text(emptyPhotoText)
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
                                    .frame(width: 120, height: 120)
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

    private var emptyPhotoText: String {
        if model.dataSource == .sample {
            return "Inga exempelbilder för det här passet."
        }
        return "Inga foton hittades mellan start och mål. Tillåt åtkomst till bilder om appen ska söka i biblioteket."
    }
}

private struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

#Preview("Detalj") {
    NavigationStack {
        RunDetailView(run: SampleWorkoutSource.runs[0])
    }
    .environment(AppModel.preview())
}
