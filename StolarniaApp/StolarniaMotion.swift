import SwiftUI

/// Słownik ruchu aplikacji: krzywe, czasy i reguła, czy w ogóle animować.
///
/// Stan przed: dwadzieścia kilka animacji w całej aplikacji, z czego trzy
/// z jawną krzywą — wszystkie `.easeInOut`. Reszta brała `.default`, czyli
/// systemową sprężynę, której nikt nie wybrał świadomie.
///
/// ## Dlaczego własne krzywe
///
/// Wbudowane `easeOut` i `easeInOut` są **za słabe** — brakuje im wyrazu, przez
/// który animacja wygląda na zamierzoną, a nie na skutek uboczny. Krzywe niżej
/// to warianty mocniejsze, sprawdzone w bibliotekach interfejsowych.
///
/// ## Czego tu nie ma i dlaczego
///
/// **`easeIn` nie ma i nie ma go mieć.** Startuje wolno, czyli opóźnia ruch
/// dokładnie w chwili, w której użytkownik patrzy najuważniej. Rozwijana lista
/// z `easeIn` przy 300 ms *czuje się* wolniejsza niż ta sama przy `easeOut`.
enum StolarniaMotion {

    // MARK: - Krzywe

    /// Wejścia i wyjścia: startuje szybko, kończy miękko.
    ///
    /// To jest domyślna krzywa interfejsu. Element pojawiający się z tą krzywą
    /// odpowiada natychmiast, co czyta się jako „aplikacja usłyszała dotyk".
    static func wejscie(_ czas: Double) -> Animation {
        .timingCurve(0.23, 1, 0.32, 1, duration: czas)
    }

    /// Ruch po ekranie: przyspiesza i zwalnia, jak rzecz, która ma masę.
    static func ruch(_ czas: Double) -> Animation {
        .timingCurve(0.77, 0, 0.175, 1, duration: czas)
    }

    /// Panele wysuwane — krzywa z Ionica, wyczuwalnie „iOS-owa".
    static func panel(_ czas: Double) -> Animation {
        .timingCurve(0.32, 0.72, 0, 1, duration: czas)
    }

    // MARK: - Czasy
    //
    // Reguła: **animacja interfejsu poniżej 300 ms**. Powyżej zaczyna być
    // odczuwana jako opóźnienie, a nie jako ruch.

    /// Reakcja na dotyk — ma być na granicy natychmiastowości.
    static let dotyk: Double = 0.11
    /// Powrót po puszczeniu — odrobinę dłuższy, żeby element „osiadł".
    ///
    /// Asymetria jest celowa: wciśnięcie to system odpowiadający na dotyk
    /// i musi być natychmiastowe, puszczenie to system wracający do spoczynku
    /// i może wybrzmieć.
    static let puszczenie: Double = 0.16
    /// Podpowiedzi i małe nakładki.
    static let podpowiedz: Double = 0.15
    /// Rozwijane listy, wybory.
    static let lista: Double = 0.2
    /// Arkusze i panele.
    static let arkusz: Double = 0.3

    // MARK: - Gotowe animacje

    static let dotykWcisniecie = wejscie(dotyk)
    static let dotykPuszczenie = wejscie(puszczenie)
    static let pojawienie = wejscie(lista)
    static let panelBoczny = panel(arkusz)
}

// MARK: - Reguła częstotliwości

extension StolarniaMotion {
    /// Jak często użytkownik zobaczy tę animację — i czy w związku z tym
    /// ma ona prawo istnieć.
    ///
    /// To jest **pierwsze pytanie**, przed wyborem krzywej i czasu. Animacja
    /// oglądana setki razy dziennie przestaje być ozdobą i staje się podatkiem
    /// od każdego kliknięcia.
    ///
    /// W tej aplikacji dotyczy to wprost przełączania Plan / Elewacja / 3D
    /// i przechodzenia między etapami: stolarz robi to dziesiątki razy podczas
    /// jednego projektu. **Te przejścia nie są animowane** — zmienia się tylko
    /// reakcja na dotyk. To jest decyzja, nie przeoczenie.
    enum Czestotliwosc {
        /// Setki razy dziennie — nigdy nie animujemy.
        case ciagle
        /// Dziesiątki razy dziennie — animujemy tylko reakcję na dotyk.
        case czeste
        /// Kilka razy dziennie — standardowa animacja.
        case okazjonalne
        /// Rzadko albo raz — tu wolno dołożyć wyrazu.
        case rzadkie

