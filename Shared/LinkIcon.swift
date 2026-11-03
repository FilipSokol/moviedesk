import CoreGraphics
import Foundation

/// Ikona strony dla skrótu: plik w katalogu `Icons` kontenera App Group.
/// Styl jest zapisany w nazwie pliku, żeby widget nie musiał analizować obrazka przy każdym rysowaniu.
enum LinkIcon {
    enum Style: String {
        /// Ikona wypełnia cały kwadrat — rysujemy ją na całe kółko.
        case fill
        /// Ikona z przezroczystymi rogami — rysujemy ją pomniejszoną na jasnym tle.
        case padded
    }

    static func host(of url: URL) -> String? {
        guard var host = url.host?.lowercased(), !host.isEmpty else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host
    }

    static func fileName(host: String, style: Style) -> String {
        "\(host).\(style.rawValue).img"
    }

    /// Plik ikony dla adresu (dowolny styl), jeśli już jest.
    static func existingFile(for url: URL) -> (name: String, style: Style)? {
        guard let host = host(of: url), let directory = PicksStore.iconsDirectory else { return nil }
        for style in [Style.fill, .padded] {
            let name = fileName(host: host, style: style)
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path) {
                return (name, style)
            }
        }
        return nil
    }

    static func image(for url: URL, maxPixel: CGFloat) -> (image: CGImage, style: Style)? {
        guard let file = existingFile(for: url),
              let image = ImageStore.image(file.name, in: PicksStore.iconsDirectory, maxPixel: maxPixel)
        else { return nil }
        return (image, file.style)
    }
}
