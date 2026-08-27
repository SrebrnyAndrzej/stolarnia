import DomainCore
import SwiftUI

/// Pulpit warsztatu — kafle zamiast menu w menu.
///
/// ## Co było nie tak
///
/// Ekran startowy był **menu prowadzącym do menu**. Boczny pasek o szerokości
/// 290 punktów trzymał dwie pozycje („Klienci i projekty", „Firma i bazy"),
/// a wybranie drugiej dawało kolejną listę czterech. Do „Bazy materiałów"
/// szło się przez dwa poziomy listy, choć w aplikacji jest **sześć miejsc
/// razem**. Ćwierć szerokości ekranu była wydana na wybór binarny.
///
/// To jest przy tym pierwszy ekran, jaki się widzi — więc ustawiał wrażenie
/// całego narzędzia jako spisu treści.
///
/// ## Dlaczego kafle nie są równe
///
/// Kuszące jest zrobić sześć jednakowych kwadratów. Byłoby to ładne i błędne:
/// projekty to jest **ta praca**, a bazy i ustawienia odwiedza się co kilka
/// dni. Równe kafle mówiłyby, że dalmierz jest tak samo ważny jak zlecenie
/// klienta.
///
/// Dlatego projekty dostają siatkę dużych kafli i całą górę ekranu, a bazy
/// wąski rząd na dole. Wszystko jest **na jedno stuknięcie**, ale wielkość
/// niesie częstotliwość.
struct PulpitStolarniV0105: View {

    let projekty: [WorkshopProject]
    let ladowanie: Bool
    let onOtworzProjekt: (WorkshopProject) -> Void
    let onNowyProjekt: () -> Void
    let onOtworzBaze: (KafelBazyV0105) -> Void

    /// Ile projektów pokazać, zanim pojawi się wejście do pełnej listy.
    ///
    /// Dwanaście to trzy pełne rzędy na iPadzie w poziomie. Więcej zmienia
    /// pulpit w listę, a od list właśnie odchodzimy.
    private static let maksKafliProjektow = 12

