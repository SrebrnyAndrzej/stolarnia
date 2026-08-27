import SwiftUI

/// Miniatura kategorii jako **pozycja w ciągu kuchennym**, nie symbol.
///
/// Wzorzec z planera ABRYS: ich miniatury kategorii to schematy elewacji
/// kuchni z podświetlonym pasem, którego kategoria dotyczy. „Szafki Dolne"
/// pokazują podświetlony dolny pas, „Wiszące" górny. Dzięki temu nie trzeba
/// czytać nazwy, żeby wiedzieć, o którą część zabudowy chodzi.
///
/// U nas te same kategorie miały symbole SF — `cabinet` dla dolnych,
/// `square.topthird.inset.filled` dla wiszących, `rectangle.stack` dla cargo.
/// Trzy różne metafory dla trzech miejsc w tym samym ciągu; z symbolu nie
/// wynikało, gdzie moduł stanie.
///
/// **Schemat ma sens tylko dla kuchni.** Szafa czy regał nie są pozycją
/// w ciągu z blatem, więc dla pozostałych grup zostaje symbol — patrz
/// `schematPozycji(dla:)`, które zwraca `nil`.
struct SchematPozycjiWCiaguV099: View {

    /// Który fragment zabudowy jest tą kategorią.
    enum Pozycja {
        /// Pas pod blatem.
        case dolny
        /// Pas nad blatem.
        case gorny
        /// Słupek przez pełną wysokość.
        case wysoki
        /// Bryła stojąca przed ciągiem.
        case wyspa
        /// Dolny pas w narożniku.
        case naroznik
        /// Wąski element domykający ciąg.
        case wykonczenie
    }

    let pozycja: Pozycja
    var aktywny: Bool = false

    // Proporcje pasów w elewacji kuchni: górny pas kończy się tuż nad blatem,
    // blat leży na wysokości roboczej, dolny pas idzie do podłogi.
    private let gornyDol = 0.34
    private let blatGora = 0.46
    private let blatDol = 0.53

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack(alignment: .topLeading) {
                pas(x: 0, y: 0, w: w, h: h * gornyDol,
                    podswietlony: pozycja == .gorny)

                // Blat rysujemy zawsze — to on mówi, że patrzymy na kuchnię,
                // a nie na dowolny prostokąt.
                Rectangle()
                    .fill(kolorLinii)
                    .frame(width: w, height: max(h * (blatDol - blatGora), 1))
                    .offset(y: h * blatGora)

                pas(x: 0, y: h * blatDol, w: w, h: h * (1 - blatDol),
                    podswietlony: pozycja == .dolny)

                nakladka(w: w, h: h)
            }
        }
        .frame(width: 24, height: 18)
        .accessibilityHidden(true)
    }

    /// Element, który nie jest zwykłym pasem elewacji.
    @ViewBuilder
    private func nakladka(w: CGFloat, h: CGFloat) -> some View {
        switch pozycja {
        case .wysoki:
            // Słupek z prawej strony przecina oba pasy i blat.
            pas(x: w * 0.68, y: 0, w: w * 0.32, h: h, podswietlony: true)

        case .naroznik:
            // Narożnik to skrajny segment ciągu — miejsce, gdzie dwie ściany
            // się spotykają. Na 24 punktach szerokości ścięty róg zlałby się
            // z obrysem, więc zaznaczamy sam segment przy krawędzi.
            pas(x: 0, y: h * blatDol, w: w * 0.3, h: h * (1 - blatDol),
                podswietlony: true)

        case .wyspa:
            // Wyspa stoi **przed** ciągiem, nie w nim. Sam podświetlony
            // prostokąt w dolnym pasie czytałby się jak zwykła szafka dolna,
            // dlatego bryła dostaje przerwę w kolorze tła — to ona mówi, że
            // element jest wolnostojący.
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color(uiColor: .systemBackground))
                    .frame(width: w * 0.56, height: h * 0.46)
                    .offset(x: w * 0.22, y: h * 0.56)
                pas(x: w * 0.28, y: h * 0.60, w: w * 0.44, h: h * 0.38,
                    podswietlony: true)
            }

        case .wykonczenie:
            // Blenda domyka ciąg — wąski pionowy pasek przy krawędzi.
            pas(x: w * 0.86, y: 0, w: w * 0.14, h: h, podswietlony: true)

        case .dolny, .gorny:
            EmptyView()
        }
    }

    private func pas(
        x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
        podswietlony: Bool
    ) -> some View {
        Rectangle()
            .fill(podswietlony ? kolorWypelnienia : Color.clear)
            .overlay(
                Rectangle().strokeBorder(kolorLinii, lineWidth: 1)
            )
            .frame(width: max(w, 1), height: max(h, 1))
            .offset(x: x, y: y)
    }

    /// Kolory biorą się z tego, czy filtr jest włączony, bo schemat siedzi
    /// wewnątrz przycisku filtra i musi zmieniać się razem z nim.
    private var kolorLinii: Color {
        aktywny ? Color.white.opacity(0.85) : Color.secondary.opacity(0.55)
    }

    private var kolorWypelnienia: Color {
        aktywny ? Color.white.opacity(0.9) : StolarniaPalette.accentStrong.opacity(0.75)
    }
}

extension FurnitureLibraryCategoryV016 {
    /// Pozycja kategorii w ciągu kuchennym — albo `nil`, gdy kategoria nie
    /// jest częścią ciągu i schemat wprowadzałby w błąd.
    ///
    /// Świadomie nie ma tu szaf, garderób ani regałów: rysowanie im blatu
    /// i pasa wiszącego sugerowałoby kuchenną elewację, której nie mają.
    var schematPozycjiV099: SchematPozycjiWCiaguV099.Pozycja? {
        switch self {
        case .kitchenWall:
            return .gorny
        case .kitchenBase, .kitchenDrawers, .sinkCabinet, .cargo:
            return .dolny
        case .kitchenTall, .pantryStorage, .applianceHousing:
            return .wysoki
        case .kitchenIsland:
            return .wyspa
        case .kitchenCorner:
            return .naroznik
        case .kitchenFinishing:
            return .wykonczenie
        default:
            return nil
        }
    }
}
