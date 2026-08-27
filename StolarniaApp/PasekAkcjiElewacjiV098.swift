import SwiftUI

/// Stały pasek akcji elewacji — wszystko widoczne, nic w menu „Więcej".
///
/// Wzorzec podpatrzony w planerze ABRYS (meblowo.eu): jeden rząd trybów zawsze
/// na wierzchu, zamiast funkcji rozrzuconych po menu i overlayach. U nas cztery
/// z siedmiu akcji elewacji siedziały w „Więcej" — żeby je znaleźć, trzeba było
/// wiedzieć, że tam są.
///
/// Różnica wobec pierwowzoru jest celowa: **ikona zawsze z tekstem**. Ich pasek
/// jest czysto ikonowy, co dla odbiorcy 50+ oznacza zgadywanie. Reguła projektu
/// mówi wprost, że ikona kluczowej funkcji ma podpis.
///
/// Pasek przewija się poziomo, gdy zabraknie miejsca — kafle nie kurczą się
/// poniżej celu dotyku.
struct PasekAkcjiElewacjiV098<Trailing: View>: View {

    struct Akcja: Identifiable {
        let id = UUID()
        let tytul: String
        let ikona: String
        /// Akcja wiodąca jest wyróżniona wypełnieniem — jak aktywny tryb
        /// w pasku, na którym się wzorujemy.
        var wiodaca: Bool = false
        /// Akcja niedostępna w bieżącym stanie — np. podgląd 3D przy pustej
        /// ścianie. Zostaje widoczna, żeby projektant wiedział, że istnieje.
        var wylaczona: Bool = false
        var identyfikator: String?
        let dzialanie: () -> Void
    }

    let akcje: [Akcja]
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(akcje) { akcja in
                        przycisk(akcja)
                    }
                }
                .padding(.vertical, 2)
            }
            trailing
        }
    }

    @ViewBuilder
    private func przycisk(_ akcja: Akcja) -> some View {
        Button(action: akcja.dzialanie) {
            Label(akcja.tytul, systemImage: akcja.ikona)
                .font(.callout.weight(akcja.wiodaca ? .semibold : .regular))
                .lineLimit(1)
                .padding(.horizontal, 14)
                // Reguła projektu: ważny wiersz 52–62 pt. Badania dla 60+ dają
                // próg komfortu ok. 48 pt, więc 52 jest powyżej optimum.
                .frame(minHeight: 52)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(akcja.wiodaca
                      ? StolarniaPalette.accentStrong.opacity(0.22)
                      : StolarniaPalette.canvasInset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    akcja.wiodaca
                        ? StolarniaPalette.accentStrong.opacity(0.65)
                        : Color.secondary.opacity(0.22),
                    lineWidth: 1)
        )
        .foregroundStyle(akcja.wiodaca ? StolarniaPalette.accentStrong : Color.primary)
        .stolarniaPressable()
        .opacity(akcja.wylaczona ? 0.4 : 1)
        .disabled(akcja.wylaczona)
        .accessibilityIdentifier(akcja.identyfikator ?? akcja.tytul)
    }
}

extension PasekAkcjiElewacjiV098 where Trailing == EmptyView {
    init(akcje: [Akcja]) {
        self.akcje = akcje
        self.trailing = EmptyView()
    }
}
