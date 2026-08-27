//
//  StolarniaAppTests.swift
//  StolarniaAppTests
//
//  Created by Mateusz Wojciechowski on 15/06/2026.
//

import Foundation
import Testing
import DomainCore
@testable import StolarniaApp

/// Testy sięgają do typów UI (`PolozenieFormatkiV071`, katalogi), które są
/// związane z main actorem, więc cała suita musi być `@MainActor`.
/// Bez tego plik **nie kompilował się wcale** — regresje rozkroju i okleinowania
/// dopisane w lipcu 2026 nigdy nie zostały uruchomione.
@MainActor
struct StolarniaAppTests {

    @MainActor
    @Test func rozkrojWykorzystujeWolneProstokatyNaTymSamymArkuszu() async throws {
        let material = MaterialFormatkiV070(
            kod: "TEST",
            nazwa: "Płyta testowa",
            producent: "Test",
            kolorHEX: "#FFFFFF"
        )
        let list = ListaFormatekProjektuV070(
            nazwaProjektu: "Test rozkroju",
            dataUtworzenia: Date(),
            formatki: [
                formatka(
                    id: "a",
                    material: material,
                    dlugosc: 700,
                    szerokosc: 700
                ),
                formatka(
                    id: "b",
                    material: material,
                    dlugosc: 300,
                    szerokosc: 300
                ),
                formatka(
                    id: "c",
                    material: material,
                    dlugosc: 300,
                    szerokosc: 300
                ),
                formatka(
                    id: "d",
                    material: material,
                    dlugosc: 300,
                    szerokosc: 300
                )
            ]
        )
        let settings = UstawieniaRozkrojuPlytV071(
            szerokoscArkuszaMM: 1_000,
            dlugoscArkuszaMM: 1_000,
            rzazMM: 0,
            marginesMM: 0,
            uwzgledniajKierunekDekoru: true
        )

        let raport =
            RozkrojPlytEngineV071.build(
                list: list,
                settings: settings
            )

        #expect(raport.nierozmieszczone.isEmpty)
        #expect(raport.liczbaArkuszy == 1)
        #expect(raport.liczbaRozmieszczonychFormatek == 4)
        // Procent liczony z pól w mm daje 75,99999999999999 — porównanie
        // dokładne nie ma tu sensu. Ten test nigdy wcześniej nie został
        // uruchomiony, bo suita się nie kompilowała.
        #expect(abs(raport.wykorzystanieProcent - 76) < 0.001)
    }

    @MainActor
    @Test func rozkrojNieNakladaFormatekINieWychodziPozaArkusz() async throws {
        let material = MaterialFormatkiV070(
            kod: "TEST",
            nazwa: "Płyta testowa",
            producent: "Test",
            kolorHEX: "#FFFFFF"
        )
        let list = ListaFormatekProjektuV070(
            nazwaProjektu: "Kontrola geometrii rozkroju",
            dataUtworzenia: Date(),
            formatki: [
                formatka(id: "a", material: material, dlugosc: 920, szerokosc: 410),
                formatka(id: "b", material: material, dlugosc: 760, szerokosc: 360),
                formatka(id: "c", material: material, dlugosc: 640, szerokosc: 300),
                formatka(id: "d", material: material, dlugosc: 420, szerokosc: 280),
                formatka(id: "e", material: material, dlugosc: 390, szerokosc: 220)
            ]
        )
        let settings = UstawieniaRozkrojuPlytV071(
            szerokoscArkuszaMM: 1_250,
            dlugoscArkuszaMM: 1_250,
            rzazMM: 3.2,
            marginesMM: 10,
            uwzgledniajKierunekDekoru: false
        )

        let raport = RozkrojPlytEngineV071.build(
            list: list,
            settings: settings
        )

        #expect(raport.nierozmieszczone.isEmpty)

        for sheet in raport.arkusze {
            for placement in sheet.polozenia {
                #expect(placement.xMM >= settings.marginesMM)
                #expect(placement.yMM >= settings.marginesMM)
                #expect(
                    placement.xMM + placement.szerokoscNaArkuszuMM
                    <= sheet.szerokoscMM - settings.marginesMM + 0.001
                )
                #expect(
                    placement.yMM + placement.dlugoscNaArkuszuMM
                    <= sheet.dlugoscMM - settings.marginesMM + 0.001
                )
            }

