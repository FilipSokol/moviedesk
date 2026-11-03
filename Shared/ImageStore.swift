import ImageIO
import SwiftUI

/// Wczytywanie plakatów i teł z kontenera App Group, od razu pomniejszonych do rozmiaru,
/// w jakim są wyświetlane. Widget nie może archiwizować obrazów większych niż jego
/// powierzchnia w pikselach — za duży obrazek wyświetla się jako pusty.
enum ImageStore {
    static func poster(for pick: Pick, maxPixel: CGFloat) -> CGImage? {
        image(pick.posterFile, in: PicksStore.postersDirectory, maxPixel: maxPixel)
    }

    static func backdrop(for pick: Pick, maxPixel: CGFloat) -> CGImage? {
        image(pick.backdropFile, in: PicksStore.backdropsDirectory, maxPixel: maxPixel)
    }

    static func image(_ file: String?, in directory: URL?, maxPixel: CGFloat) -> CGImage? {
        guard let file, let directory,
              let source = CGImageSourceCreateWithURL(directory.appendingPathComponent(file) as CFURL, nil)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixel)),
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