    private var widoczneProjekty: [WorkshopProject] {
        Array(projekty.prefix(Self.maksKafliProjektow))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                naglowek
                sekcjaProjektow
                sekcjaBaz
            }
            .padding(24)
        }
        .background(PulpitTloV0106())
        .foregroundStyle(StolarniaPalette.paper)
        // Pulpit jest ciemny **zawsze**, niezależnie od trybu systemu.
        // To nie jest ekran do czytania długiego tekstu, tylko blat warsztatu:
        // ciemne tło pozwala kaflom świecić i zgadza się z tożsamością marki
        // (antracyt + limonka), która na jasnym tle po prostu nie istnieje.
        .environment(\.colorScheme, .dark)
        .stolarniaReadableInterface()
    }

    // MARK: - Nagłówek

    private var naglowek: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                EtykietaNadrzednaV0106(tekst: "Warsztat")
                Text("Stolarnia")
                    .font(.system(size: 44, weight: .semibold))
                    // Ujemny odstęp liter przy dużym stopniu pisma — duże
                    // wersaliki systemowej kroju bez tego wyglądają na
                    // rozstrzelone. Poniżej ok. 30 pt nie robi się tego wcale.
                    .tracking(-0.8)
                Text(podpisNaglowka)
                    .font(.subheadline)
                    .foregroundStyle(StolarniaPalette.stone.opacity(0.8))
            }

            Spacer(minLength: 16)

            przyciskNowegoProjektu
        }
    }

    /// Przycisk główny z ikoną **w osobnym kółku**.
    ///
    /// Ikona postawiona goło obok napisu czyta się jak znak przestankowy.
    /// Zamknięta we własnym kręgu staje się elementem przycisku i daje mu
    /// wewnętrzną strukturę — to drobiazg, którego się nie zauważa, a który
    /// odróżnia przycisk zaprojektowany od domyślnego.
    private var przyciskNowegoProjektu: some View {
        Button(action: onNowyProjekt) {
            HStack(spacing: 12) {
                Text("Nowy projekt")
                    .font(.headline)

                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(.black.opacity(0.18)))
            }
            .padding(.leading, 22)
            .padding(.trailing, 8)
            .frame(minHeight: 56)
            .foregroundStyle(StolarniaPalette.anthracite)
            .background(
                Capsule().fill(StolarniaPalette.lime)
            )
            .overlay(
                // Rozświetlenie górnej krawędzi także tutaj — przycisk jest
                // bryłą oświetloną z góry, tak samo jak kafle.
                Capsule().strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.45), .clear],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            )
            .shadow(color: StolarniaPalette.lime.opacity(0.28), radius: 18, y: 6)
        }
        .stolarniaPressable()
    }

    private var podpisNaglowka: String {
        if ladowanie && projekty.isEmpty { return "Wczytywanie…" }
        if projekty.isEmpty { return "Zacznij od pierwszego zlecenia" }
        return projekty.count == 1
            ? "1 projekt"
            : "\(projekty.count) projektów"
    }

    // MARK: - Projekty

    @ViewBuilder
    private var sekcjaProjektow: some View {
        if projekty.isEmpty && !ladowanie {
            pustyStan
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 260, maximum: 380), spacing: 16)],
                alignment: .leading,
                spacing: 16
            ) {
                ForEach(Array(widoczneProjekty.enumerated()), id: \.element.id) { indeks, projekt in
                    Button {
                        onOtworzProjekt(projekt)
                    } label: {
                        kafelProjektu(projekt, wyrozniony: indeks == 0)
                    }
                    .stolarniaPressable(skala: 0.985)
                }
            }

            if projekty.count > Self.maksKafliProjektow {
                Text("Pokazane \(widoczneProjekty.count) z \(projekty.count) — resztę znajdziesz w wyszukiwaniu.")
                    .font(.caption)
                    .foregroundStyle(StolarniaPalette.steel.opacity(0.85))
            }
        }
    }

    /// Kafel projektu.
    ///
    /// Pierwszy w siatce jest **wyróżniony** — obudowa dostaje limonkowy
    /// odcień zamiast neutralnego. To jest bento w praktyce: hierarchia niesiona
    /// wyglądem, nie tylko kolejnością. Projekt na górze listy to ten, przy
    /// którym się siedzi, więc ma się wyróżniać zanim przeczyta się nazwę.
    private func kafelProjektu(
        _ projekt: WorkshopProject,
        wyrozniony: Bool = false
    ) -> some View {
        PodwojnaRamkaV0106(promien: 24, obudowa: 6, wyrozniony: wyrozniony) {
            trescKafla(projekt)
        }
    }

    private func trescKafla(_ projekt: WorkshopProject) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(projekt.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Text(projekt.code.rawValue)
                    .font(.caption2.monospaced())
                    .foregroundStyle(StolarniaPalette.steel.opacity(0.8))
            }

            Text(projekt.customer.displayName)
                .font(.subheadline)
                .foregroundStyle(StolarniaPalette.stone.opacity(0.78))
                .lineLimit(1)

            Spacer(minLength: 0)

            // Status z ikoną i słowem — kolor nigdy nie jest jedynym
            // nośnikiem znaczenia (reguła UX projektu).
            Label(
                projekt.status.displayName,
                systemImage: projekt.status.ikonaV0105
            )
            .font(.footnote.weight(.medium))
            .foregroundStyle(projekt.status.kolorV0105)
            .padding(.horizontal, 10)
            .frame(minHeight: 32)
            .background(
                Capsule().fill(projekt.status.kolorV0105.opacity(0.14))
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
    }

    private var pustyStan: some View {
        PodwojnaRamkaV0106(promien: 24, obudowa: 6) {
            trescPustegoStanu
        }
    }

    private var trescPustegoStanu: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Brak projektów", systemImage: "folder")
                .font(.title3.weight(.semibold))
            // Pusty ekran mówi, co zrobić dalej — reguła UX projektu.
            Text("Zacznij od „Nowy projekt”. Pomiar, wycena i rozkrój wezmą się z niego same.")
                .font(.callout)
                .foregroundStyle(StolarniaPalette.stone.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Bazy

    private var sekcjaBaz: some View {
        VStack(alignment: .leading, spacing: 10) {
            EtykietaNadrzednaV0106(tekst: "Firma i bazy")

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 190, maximum: 280), spacing: 12)],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(KafelBazyV0105.allCases) { kafel in
                    Button {
                        onOtworzBaze(kafel)
                    } label: {
                        // Mniejszy promień i cieńsza obudowa niż przy
                        // projektach — kafel bazy jest mniejszy, więc te same
                        // wartości wyglądałyby na nim jak gruba rama.
                        PodwojnaRamkaV0106(promien: 16, obudowa: 4) {
                            kafelBazy(kafel)
                        }
                    }
                    .stolarniaPressable()
                }
            }
        }
    }

    private func kafelBazy(_ kafel: KafelBazyV0105) -> some View {
        HStack(spacing: 12) {
            Image(systemName: kafel.ikona)
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(StolarniaPalette.lime)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(kafel.tytul)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(kafel.podtytul)
                    .font(.caption)
                    .foregroundStyle(StolarniaPalette.stone.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
    }
}

/// Bazy dostępne z pulpitu — te same cztery co w dawnym menu „Firma".
enum KafelBazyV0105: String, CaseIterable, Identifiable {
    case ustawienia
    case materialy
    case okucia
    case dalmierz

    var id: String { rawValue }

    /// Tytuły są **krótsze niż w dawnym menu**.
    ///
    /// „Baza materiałów i cennik płyt" w kaflu łamie się na trzy linie i zjada
    /// całą jego wysokość. Szczegół idzie do podtytułu; kafel ma być rozpoznany
    /// rzutem oka, a nie przeczytany.
    var tytul: String {
        switch self {
        case .ustawienia: return "Firma i ustawienia"
        case .materialy:  return "Materiały"
        case .okucia:     return "Okucia"
        case .dalmierz:   return "Dalmierz"
        }
    }

    var podtytul: String {
        switch self {
        case .ustawienia: return "Stawki, dane do dokumentów"
        case .materialy:  return "Płyty, wzorniki, ceny"
        case .okucia:     return "Zawiasy, prowadnice, cargo"
        case .dalmierz:   return "HOTO D50 przez Bluetooth"
        }
    }

    var ikona: String {
        switch self {
        case .ustawienia: return "gearshape.2"
        case .materialy:  return "square.grid.2x2"
        case .okucia:     return "shippingbox"
        case .dalmierz:   return "dot.radiowaves.left.and.right"
        }
    }
}

extension KafelBazyV0105 {
    /// Odpowiednik w dawnym menu „Firma".
    ///
    /// Kafel jest nowym wejściem do **tych samych ekranów** — nic nie zostało
    /// przepisane, zmienia się tylko droga. Dzięki temu podmiana jest
    /// odwracalna jedną flagą.
    var dawnaSekcjaV0105: PanelFirmySekcja {
        switch self {
        case .ustawienia: return .ustawienia
        case .materialy:  return .materialy
        case .okucia:     return .okucia
        case .dalmierz:   return .dalmierz
        }
    }
}

extension ProjectStatus {
    /// Ikona etapu — status nie może być niesiony samym kolorem.
    var ikonaV0105: String {
        switch self {
        case .inquiry:              return "envelope"
        case .measurementScheduled: return "calendar"
        case .measurementCompleted: return "ruler"
        case .designing:            return "pencil.and.outline"
        case .offerSent:            return "paperplane"
        case .accepted:             return "checkmark.seal"
        case .readyForProduction:   return "shippingbox"
        case .installation:         return "wrench.and.screwdriver"
        case .handover:             return "key"
        case .service:              return "arrow.clockwise"
        case .archived:             return "archivebox"
        }
    }

    /// Kolor etapu — trzy grupy, nie jedenaście odcieni.
    ///
    /// Jedenaście kolorów to nie jest informacja, tylko szum. Liczy się jedno
    /// rozróżnienie: **czy projekt czeka na mnie, czy jest w robocie,
    /// czy jest zamknięty.**
    var kolorV0105: Color {
        switch self {
        case .inquiry, .measurementScheduled, .offerSent:
            return .orange
        case .measurementCompleted, .designing, .accepted,
             .readyForProduction, .installation:
            return StolarniaPalette.accentStrong
        case .handover, .service, .archived:
            // Na ciemnym tle `.secondary` gaśnie do nieczytelności —
            // etap zamknięty ma być stonowany, nie niewidoczny.
            return StolarniaPalette.steel
        }
    }
}