            for leftIndex in sheet.polozenia.indices {
                for rightIndex in sheet.polozenia.indices
                where rightIndex > leftIndex {
                    #expect(
                        !nakladajaSie(
                            sheet.polozenia[leftIndex],
                            sheet.polozenia[rightIndex],
                            rzazMM: settings.rzazMM
                        )
                    )
                }
            }
        }
    }

    @MainActor
    @Test func okleinowaniePelnegoFrontuLiczyCzteryKrawedzie() async throws {
        let material = MaterialFormatkiV070(
            kod: "FRONT",
            nazwa: "Front testowy",
            producent: "Test",
            kolorHEX: "#332211"
        )
        let front = formatka(
            id: "front",
            material: material,
            dlugosc: 1_000,
            szerokosc: 500,
            rola: .front,
            kategoria: .front
        )

        let pozycja = OkleinowanieEngineV072.automatycznaPozycja(
            dla: front
        )
        let raport = OkleinowanieEngineV072.raport(
            nazwaProjektu: "Okleinowanie",
            pozycje: [pozycja],
            ustawienia: .standard
        )

        #expect(pozycja.liczbaOklejanychKrawedzi == 4)
        #expect(abs(pozycja.dlugoscNettoMM - 3_000) < 0.001)
        #expect(raport.zapotrzebowanie.count == 1)
        #expect(abs((raport.zapotrzebowanie.first?.dlugoscNettoM ?? 0) - 3) < 0.001)
    }

    private func formatka(
        id: String,
        material: MaterialFormatkiV070,
        dlugosc: Double,
        szerokosc: Double,
        rola: FurnitureComponentRole = .side,
        kategoria: KategoriaFormatkiV070 = .korpus
    ) -> FormatkaProjektuV070 {
        FormatkaProjektuV070(
            id: id,
            etykieta: id.uppercased(),
            indeksModulu: 1,
            nazwaModulu: "Moduł testowy",
            kodKomponentu: id.uppercased(),
            rolaKomponentu: rola,
            kategoria: kategoria,
            material: material,
            dlugoscMM: dlugosc,
            szerokoscMM: szerokosc,
            gruboscMM: 18,
            kierunekDekoru: .wzdluzDlugosci,
            wspoldzielona: false
        )
    }

    private func nakladajaSie(
        _ lhs: PolozenieFormatkiV071,
        _ rhs: PolozenieFormatkiV071,
        rzazMM: Double
    ) -> Bool {
        let leftMaxX =
            lhs.xMM + lhs.szerokoscNaArkuszuMM + rzazMM
        let rightMaxX =
            rhs.xMM + rhs.szerokoscNaArkuszuMM + rzazMM
        let leftMaxY =
            lhs.yMM + lhs.dlugoscNaArkuszuMM + rzazMM
        let rightMaxY =
            rhs.yMM + rhs.dlugoscNaArkuszuMM + rzazMM

        return lhs.xMM < rightMaxX
            && rhs.xMM < leftMaxX
            && lhs.yMM < rightMaxY
            && rhs.yMM < leftMaxY
    }

}

// MARK: - Propozycja ciągu kuchennego (V095)

/// Planer domenowy mówi „tu zlew 800", a mapper musi znaleźć dla tego realny
/// moduł w katalogu. Gdyby nie znajdował, przycisk „Wstaw ten układ" po cichu
/// nie wstawiałby nic — a build i tak by przechodził.
@MainActor
struct PropozycjaCiaguMapperTests {

    private func szablony() throws -> [FurnitureTemplate] {
        try StandardKitchenTemplatesV0143.make()
    }

