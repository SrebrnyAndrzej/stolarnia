import SwiftUI

enum PrezentacjaProdukcjiV074 {
    case modalna
    case osadzona
}

enum WorkspaceDestinationV074:
    String,
    CaseIterable,
    Hashable,
    Identifiable
{
    case plan
    case elewacja
    case elewacjaWyspy
    case widok3D
    case garderobyDrzwi
    /// Wycena pomieszczenia **wewnątrz** warsztatu.
    ///
    /// Osobna od oferty projektowej na ekranie projektu: tamta obejmuje
    /// wszystkie pomieszczenia i jest dokumentem dla klienta, ta odpowiada
    /// na pytanie „ile kosztuje to, co mam przed sobą". Stara droga
    /// (`ProjektSzczegolySheet.projectQuote`) działa bez zmian.
    case wycena
    case produkcjaStart
    case formatki
    case rozkroj
    case obrzeza
    case cnc
    case montazPakowanie
    case zakupPlyt

    var id: String { rawValue }

    static var projektowe:
        [WorkspaceDestinationV074]
    {
        [
            .plan,
            .elewacja,
            .elewacjaWyspy,
            .widok3D,
            .garderobyDrzwi
        ]
    }

    static var produkcyjne:
        [WorkspaceDestinationV074]
    {
        [
            .produkcjaStart,
            .formatki,
            .rozkroj,
            .obrzeza,
            .cnc,
            .montazPakowanie,
            .zakupPlyt
        ]
    }

    /// Do którego etapu pracy należy ten ekran.
    ///
    /// Podział idzie po tym, **po co się tam wchodzi**, nie po tym, jaka
    /// technologia za tym stoi. Dlatego obrzeża i CNC są przy rozkroju
    /// (to jedna robota na formatkach), a zakup płyt i pakowanie przy
    /// zamówieniu (to jedna robota z hurtownią).
    var etap: EtapPracyV0103 {
        switch self {
        case .plan, .elewacja, .elewacjaWyspy, .widok3D, .garderobyDrzwi:
            return .projekt
        case .wycena:
            return .wycena
        case .produkcjaStart, .formatki, .rozkroj, .obrzeza, .cnc:
            return .rozkroj
        case .montazPakowanie, .zakupPlyt:
            return .zamowienie
        }
    }

    static func cele(etapu etap: EtapPracyV0103) -> [WorkspaceDestinationV074] {
        allCases.filter { $0.etap == etap }
    }

    var tytul: String {
        switch self {
        case .plan:
            return "Plan 2D"
        case .elewacja:
            return "Elewacja"
        case .elewacjaWyspy:
            return "Elewacja wyspy"
        case .widok3D:
            return "Widok 3D"
        case .garderobyDrzwi:
            return "Garderoby i drzwi"
        case .wycena:
            return "Wycena"
        case .produkcjaStart:
            return "Produkcja"
        case .formatki:
            return "Formatki"
        case .rozkroj:
            return "Rozkrój płyt"
        case .obrzeza:
            return "Obrzeża"
        case .cnc:
            return "CNC i wiercenia"
        case .montazPakowanie:
            return "Montaż i pakowanie"
        case .zakupPlyt:
            return "Zakup płyt"
        }
    }

    var opis: String {
        switch self {
        case .plan:
            return "Układ pomieszczenia i modułów"
        case .elewacja:
            return "Widok aktywnej ściany"
        case .elewacjaWyspy:
            return "Widok modułów wolnostojących"
        case .widok3D:
            return "Kontrola bryły projektu"
        case .garderobyDrzwi:
            return "Szafy przesuwne i dostęp"
        case .wycena:
            return "Warianty i cena tego pomieszczenia"
        case .produkcjaStart:
            return "Status przygotowania produkcji"
        case .formatki:
            return "Lista elementów i etykiety"
        case .rozkroj:
            return "Arkusze, ułożenie i odpad"
        case .obrzeza:
            return "Okleinowanie każdej krawędzi"
        case .cnc:
            return "Wiercenia, rowki i operacje"
        case .montazPakowanie:
            return "Kolejność montażu i paczki"
        case .zakupPlyt:
            return "Zapotrzebowanie materiałowe"
        }
    }

    /// Krótka etykieta do przełącznika nad rysunkiem.
    ///
    /// Pełne tytuły („Elewacja wyspy", „Garderoby i drzwi") są dobre w pasku
    /// bocznym, ale w poziomym rzędzie zjadają miejsce i wymuszają przewijanie
    /// przy pierwszym spojrzeniu.
    var tytulSkrocony: String {
        switch self {
        case .plan:           return "Plan"
        case .elewacja:       return "Elewacja"
        case .elewacjaWyspy:  return "Wyspa"
        case .widok3D:        return "3D"
        case .garderobyDrzwi: return "Przesuwne"
        default:              return tytul
        }
    }

    var symbol: String {
        switch self {
        case .plan:
            return "square.grid.2x2"
        case .elewacja:
            return "rectangle.portrait"
        case .elewacjaWyspy:
            return "rectangle.center.inset.filled"
        case .widok3D:
            return "cube"
        case .garderobyDrzwi:
            return "rectangle.split.3x1"
        case .wycena:
            return "banknote"
        case .produkcjaStart:
            return "shippingbox"
        case .formatki:
            return "list.number"
        case .rozkroj:
            return "square.grid.3x3.square"
        case .obrzeza:
            return "rectangle.and.hand.point.up.left"
        case .cnc:
            return "gearshape.2"
        case .montazPakowanie:
            return "shippingbox"
        case .zakupPlyt:
            return "cart"
        }
    }

    var jestProjektem: Bool {
        trybProjektowy != nil
    }

    var trybProjektowy:
        TrybWorkspaceProjektowegoV063?
    {
        switch self {
        case .plan:
            return .plan
        case .elewacja:
            return .elewacja
        case .elewacjaWyspy:
            return .elewacjaWyspy
        case .widok3D:
            return .widok3D
        case .garderobyDrzwi:
            return .garderobyDrzwi
        default:
            return nil
        }
    }

    var zakladkaProdukcji:
        ZakladkaProdukcjiV071?
    {
        switch self {
        case .produkcjaStart:
            return .pulpit
        case .formatki:
            return .formatki
        case .rozkroj:
            return .rozkroj
        case .obrzeza:
            return .obrzeza
        case .cnc:
            return .obrobki
        case .montazPakowanie:
            return .montaz
        case .zakupPlyt:
            return .zakup
        default:
            return nil
        }
    }

    init(
        zakladkaProdukcji:
            ZakladkaProdukcjiV071
    ) {
        switch zakladkaProdukcji {
        case .pulpit:
            self = .produkcjaStart
        case .formatki:
            self = .formatki
        case .rozkroj:
            self = .rozkroj
        case .obrzeza:
            self = .obrzeza
        case .obrobki:
            self = .cnc
        case .montaz:
            self = .montazPakowanie
        case .zakup:
            self = .zakupPlyt
        }
    }
}

