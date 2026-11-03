import CoreGraphics
import Foundation
import ImageIO

/// Pobiera ikony do kółek ze skrótami i znaczków na plakatach:
/// - logotypy serwisów VOD z TMDB (oficjalne grafiki dostawców),
/// - favikony pozostałych stron (np. dowolny serwis spoza listy) — przez usługę ikon Google.
/// Wszystko trafia do kontenera App Group, bo widget nie ma dostępu do sieci.
enum IconFetcher {
    /// Logotypy serwisów, których jeszcze nie ma na dysku. `true`, gdy coś doszło.
    @discardableResult
    static func refreshServiceLogos(tmdb: TMDBClient) async -> Bool {
        guard let directory = PicksStore.logosDirectory else { return false }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let missing = StreamingService.allCases.filter {
            !FileManager.default.fileExists(atPath: directory.appendingPathComponent($0.logoFileName).path)
        }
        guard !missing.isEmpty, let logos = try? await tmdb.providerLogosPL() else { return false }

        var added = false
        for service in missing {
            // Podstawowy wariant, np. „Netflix”, a nie „Netflix Standard with Ads”.
            let candidates = logos.filter { service.matches(providerName: $0.key) }
            guard let path = candidates.min(by: { $0.key.count < $1.key.count })?.value,
                  let data = try? await tmdb.image(path, size: "w154")
            else { continue }
            if (try? data.write(to: directory.appendingPathComponent(service.logoFileName), options: .atomic)) != nil {
                added = true
            }
        }
        return added
    }

    /// Favikony stron z linków (poza serwisami VOD, które mają logo). `true`, gdy coś doszło.
    @discardableResult
    static func refreshFavicons(for links: [QuickLink]) async -> Bool {
        guard let directory = PicksStore.iconsDirectory else { return false }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var added = false
        for link in links {
            guard let url = link.url, let host = LinkIcon.host(of: url),
                  LinkIcon.existingFile(for: url) == nil
            else { continue }
            // Serwisy VOD mają własne znaczki (`ServiceMark`) — favikona niepotrzebna.
            if StreamingService.detect(in: url) != nil { continue }
            guard let data = await download(host: host),
                  let style = analyze(data)
            else { continue }
            let file = directory.appendingPathComponent(LinkIcon.fileName(host: host, style: style))
            if (try? data.write(to: file, options: .atomic)) != nil { added = true }
        }
        return added
    }

    private static func download(host: String) async -> Data? {
        var components = URLComponents(string: "https://www.google.com/s2/favicons")
        components?.queryItems = [URLQueryItem(name: "domain", value: host), URLQueryItem(name: "sz", value: "128")]
        guard let url = components?.url else { return nil }
        return try? await HTTP.get(URLRequest(url: url), service: "Ikony")
    }

    /// Odrzuca zastępczą „kulę ziemską” (Google zwraca ją w 16 px, gdy strona nie ma ikony)
    /// i sprawdza, czy ikona wypełnia cały kwadrat (wtedy rysujemy ją na całe kółko),
    /// czy ma przezroczyste rogi (wtedy na jasnym tle, pomniejszoną).
    private static func analyze(_ data: Data) -> LinkIcon.Style? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width >= 48
        else { return nil }

        let size = 8
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: size, height: size, bitsPerComponent: 8,
                bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
            return true
        }
        guard drawn else { return .padded }
        let corners = [0, size - 1, size * (size - 1), size * size - 1]
        let opaque = corners.allSatisfy { pixels[$0 * 4 + 3] > 230 }
        return opaque ? .fill : .padded
    }
}