    @Test func kazdySlotSprzetowyMaModulWKatalogu() throws {
        let templates = try szablony()
        let plan = KitchenLayoutProposer.proposeBaseRun(
            wallLength: 4_160,
            appliances: .init(hasIntegratedFridge: true))
        #expect(!plan.slots.isEmpty)

        for slot in plan.slots where slot.kind != .filler {
            let szablon = MapperPropozycjiCiaguV095.szablon(
                dla: slot, wSzablonach: templates)
            #expect(szablon != nil,
                    "brak modułu dla \(slot.kind.displayName) \(slot.width)")
        }
    }

    /// Blenda celowo nie ma odpowiednika — nie jest modułem katalogowym.
    @Test func blendaNieMaModuluIToJestZamierzone() throws {
        let slot = KitchenLayoutProposer.Slot(
            id: 0, kind: .filler, width: 80)
        #expect(MapperPropozycjiCiaguV095.szablon(
            dla: slot, wSzablonach: try szablony()) == nil)
    }

    /// Realna szerokość slotu trafia do danych modułu, nawet gdy katalog nie ma
    /// presetu dokładnie tej szerokości (np. korpus 605 mm po wchłonięciu blendy).
    @Test func realnaSzerokoscSlotuNadpisujeSzerokoscPresetu() throws {
        let templates = try szablony()
        let slot = KitchenLayoutProposer.Slot(
            id: 0, kind: .drawers, width: 605)
        let szablon = try #require(MapperPropozycjiCiaguV095.szablon(
            dla: slot, wSzablonach: templates))
        let dane = MapperPropozycjiCiaguV095.dane(
            dla: slot, szablon: szablon, offsetWzdluzSciany: 1_400)
        #expect(dane.width == Millimeters(605))
        #expect(dane.offsetAlongWall == Millimeters(1_400))
        #expect(dane.height > .zero)
        #expect(dane.depth > .zero)
    }

    /// Moduły muszą wypełnić ścianę bez nachodzenia: offset kolejnego zaczyna
    /// się dokładnie tam, gdzie kończy się poprzedni.
    @Test func offsetyModulowNieNachodzaNaSiebie() throws {
        let plan = KitchenLayoutProposer.proposeBaseRun(wallLength: 3_600)
        var offset = Millimeters.zero
        for slot in plan.slots {
            offset = offset + slot.width
        }
        #expect(offset == Millimeters(3_600))
    }
}

// MARK: - Przykładowa kuchnia od początku do końca (V095)

/// Przepuszcza kompletną kuchnię przez **prawdziwe silniki aplikacji**:
/// planer układu → mapper katalogowy → builder korpusów → kontrola produkcyjna
/// → lista formatek. Nic tu nie jest atrapą.
///
/// Powstało, bo dotąd każdy element łańcucha był testowany osobno, a nikt nie
/// sprawdził, czy da się przejść całą drogę od pustej ściany do formatek.
@MainActor
struct PrzykladowaKuchniaTests {