struct WorkspaceNawigacjaV074:
    View
{
    @Binding var wybor:
        WorkspaceDestinationV074

    let nazwaProjektu: String
    let liczbaModulow: Int
    let liczbaFormatek: Int
    let liczbaBlokadGotowosci: Int
    let liczbaOstrzezenGotowosci: Int
    /// Cena brutto pomieszczenia — widoczna **podczas projektowania**.
    ///
    /// W narzędziach wycenowych dla wykonawców suma aktualizuje się na bieżąco,
    /// gdy klient zaznacza opcje. U nas cena mieszkała za osobnym oknem, więc
    /// przestawała być narzędziem decyzji, a stawała się raportem na koniec.
    ///
    /// `nil` znaczy „nie ma z czego policzyć" (pusty pokój), a nie zero.
    let cenaBruttoPomieszczenia: Double?
    /// Ile pozycji wyceny nie ma jeszcze ceny w cenniku.
    ///
    /// Wzorzec z systemów CPQ: brak danych oznacza się **przy pozycji**,
    /// a nie milczy o nim w podsumowaniu. Dopóki cennik jest uzupełniany,
    /// suma jest oszacowaniem i musi to mówić.
    let brakiCennika: Int

    var body: some View {
        // Sekcje to **etapy drogi**, nie kategorie techniczne.
        //
        // Wcześniej były dwa worki („Projekt" i „Produkcja") z dwunastoma
        // równorzędnymi pozycjami, a wyceny nie było wśród nich wcale.
        // Teraz nagłówek mówi, na którym etapie się jest i po co on jest;
        // ekrany zostają te same, więc nic nie znika z zasięgu.
        // **Jeden wiersz na etap**, nie lista ekranów.
        //
        // Pasek miał dwanaście równorzędnych pozycji w dwóch workach
        // („Projekt" i „Produkcja"), a wyceny nie było wśród nich wcale.
        // Teraz są cztery etapy drogi, którą się chodzi. Widoki wewnątrz
        // etapu nie znikają — przełącznik plan / elewacja / 3D stoi nad
        // rysunkiem, a produkcja ma własny pasek zakładek w treści.
        List {
            ForEach(EtapPracyV0103.allCases) { etap in
                wierszEtapu(etap)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(nazwaProjektu)
        .safeAreaInset(edge: .bottom) {
            podsumowanie
        }
    }

    /// Wiersz etapu — numer, nazwa, cel i skrót zawartości.
    ///
    /// Wyróżnienie idzie po **etapie**, nie po konkretnym ekranie: przełączenie
    /// z planu na elewację nie zmienia etapu, bo to nadal projektowanie.
    private func wierszEtapu(
        _ etap: EtapPracyV0103
    ) -> some View {
        let aktywny = wybor.etap == etap

        return Button {
            // Wejście w etap, na którym już jesteśmy, nie może wyrzucić
            // z bieżącego widoku — inaczej stuknięcie w „Projekt" przy
            // otwartej elewacji cofałoby na plan bez powodu.
            if !aktywny {
                wybor = etap.celDomyslny
            }
        } label: {
            HStack(spacing: 12) {
                Text("\(etap.numer)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(aktywny ? Color.white : Color.accentColor)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle().fill(
                            aktywny
                            ? Color.accentColor
                            : Color.accentColor.opacity(0.16)
                        )
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(etap.nazwa)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(etap.opis)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        // Wiersz etapu jest dużym celem — przy dużej powierzchni ta sama
        // skala procentowa to więcej ruchu, więc jest łagodniejsza.
        //
        // Samo **przejście między etapami nie jest animowane**: stolarz robi
        // to dziesiątki razy podczas jednego projektu, a animacja oglądana
        // tak często przestaje być ozdobą i staje się podatkiem od kliknięcia.
        .stolarniaPressable(skala: 0.985)
        .listRowBackground(
            aktywny
            ? Color.accentColor.opacity(0.12)
            : Color.clear
        )
        .accessibilityAddTraits(aktywny ? [.isSelected] : [])
    }

    /// Nagłówek sekcji z numerem kroku i celem etapu.
    ///
    /// Numer niesie prawdziwą informację — te etapy **są** kolejnością pracy,
    /// a nie listą kategorii, więc numerowanie nie jest tu ozdobą.
    /// Cena pomieszczenia w stopce paska — zawsze na oczach.
    @ViewBuilder
    private var cenaPomieszczeniaV0103: some View {
        if let cena = cenaBruttoPomieszczenia {
            VStack(alignment: .leading, spacing: 1) {
                Label {
                    Text(cena.formatted(.currency(code: "PLN")))
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        // Cyfry przetaczają się zamiast podmieniać skokowo.
                        //
                        // To jedyne miejsce w aplikacji, gdzie liczba zmienia
                        // się **w reakcji na pracę użytkownika** — po każdej
                        // zmianie modułu. Skokowa podmiana czyta się jak
                        // przeładowanie ekranu; przetoczenie mówi, że to ta
                        // sama liczba, która właśnie urosła.
                        //
                        // Font jest `monospacedDigit`, więc szerokość nie
                        // skacze przy zmianie cyfr — bez tego przetaczanie
                        // ciągnęłoby za sobą cały wiersz.
                        .contentTransition(.numericText())
                        .animation(StolarniaMotion.pojawienie, value: cena)
                } icon: {
                    Image(systemName: "banknote")
                }

                // Słowo „szacunek" pada wprost, dopóki cennik ma dziury.
                // Liczba bez tego zastrzeżenia byłaby obietnicą, której
                // nie mamy z czego dotrzymać.
                Text(
                    brakiCennika > 0
                    ? "szacunek — \(brakiCennika) poz. bez ceny"
                    : "brutto, cennik kompletny"
                )
                .font(.caption2)
                .foregroundStyle(
                    brakiCennika > 0 ? Color.orange : Color.secondary
                )
            }
            .padding(.top, 2)
        }
    }

    private var podsumowanie:
        some View
    {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Divider()

            Label(
                "\(liczbaModulow) modułów",
                systemImage:
                    "square.stack.3d.up"
            )

            Label(
                "\(liczbaFormatek) formatek",
                systemImage:
                    "rectangle.split.3x1"
            )

            Label(
                statusGotowosciTekst,
                systemImage:
                    statusGotowosciSymbol
            )
            .foregroundStyle(
                statusGotowosciKolor
            )

            cenaPomieszczeniaV0103
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .stolarniaMaterial(.regularMaterial)
    }

    private var statusGotowosciTekst:
        String
    {
        if liczbaBlokadGotowosci > 0 {
            return "\(liczbaBlokadGotowosci) blokad"
        }

        if liczbaOstrzezenGotowosci > 0 {
            return "\(liczbaOstrzezenGotowosci) ostrzeżeń"
        }

        return "Gotowe do wyceny"
    }

    private var statusGotowosciSymbol:
        String
    {
        if liczbaBlokadGotowosci > 0 {
            return "xmark.octagon.fill"
        }

        if liczbaOstrzezenGotowosci > 0 {
            return "exclamationmark.triangle.fill"
        }

        return "checkmark.circle.fill"
    }

    private var statusGotowosciKolor:
        Color
    {
        if liczbaBlokadGotowosci > 0 {
            return .red
        }

        if liczbaOstrzezenGotowosci > 0 {
            return .orange
        }

        return .secondary
    }
}
