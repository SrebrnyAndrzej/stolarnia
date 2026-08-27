import SwiftUI
import DomainCore
import Persistence

/// Jedno okno modułu o strukturze teczki dokumentacji technicznej.
///
/// **Zastępuje łańcuch okien.** Dotąd po wybraniu modułu na elewacji
/// nakładały się na siebie: panel zaznaczenia, `SzybkiEdytorModuluV083`, panel
/// systemu przesuwnego — a potem `Edytuj` otwierał pełny ekran edytora,
/// z którego dokumentacja techniczna była **jeszcze jednym** pełnym ekranem.
/// Na elewacji wisiało pięć równoległych stanów prezentacji.
///
/// Porządek sekcji jest celowo taki sam jak w teczce dokumentacji technicznej
/// (przegląd → rysunek → produkcja). Dzięki temu układ ekranu i układ wydruku
/// mówią tym samym językiem: projektant szukający „gdzie są formatki" szuka
/// w tym samym miejscu na ekranie i w PDF-ie.
struct KartaModuluV097: View {

    enum Sekcja: String, CaseIterable, Identifiable {
        case przeglad
        case rysunek
        case naroznik
        case produkcja

        var id: String { rawValue }

        var nazwa: String {
            switch self {
            case .przeglad:  return "Przegląd"
            case .rysunek:   return "Rysunek"
            case .naroznik:  return "Narożnik"
            case .produkcja: return "Produkcja"
            }
        }

        var ikona: String {
            switch self {
            case .przeglad:  return "square.text.square"
            case .rysunek:   return "ruler"
            case .naroznik:  return "square.split.bottomrightquarter"
            case .produkcja: return "shippingbox"
            }
        }
    }

    let stored: StoredFurnitureAssembly
    @ObservedObject var mebleViewModel: MeblePomieszczeniaViewModel
    let wall: WallSegment
    let room: RoomDefinition
    /// Definicje narożników jako **wiązanie**, nie kopia.
    ///
    /// Sekcja `Narożnik` hostuje `CornerCabinetEditorV025`, który zapisuje
    /// zmiany przez `@Binding`. Sekcja `Produkcja` czyta te same dane, żeby
    /// arkusz A4 pokazywał martwą strefę i kopertę ruchu mechanizmu zgodnie
    /// z tym, co przed chwilą ustawiono w sekcji obok.
    @Binding var cornerDefinitions: [CornerCabinetDefinitionV025]
    /// Czy ten moduł jest narożnikiem — decyduje o widoczności sekcji.
    ///
    /// Rozpoznanie zostaje po stronie elewacji, bo to ona zna szablon modułu;
    /// karta dostaje gotową odpowiedź zamiast zgadywać z nazwy drugi raz.
    let jestNaroznikiem: Bool
    let onZamknij: () -> Void
    let onZapiszModul: (ElevationModule) async -> Bool

    @State private var sekcja: Sekcja = .przeglad

    private var zespol: FurnitureAssembly { stored.assembly }

    private var zastrzezenia: [ProductionIssue] {
        mebleViewModel.zastrzezeniaProdukcyjne[zespol.id] ?? []
    }