    /// Pomieszczenie 3600 × 2600 mm, ciąg na dłuższej ścianie.
    private func kuchnia() throws -> (RoomDefinition, WallSegment) {
        let obrys = try ClosedContour2D.rectangle(width: 3_600, height: 2_600)
        let sciany = try obrys.segments.enumerated().map { index, segment in
            try WallSegment(
                contourSegmentID: segment.id,
                name: "Ściana \(index + 1)",
                thickness: 120,
                startHeight: 2_600,
                constructionType: .masonry
            )
        }
        let geometria = try RoomGeometry(boundary: obrys, walls: sciany)
        let pomieszczenie = try RoomDefinition(
            projectID: ProjectID(),
            name: "Kuchnia przykładowa",
            geometry: geometria
        )
        // Najdłuższa ściana — tam idzie ciąg roboczy.
        let najdluzsza = try #require(
            sciany.max {
                (geometria.geometry(of: $0.id)?.length ?? .zero)
                    < (geometria.geometry(of: $1.id)?.length ?? .zero)
            })
        return (pomieszczenie, najdluzsza)
    }

    @Test func kompletnaKuchniaPrzechodziOdScianyDoFormatek() throws {
        let (pomieszczenie, sciana) = try kuchnia()
        let dlugosc = try #require(
            pomieszczenie.geometry.geometry(of: sciana.id)?.length)
        let szablony = try StandardKitchenTemplatesV0143.make()
            + StandardKitchenFinishingTemplatesV015.make()

        let plan = KitchenLayoutProposer.proposeBaseRun(
            wallLength: dlugosc,
            appliances: .init(hasIntegratedFridge: true))

        #expect(!plan.slots.isEmpty, "planer nie zaproponował nic dla \(dlugosc)")
        #expect(plan.totalWidth == dlugosc, "ciąg nie domyka ściany")

        var zbudowane: [FurnitureAssembly] = []
        var pominiete: [String] = []
        var offset = Millimeters.zero

        for slot in plan.slots {
            defer { offset = offset + slot.width }
            guard let szablon = MapperPropozycjiCiaguV095.szablon(
                dla: slot, wSzablonach: szablony) else {
                pominiete.append("\(slot.kind.displayName) \(Int(slot.width.rawValue))")
                continue
            }
            let dane = MapperPropozycjiCiaguV095.dane(
                dla: slot, szablon: szablon, offsetWzdluzSciany: offset)

            // Ta sama droga, którą idzie zapis modułu z ekranu.
            let parametry = try szablon.defaultParameters
                .setting(.millimeters(dane.width), for: .width)
                .setting(.millimeters(dane.height), for: .height)
                .setting(.millimeters(dane.depth), for: .depth)
            let builder: any FurnitureBuilding =
                StandardKitchenFinishingTemplatesV015.isFinishingTemplate(szablon)
                ? KitchenFillerBuilderV015()
                : ParametricFurnitureBuilderV077(
                    builderType: szablon.builderType,
                    assemblyKind: .cabinet)
            let zespol = try builder.build(
                template: szablon,
                parameters: parametry,
                preservingIDsFrom: nil)
            zbudowane.append(zespol)
        }

        // Po podpięciu blendy do szablonu wykończeniowego nic nie może zostać
        // pominięte — inaczej na ścianie zostaje fizyczna luka.
        #expect(pominiete.isEmpty, "pominięto: \(pominiete)")
        #expect(zbudowane.count >= 5, "zbudowano tylko \(zbudowane.count) korpusów")

        // Każdy korpus musi nadawać się na warsztat.
        for zespol in zbudowane {
            let bledy = AssemblyInspector.inspect(zespol)
                .filter { $0.severity == .error }
            #expect(bledy.isEmpty,
                    "\(zespol.name): \(bledy.map(\.message))")
        }

        // I musi z tego wyjść realna lista formatek.
        let formatki = zbudowane.flatMap(\.components)
        #expect(formatki.count > 20,
                "cała kuchnia dała tylko \(formatki.count) elementów")
        for f in formatki {
            #expect(ProductionRules.fitsOnSheet(f.size.width, f.size.height),
                    "\(f.code) \(f.size.width)×\(f.size.height) nie mieści się w arkuszu")
        }

        print("\n=== PRZYKŁADOWA KUCHNIA \(Int(dlugosc.rawValue)) mm ===")
        for zespol in zbudowane {
            print(String(format: "  %-28s %4.0f × %4.0f × %3.0f  · %d elementów",
                         (zespol.name as NSString).utf8String!,
                         zespol.size.width.rawValue,
                         zespol.size.height.rawValue,
                         zespol.size.depth.rawValue,
                         zespol.components.count))
        }
        print("  RAZEM: \(zbudowane.count) korpusów, \(formatki.count) elementów")
        if !pominiete.isEmpty { print("  pominięte: \(pominiete.joined(separator: ", "))") }
    }
}

// MARK: - Zabudowa pod schodami: mapowanie na katalog (V096)

/// Ekran zabudowy pod schodami opiera się na jednym presecie katalogowym.
/// Gdyby go zabrakło, przycisk „Wstaw zabudowę” byłby trwale wyłączony,
/// a build i tak by przechodził.
@MainActor
struct ZabudowaPodSchodamiTests {

    @Test func presetPodSchodyIstniejeWKatalogu() throws {
        let szablony = try StandardFurnitureModuleCatalogV077.make()
        let podSchody = szablony.first { szablon in
            StandardFurnitureModuleCatalogV077.preset(for: szablon.id)?.id
                == "under-stairs-built-in-2200"
        }
        #expect(podSchody != nil, "brak presetu zabudowy pod schodami")
    }

