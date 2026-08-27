import SwiftUI

/// Przełącznik widoków wewnątrz etapu — nad rysunkiem, nie w pasku bocznym.
///
/// Plan, elewacja i 3D to **trzy spojrzenia na ten sam mebel**, a nie trzy
/// miejsca w aplikacji. Trzymanie ich jako osobnych pozycji paska bocznego
/// mówiło co innego: że to trzy różne rzeczy, między którymi się nawiguje.
/// Ten sam wzorzec ma planer, na który wskazał użytkownik — jeden rząd trybów
/// zawsze na wierzchu, przy treści, której dotyczy.
///
/// Reguła projektu obowiązuje: **ikona zawsze z podpisem**, cel dotyku
/// nie mniejszy niż 44 pt, przewijanie poziome zamiast kurczenia kafli.
struct PrzelacznikWidokuV0103: View {

    struct Widok: Identifiable, Hashable {
        let id: String
        let tytul: String
        let ikona: String
        /// Widok niedostępny w bieżącym stanie zostaje widoczny i wyszarzony,
        /// żeby było wiadomo, że istnieje.
        var wylaczony: Bool = false
    }

    let widoki: [Widok]
    @Binding var wybrany: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(widoki) { widok in
                    przycisk(widok)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        // `stolarniaMaterial`, nie surowe `.thinMaterial` — modyfikator
        // projektu podmienia materiał na kolor, gdy system ma włączone
        // Reduce Transparency. Pasek leży nad rysunkiem, więc przezroczystość
        // bez tej obsługi zlewałaby etykiety z liniami planu.
        .stolarniaMaterial(.thinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    @ViewBuilder
    private func przycisk(_ widok: Widok) -> some View {
        let aktywny = wybrany == widok.id

        Button {
            wybrany = widok.id
        } label: {
            Label(widok.tytul, systemImage: widok.ikona)
                .font(.subheadline.weight(aktywny ? .semibold : .regular))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .foregroundStyle(aktywny ? Color.accentColor : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            aktywny
                            ? Color.accentColor.opacity(0.16)
                            : Color.clear
                        )
                )
        }
        .stolarniaPressable()
        .opacity(widok.wylaczony ? 0.4 : 1)
        .disabled(widok.wylaczony)
        .accessibilityAddTraits(aktywny ? [.isSelected] : [])
    }
}