        var animacja: Animation? {
            switch self {
            case .ciagle:      return nil
            case .czeste:      return nil
            case .okazjonalne: return StolarniaMotion.pojawienie
            case .rzadkie:     return StolarniaMotion.wejscie(0.28)
            }
        }
    }
}

// MARK: - Reakcja na dotyk

/// Styl przycisku, który **odpowiada na dotyk**.
///
/// W aplikacji było 53 przycisków z `.buttonStyle(.plain)`, czyli bez żadnej
/// reakcji: dotknięcie kafla systemu szuflad, etapu w pasku czy podziałki
/// w bibliotece wyglądało identycznie jak dotknięcie tła. Interfejs, który nie
/// potwierdza dotyku, czyta się jako zawieszony — użytkownik dotyka drugi raz.
///
/// Skala jest **subtelna** (0.97). Wyraźniejsza wygląda na zabawkę, słabsza
/// nie niesie informacji.
struct StolarniaPressableButtonStyle: ButtonStyle {
    /// Elementy, które same w sobie są duże (kafle, wiersze), znoszą mniejszą
    /// skalę — przy dużej powierzchni ten sam procent to więcej pikseli ruchu.
    var skala: CGFloat = 0.97

    @Environment(\.accessibilityReduceMotion) private var ograniczRuch

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                // Przy ograniczonym ruchu skala znika, ale potwierdzenie
                // dotyku zostaje — jako zmiana krycia. Reduced Motion znaczy
                // „mniej ruchu", nie „bez informacji zwrotnej".
                configuration.isPressed && !ograniczRuch ? skala : 1
            )
            .opacity(
                configuration.isPressed && ograniczRuch ? 0.72 : 1
            )
            .animation(
                configuration.isPressed
                ? StolarniaMotion.dotykWcisniecie
                : StolarniaMotion.dotykPuszczenie,
                value: configuration.isPressed
            )
    }
}

extension View {
    /// Reakcja na dotyk dla przycisku, który poza tym ma własny wygląd.
    ///
    /// Zastępuje `.buttonStyle(.plain)` wszędzie tam, gdzie element jest
    /// naciskalny i ma to potwierdzać.
    func stolarniaPressable(skala: CGFloat = 0.97) -> some View {
        buttonStyle(StolarniaPressableButtonStyle(skala: skala))
    }
}


// MARK: - Ograniczony ruch

/// Animacja respektująca systemowe „Ogranicz ruch".
///
/// Ograniczony ruch znaczy **mniej ruchu i łagodniej**, a nie „bez animacji".
/// Zanikanie i zmiany koloru pomagają zrozumieć, co się stało, i zostają.
/// Znika przemieszczanie: wjazdy z krawędzi, przesunięcia, skalowanie.
///
/// Aplikacja obsługuje już „Ogranicz przezroczystość" (`stolarniaMaterial`),
/// więc brak obsługi ruchu był luką w spójności, nie świadomym wyborem.
private struct StolarniaOgraniczonyRuchModifier<V: Equatable>: ViewModifier {
    let animacja: Animation
    let wartosc: V

    @Environment(\.accessibilityReduceMotion) private var ograniczRuch

    func body(content: Content) -> some View {
        content.animation(
            ograniczRuch
            // Samo zanikanie, bez ruchu — i krócej, bo przy ograniczonym
            // ruchu dłuższe przejście samo w sobie bywa męczące.
            ? .easeOut(duration: StolarniaMotion.podpowiedz)
            : animacja,
            value: wartosc
        )
    }
}

extension View {
    /// Jak `.animation(_:value:)`, ale pod „Ogranicz ruch" zostaje samo zanikanie.
    ///
    /// Używaj wszędzie tam, gdzie animacja **przemieszcza** element. Dla samej
    /// zmiany koloru czy krycia zwykłe `.animation` wystarczy.
    func stolarniaAnimation<V: Equatable>(
        _ animacja: Animation,
        value: V
    ) -> some View {
        modifier(
            StolarniaOgraniczonyRuchModifier(
                animacja: animacja,
                wartosc: value
            )
        )
    }
}

extension AnyTransition {
    /// Przejście panelu wjeżdżającego od dołu.
    ///
    /// Wjazd i zanik są **niesymetryczne**: pojawienie się może wybrzmieć,
    /// zniknięcie ma być szybkie. Użytkownik, który zamyka panel, podjął już
    /// decyzję i czeka na system — a system nie powinien kazać na siebie czekać.
    static var stolarniaPanelOdDolu: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        )
    }
}