    /// Szafki z propozycji muszą dać się zbudować realnym builderem
    /// i przejść kontrolę produkcyjną.
    @Test func szafkiPodSchodamiPrzechodzaKontroleProdukcyjna() throws {
        let szablony = try StandardFurnitureModuleCatalogV077.make()
        let szablon = try #require(szablony.first { szablon in
            StandardFurnitureModuleCatalogV077.preset(for: szablon.id)?.id
                == "under-stairs-built-in-2200"
        })

        let bieg = StaircaseGeometry(rise: 175, going: 280, stepCount: 16)
        let szafki = bieg.proposeBays(bayWidth: 500)
        #expect(!szafki.isEmpty)

        for szafka in szafki {
            let parametry = try szablon.defaultParameters
                .setting(.millimeters(szafka.width), for: .width)
                .setting(.millimeters(szafka.height), for: .height)
            let builder = ParametricFurnitureBuilderV077(
                builderType: szablon.builderType, assemblyKind: .cabinet)
            let zespol = try builder.build(
                template: szablon, parameters: parametry, preservingIDsFrom: nil)

            let bledy = AssemblyInspector.inspect(zespol)
                .filter { $0.severity == .error }
            let opis = "\(Int(szafka.width.rawValue))×\(Int(szafka.height.rawValue)): "
                + bledy.map(\.message).joined(separator: "; ")
            #expect(bledy.isEmpty, "\(opis)")
        }
    }
}

// MARK: - Wydajność wyszukiwania presetów (V098)

/// `preset(for:)` robił liniowy skan katalogu z pełnym haszem FNV na element.
/// Widoki wołają to per szablon w ciele `body`, więc jedno przeliczenie
/// biblioteki kosztowało ok. 10,5 ms w buildzie -O — 0,6 klatki przy 60 fps.
/// Zamiana na indeks dała ~740×. Te testy pilnują, żeby indeks **nie zmienił
/// wyników** i żeby nikt nie wrócił do skanu.
@MainActor
struct IndeksPresetowTests {

    @Test func indeksKuchennyZwracaToSamoCoSkanLiniowy() throws {
        let szablony = try StandardKitchenTemplatesV0143.make()
        #expect(!szablony.isEmpty)

        for szablon in szablony {
            let zIndeksu = StandardKitchenTemplatesV0143.preset(for: szablon.id)
            #expect(zIndeksu != nil, "brak presetu dla \(szablon.code)")
        }
    }

    @Test func indeksOgolnyZwracaToSamoCoSkanLiniowy() throws {
        let szablony = try StandardFurnitureModuleCatalogV077.make()
        #expect(!szablony.isEmpty)

        for szablon in szablony {
            let zIndeksu = StandardFurnitureModuleCatalogV077.preset(for: szablon.id)
            #expect(zIndeksu != nil, "brak presetu dla \(szablon.code)")
        }
    }

    /// Nieznany identyfikator nadal daje `nil` — indeks nie może zwracać
    /// przypadkowego presetu przy pudle.
    @Test func nieznanyIdentyfikatorDajeNil() {
        let obcy = FurnitureTemplateID(rawValue: UUID())
        #expect(StandardKitchenTemplatesV0143.preset(for: obcy) == nil)
        #expect(StandardFurnitureModuleCatalogV077.preset(for: obcy) == nil)
    }

    /// Odwzorowanie musi być różnowartościowe — dwa presety o tym samym
    /// `templateID` oznaczałyby, że indeks po cichu gubi jeden z nich.
    @Test func identyfikatoryPresetowSaUnikalne() throws {
        let kuchenne = try StandardKitchenTemplatesV0143.make().map(\.id)
        #expect(Set(kuchenne).count == kuchenne.count, "kolizja ID w katalogu kuchennym")

        let ogolne = try StandardFurnitureModuleCatalogV077.make().map(\.id)
        #expect(Set(ogolne).count == ogolne.count, "kolizja ID w katalogu ogólnym")
    }

    // MARK: - Okucia zamawialne

