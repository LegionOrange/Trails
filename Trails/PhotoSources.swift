import Photos
import UIKit

@MainActor
protocol WorkoutPhotoSource {
    func photos(for runs: [RunWorkout]) async -> [UUID: [WorkoutPhoto]]
}

@MainActor
struct SamplePhotoSource: WorkoutPhotoSource {
    func photos(for runs: [RunWorkout]) async -> [UUID: [WorkoutPhoto]] {
        Self.makePhotos(for: runs)
    }

    static func makePhotos(for runs: [RunWorkout]) -> [UUID: [WorkoutPhoto]] {
        Dictionary(uniqueKeysWithValues: runs.map { run in
            (run.id, photos(for: run))
        })
    }

    static func photos(for run: RunWorkout) -> [WorkoutPhoto] {
        let fractions = [0.22, 0.55, 0.82]
        let palettes: [(UIColor, UIColor, String)] = [
            (UIColor(red: 0.55, green: 0.72, blue: 0.78, alpha: 1), UIColor(red: 0.22, green: 0.48, blue: 0.34, alpha: 1), "Stigen"),
            (UIColor(red: 0.93, green: 0.72, blue: 0.48, alpha: 1), UIColor(red: 0.35, green: 0.42, blue: 0.28, alpha: 1), "Utsikten"),
            (UIColor(red: 0.45, green: 0.58, blue: 0.72, alpha: 1), UIColor(red: 0.62, green: 0.45, blue: 0.28, alpha: 1), "Vattnet")
        ]
        return fractions.enumerated().map { index, fraction in
            let capturedAt = run.startDate.addingTimeInterval(run.duration * fraction)
            let palette = palettes[index % palettes.count]
            let image = render(
                title: run.title,
                caption: palette.2,
                date: capturedAt,
                sky: palette.0,
                ground: palette.1
            )
            return WorkoutPhoto(
                id: "\(run.id.uuidString)-\(index)",
                capturedAt: capturedAt,
                thumbnail: image,
                fullImage: image
            )
        }
    }

    private static func render(title: String, caption: String, date: Date, sky: UIColor, ground: UIColor) -> UIImage {
        let size = CGSize(width: 800, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            sky.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            ground.setFill()
            let hill = UIBezierPath()
            hill.move(to: CGPoint(x: 0, y: 360))
            hill.addCurve(
                to: CGPoint(x: 800, y: 330),
                controlPoint1: CGPoint(x: 220, y: 250),
                controlPoint2: CGPoint(x: 540, y: 460)
            )
            hill.addLine(to: CGPoint(x: 800, y: 600))
            hill.addLine(to: CGPoint(x: 0, y: 600))
            hill.close()
            hill.fill()

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .left
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 54),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ]
            let captionAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .medium),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph
            ]
            (title as NSString).draw(in: CGRect(x: 40, y: 430, width: 720, height: 70), withAttributes: titleAttributes)
            let subtitle = "\(caption) · \(RunFormatting.dateTime(date))"
            (subtitle as NSString).draw(in: CGRect(x: 40, y: 500, width: 720, height: 50), withAttributes: captionAttributes)
        }
    }
}

@MainActor
final class PhotoLibrarySource: WorkoutPhotoSource {
    func photos(for runs: [RunWorkout]) async -> [UUID: [WorkoutPhoto]] {
        guard await ensureAccess() else { return [:] }
        var result: [UUID: [WorkoutPhoto]] = [:]
        for run in runs {
            let assets = fetchAssets(from: run.startDate, to: run.endDate).prefix(12)
            var photos: [WorkoutPhoto] = []
            for asset in assets {
                guard let image = await image(for: asset) else { continue }
                photos.append(WorkoutPhoto(
                    id: asset.localIdentifier,
                    capturedAt: asset.creationDate ?? run.startDate,
                    thumbnail: image,
                    fullImage: image
                ))
            }
            result[run.id] = photos
        }
        return result
    }

    private func ensureAccess() async -> Bool {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch current {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let updated = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            return updated == .authorized || updated == .limited
        default:
            return false
        }
    }

    private func fetchAssets(from start: Date, to end: Date) -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@",
            min(start, end) as NSDate,
            max(start, end) as NSDate
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let fetched = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(fetched.count)
        fetched.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    private func image(for asset: PHAsset) async -> UIImage? {
        let localIdentifier = asset.localIdentifier
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let fetched = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
                guard let asset = fetched.firstObject else {
                    continuation.resume(returning: nil)
                    return
                }
                let options = PHImageRequestOptions()
                options.isSynchronous = true
                options.deliveryMode = .highQualityFormat
                options.resizeMode = .fast
                options.isNetworkAccessAllowed = true
                var output: UIImage?
                PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: CGSize(width: 800, height: 800),
                    contentMode: .aspectFill,
                    options: options
                ) { image, _ in
                    output = image
                }
                continuation.resume(returning: output)
            }
        }
    }
}