    /// Sekcje w **lewym pasku**, nie w segmentowanym przełączniku.
    ///
    /// Segment w `ToolbarItem(.principal)` bije się o miejsce z tytułem modułu:
    /// przy nazwie w rodzaju „Zabudowa pod schodami 500×1240" na węższym iPadzie
    /// jedno z dwóch zostaje ucięte. Pasek daje pełne słowa z ikonami, jest tym
    /// samym językiem nawigacji co `WorkspaceNawigacjaV074` (Plan/Elewacja/3D)
    /// i zniesie kolejne sekcje — wizualizację i wycenę — bez ściskania.
    var body: some View {
        NavigationSplitView {
            List(selection: Binding(
                get: { sekcja },
                set: { sekcja = $0 ?? sekcja }
            )) {
                Section("Dokumentacja") {
                    ForEach(dostepneSekcje) { s in
                        Label(s.nazwa, systemImage: s.ikona)
                            .frame(minHeight: 52)
                            .tag(s)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(zespol.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij", action: onZamknij)
                }
            }
        } detail: {
            Group {
                switch sekcja {
                case .przeglad:  sekcjaPrzegladu
                case .rysunek:   sekcjaRysunku
                case .naroznik:  sekcjaNaroznika
                case .produkcja: sekcjaProdukcji
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(sekcja.nazwa)
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - A. Przegląd

    private var sekcjaPrzegladu: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !zastrzezenia.isEmpty {
                    sekcjaZastrzezen
                }
                kafelkiGabarytu
                if mebleViewModel.template(for: stored) != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        naglowek("Szybkie zmiany")
                        SzybkiEdytorModuluV083(
                            storedAssembly: stored,
                            mebleViewModel: mebleViewModel,
                            wall: wall,
                            room: room
                        )
                    }
                }
                listaKomponentow
            }
            .padding(16)
        }
    }

    private var kafelkiGabarytu: some View {
        VStack(alignment: .leading, spacing: 8) {
            naglowek("Gabaryt")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 140), spacing: 12)],
                spacing: 12
            ) {
                kafelek("Szerokość", "\(Int(zespol.size.width.rawValue)) mm")
                kafelek("Wysokość", "\(Int(zespol.size.height.rawValue)) mm")
                kafelek("Głębokość", "\(Int(zespol.size.depth.rawValue)) mm")
                kafelek("Elementów", "\(zespol.components.count)")
            }
        }
    }

    private func kafelek(_ etykieta: String, _ wartosc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(etykieta)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(wartosc)
                .font(.title3.monospacedDigit().weight(.semibold))
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(StolarniaPalette.canvasRaised)
        )
    }

    /// Kontrola produkcyjna jest **na samej górze przeglądu**, a nie schowana
    /// w produkcji — problem ma być widoczny, zanim projektant zacznie zmieniać
    /// wymiary. Ikona i słowo, nie sam kolor.
    private var sekcjaZastrzezen: some View {
        let bledy = zastrzezenia.filter { $0.severity == .error }
        return VStack(alignment: .leading, spacing: 6) {
            Label(
                bledy.isEmpty ? "Do sprawdzenia" : "Tego nie da się zbudować",
                systemImage: bledy.isEmpty
                    ? "exclamationmark.triangle" : "xmark.octagon.fill"
            )
            .font(.callout.weight(.semibold))
            .foregroundStyle(bledy.isEmpty ? Color.orange : Color.red)

            ForEach(Array(zastrzezenia.prefix(5).enumerated()), id: \.offset) { _, u in
                VStack(alignment: .leading, spacing: 1) {
                    Text(u.componentCode.map { "\($0): \(u.message)" } ?? u.message)
                        .font(.callout)
                    if !u.hint.isEmpty {
                        Text(u.hint).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill((bledy.isEmpty ? Color.orange : Color.red).opacity(0.10))
        )
    }

    private var listaKomponentow: some View {
        VStack(alignment: .leading, spacing: 8) {
            naglowek("Elementy")
            ForEach(zespol.components, id: \.code) { element in
                HStack(alignment: .top, spacing: 10) {
                    Text(element.code)
                        .font(.caption.monospaced())
                        .frame(width: 110, alignment: .leading)
                    Text("\(Int(element.size.width.rawValue))×"
                         + "\(Int(element.size.height.rawValue))×"
                         + "\(Int(element.size.depth.rawValue))")
                        .font(.callout.monospacedDigit())
                    Spacer(minLength: 0)
                    Text(element.role.opisRoliV097)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 52)
            }
        }
    }

    // MARK: - B. Rysunek

    /// Edytor rysunkowy zajmuje cały obszar sekcji — **nie otwiera nowego okna**.
    /// Wcześniej `Edytuj` był kolejnym `fullScreenCover` nad już otwartym.
    private var sekcjaRysunku: some View {
        ModulEdytorElewacjiView(
            modul: .reconstructed(from: zespol),
            onZapisz: onZapiszModul
        )
    }

    /// Narożnik dostaje własną sekcję zamiast własnego okna.
    ///
    /// Dotąd moduły narożne omijały tę kartę: elewacja otwierała im wprost
    /// `CornerCabinetEditorV025` jako osobny sheet. Skutek był taki, że
    /// jedyny rodzaj szafki z martwą strefą, kopertą ruchu mechanizmu
    /// i blendą technologiczną **nie miał ani rysunku, ani produkcji, ani
    /// kontroli produkcyjnej na górze przeglądu** — czyli był pozbawiony
    /// dokładnie tego, co przy narożniku najłatwiej policzyć źle.
    private var sekcjaNaroznika: some View {
        CornerCabinetEditorV025(
            assemblies: [zespol],
            definitions: $cornerDefinitions
        )
    }

    /// Sekcja `Narożnik` pojawia się tylko tam, gdzie coś znaczy.
    private var dostepneSekcje: [Sekcja] {
        Sekcja.allCases.filter { $0 != .naroznik || jestNaroznikiem }
    }

    // MARK: - C. Produkcja

    private var sekcjaProdukcji: some View {
        KartyTechniczneModulowV028(
            assemblies: [zespol],
            cornerDefinitions: cornerDefinitions
        )
    }

    private func naglowek(_ tekst: String) -> some View {
        Text(tekst.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

extension FurnitureComponentRole {
    /// Krótki opis roli do listy elementów.
    var opisRoliV097: String {
        switch self {
        case .side:           return "bok"
        case .bottom:         return "dno"
        case .top:            return "wieniec"
        case .shelf:          return "półka"
        case .back:           return "plecy"
        case .front:          return "front"
        case .divider:        return "przegroda"
        case .worktop:        return "blat"
        case .plinth:         return "cokół"
        case .filler:         return "blenda"
        case .maskingPanel:   return "maskownica"
        case .decorativeSide: return "bok dekoracyjny"
        case .rail:           return "drążek"
        case .reinforcement:  return "wzmocnienie"
        case .leg:            return "nóżka"
        case .drawerBox:      return "skrzynka szuflady"
        case .custom:         return "element własny"
        }
    }
}