    /// Pozycja okucia musi nieść **wymiar**, nie tylko system.
    ///
    /// „GTV • AXIS PRO • H120" nie wystarczy do zamówienia — prowadnica 450
    /// i 500 to dwa różne indeksy w hurtowni. Wartość istniała w karcie
    /// technicznej i była używana do grupowania pozycji, ale gubiła się przy
    /// budowaniu wyceny, bo `PozycjaOkuciaProjektuV068` nie miało na nią pola.
    @Test
    func pozycjaOkuciaNiesieWymiarDoZamowienia() {
        let pozycja = PozycjaOkuciaProjektuV068(
            profilID: "gtv.axis.pro",
            producent: "GTV",
            rodzina: "AXIS PRO",
            model: "H120",
            kategoria: .prowadnica,
            ilosc: 6,
            jednostka: "kpl.",
            cenaJednostkowaNetto: 0,
            zrodlo: "katalog-regul",
            nominalnaDlugoscMM: 500,
            wariantWysokosciMM: 120
        )

        let opis = pozycja.opisWymiaruV0103
        #expect(opis == "NL 500 mm · H120", "wyszło: \(opis ?? "nil")")
    }

    /// Bez wymiaru pozycja nie dokleja pustego separatora do nazwy.
    @Test
    func okucieBezWymiaruNieDoklejaPustegoOpisu() {
        let pozycja = PozycjaOkuciaProjektuV068(
            profilID: "blum.cliptop.110",
            producent: "Blum",
            rodzina: "CLIP top",
            model: "110°",
            kategoria: .zawias,
            ilosc: 12,
            jednostka: "szt.",
            cenaJednostkowaNetto: 9.5,
            zrodlo: "katalog-regul"
        )

        #expect(pozycja.opisWymiaruV0103 == nil)
    }

    /// Archiwa ofert sprzed tej zmiany nie mają nowych kluczy — muszą się
    /// nadal odczytywać, inaczej stare oferty przestałyby się otwierać.
    @Test
    func staraPozycjaOkuciaNadalSieDekoduje() throws {
        let json = """
        {
          "profilID": "gtv.axis.pro",
          "producent": "GTV",
          "rodzina": "AXIS PRO",
          "model": "H120",
          "kategoria": "prowadnica",
          "ilosc": 6,
          "jednostka": "kpl.",
          "cenaJednostkowaNetto": 0,
          "zrodlo": "katalog-regul"
        }
        """.data(using: .utf8)!

        let pozycja = try JSONDecoder().decode(
            PozycjaOkuciaProjektuV068.self,
            from: json
        )

        #expect(pozycja.model == "H120")
        #expect(pozycja.nominalnaDlugoscMM == nil)
        #expect(pozycja.opisWymiaruV0103 == nil)
    }

    // MARK: - Zawias niesymetryczny

    /// Front uchylny wystaje w światło **tylko po stronie zawiasu**.
    ///
    /// Do 2026-08-27 silnik stosował wartość dla strony zawiasu po obu
    /// stronach, bo strona nie docierała do karty. W korpusie 600 oddawało to
    /// kilka centymetrów szerokości skrzynki bez powodu.
    @Test
    func szufladaZaFrontemOdsuwaSieNiesymetrycznie() {
        var szuflada = SzufladaModulu(
            etykieta: "SZ-1",
            nazwa: "Szuflada 1",
            profilID: "gtv.axis.pro",
            typFrontu: .wewnetrzny
        )
        szuflada.odsuniecieStronaZawiasuMM = 21
        szuflada.odsuniecieStronaWolnaMM = 3

        #expect(szuflada.lacznaSzerokoscOdsunieciaV0104 == 24)
        #expect(szuflada.opisOdsunieciaV0104 == "zawias 21 mm / wolna 3 mm")
    }

    /// Nieznana strona zawiasu → zostajemy przy symetrii.
    ///
    /// Zgadnięcie strony byłoby gorsze niż jej brak: skrzynka wyszłaby
    /// odsunięta w złą stronę i nie zmieściłaby się przy zawiasie.
    @Test
    func nieznanaStronaZawiasuZostajePrzySymetrii() {
        var szuflada = SzufladaModulu(
            etykieta: "SZ-1",
            nazwa: "Szuflada 1",
            profilID: "gtv.axis.pro",
            typFrontu: .wewnetrzny
        )
        szuflada.odsuniecieOdScianBocznychMM = 21

        #expect(szuflada.odsuniecieStronaZawiasuMM == nil)
        #expect(szuflada.lacznaSzerokoscOdsunieciaV0104 == 42)
        #expect(szuflada.opisOdsunieciaV0104 == "21 mm/strona")
    }
}
