import AppIntents
import WidgetKit

/// Przycisk „odśwież” w widgecie: pokazuje kolejne trzy filmy z puli.
/// Po wykonaniu intencji WidgetKit sam przeładowuje widget, a zmiana kursora uruchamia animację.
struct ShufflePicksIntent: AppIntent {
    static let title: LocalizedStringResource = "Pokaż kolejne filmy"
    static var isDiscoverable: Bool { false }

    func perform() async throws -> some IntentResult {
        PicksStore.advance()
        return .result()
    }
}
