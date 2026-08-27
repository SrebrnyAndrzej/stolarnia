import SwiftUI

/// Zwijany panel inspektora — jeden otwarty naraz.
///
/// ## Co było nie tak
///
/// Inspektor był **jedną kolumną przewijaną przez wszystkie sekcje naraz**:
/// narzędzie, zaznaczenie, strefa, gabaryt, szybkie akcje, konsekwencje,
/// podsumowanie. Żeby zmienić profil prowadnicy, trzeba było przewinąć obok
/// gabarytu i akcji szafy — a to jest ekran, na którym spędza się najwięcej
/// czasu przy projektowaniu mebla.
///
/// ## Dlaczego jeden otwarty, a nie wszystkie zwijane
///
/// Zwijane sekcje, które można otworzyć wszystkie, po tygodniu są otwarte
/// wszystkie — i wracamy do przewijania, tylko z dodatkowymi kliknięciami.
/// Otwarcie panelu zamyka poprzedni, więc **wysokość inspektora jest z grubsza
/// stała** i wiadomo, gdzie się patrzy.
///
/// ## Dlaczego nagłówek niesie wartość
///
/// Zwinięty panel bez treści to sam napis — żeby cokolwiek sprawdzić, trzeba
/// go otworzyć. Nagłówek pokazuje **stan po prawej** (`600 × 720 × 560`,
/// `3 fronty`, `GTV H120`), więc zamknięty panel nadal informuje. To jest
/// różnica między spisem treści a przyrządem.
struct PanelInspektoraV0107<Content: View>: View {

    let tytul: String
    let ikona: String
    /// Skrót stanu pokazywany po prawej stronie nagłówka, gdy panel jest
    /// zwinięty. Ma zmieścić się w jednej linii — to podgląd, nie treść.
    var wartosc: String?
    /// Panel wymagający uwagi dostaje obwódkę akcentu. Używać oszczędnie:
    /// gdy wyróżnione są trzy panele, nie jest wyróżniony żaden.
    var wyrozniony: Bool = false
    @Binding var otwarty: Bool
    @ViewBuilder var zawartosc: Content

    @Environment(\.accessibilityReduceMotion) private var ograniczRuch

    var body: some View {
        VStack(spacing: 0) {
            naglowek

            if otwarty {
                zawartosc
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Rozwinięcie wjeżdża od góry, zwinięcie znika bez ruchu.
                    // Otwierając panel patrzysz, co się pojawia; zamykając
                    // już podjąłeś decyzję i czekasz na system.
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        )
                    )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(StolarniaPalette.canvasInset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    wyrozniony
                        ? StolarniaPalette.accentStrong.opacity(0.55)
                        : Color.secondary.opacity(0.14),
                    lineWidth: 1
                )
        )
        .clipped()
        .stolarniaAnimation(StolarniaMotion.pojawienie, value: otwarty)
    }

    private var naglowek: some View {
        Button {
            otwarty.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: ikona)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        wyrozniony ? StolarniaPalette.accentStrong : Color.secondary
                    )
                    .frame(width: 20)

                Text(tytul)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                // Skrót stanu znika po otwarciu — wtedy widać treść, więc
                // powtarzanie jej w nagłówku byłoby szumem.
                if let wartosc, !otwarty {
                    Text(wartosc)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(otwarty ? 0 : -90))
                    .stolarniaAnimation(StolarniaMotion.pojawienie, value: otwarty)
            }
            .padding(.horizontal, 12)
            // Nagłówek jest celem dotyku, nie etykietą — 52 pt to dolna
            // granica reguły projektu dla ważnego wiersza.
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .stolarniaPressable(skala: 0.99)
        .accessibilityAddTraits(otwarty ? [.isSelected] : [])
        .accessibilityHint(otwarty ? "Zwiń" : "Rozwiń")
    }
}

// MARK: - Pasek kontekstu

/// Stały pasek nad panelami: **co jest zaznaczone i jakie ma wymiary**.
///
/// Dotąd trzeba było to wywnioskować z pozycji przewinięcia — sekcja strefy
/// leżała gdzieś w środku listy i po przewinięciu do prowadnic nie było już
/// widać, której strefy dotyczy. Przy meblu z czterema strefami to jest realne
/// źródło pomyłek, bo wszystkie wyglądają tak samo.
struct PasekKontekstuInspektoraV0107: View {
    let tytul: String
    let opis: String
    var wyroznienie: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(tytul)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Text(opis)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let wyroznienie {
                Text(wyroznienie)
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(StolarniaPalette.accentStrong)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(StolarniaPalette.accentStrong.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(StolarniaPalette.accentStrong.opacity(0.28), lineWidth: 1)
        )
    }
}
