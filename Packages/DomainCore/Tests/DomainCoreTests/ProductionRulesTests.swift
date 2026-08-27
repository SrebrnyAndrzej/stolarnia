import Foundation
import Testing
@testable import DomainCore

struct ProductionRulesTests {

    // MARK: - Reguły

    @Test
    func frontToFrontGapIsTwiceTheClearance() {
        #expect(
            ProductionRules.frontToFrontGap
                == ProductionRules.frontClearancePerEdge * 2)
        #expect(ProductionRules.frontToFrontGap == Millimeters(4))
    }

    /// Podziałka 600 → front 596. To jest ta liczba, którą hurtownia dostaje
    /// w zamówieniu, więc regresja tutaj kosztuje materiał.
    @Test
    func frontWidthFollowsModulePitch() {
        #expect(ProductionRules.frontWidth(forModulePitch: 600) == Millimeters(596))
        #expect(ProductionRules.frontWidth(forModulePitch: 696) == Millimeters(692))
        #expect(ProductionRules.frontHeight(forCarcassHeight: 900) == Millimeters(896))
    }

    @Test
    func hingeCountGrowsWithFrontHeight() {
        #expect(ProductionRules.hingeCount(forFrontHeight: 700) == 2)
        #expect(ProductionRules.hingeCount(forFrontHeight: 900) == 3)
        #expect(ProductionRules.hingeCount(forFrontHeight: 1_996) == 4)
    }

    @Test
    func sheetFitIgnoresOrientation() {
        #expect(ProductionRules.fitsOnSheet(2_700, 2_000))
        #expect(ProductionRules.fitsOnSheet(2_000, 2_700))
        // 3560 mm okładziny nie da się wyciąć z arkusza 2800 × 2070.
        #expect(!ProductionRules.fitsOnSheet(3_560, 200))
    }

    // MARK: - Pomocnicy

    private func front(
        code: String,
        x: Millimeters,
        width: Millimeters,
        height: Millimeters = 700
    ) throws -> FurnitureComponent {
        try FurnitureComponent(
            code: code,
            role: .front,
            size: Size3MM(width: width, height: height, depth: 18),
            localPosition: Point3MM(x: x, y: 2, z: .zero)
        )
    }

    private func assembly(
        width: Millimeters = 1_200,
        height: Millimeters = 720,
        _ components: [FurnitureComponent]
    ) throws -> FurnitureAssembly {
        try FurnitureAssembly(
            name: "Test",
            kind: .cabinet,
            size: Size3MM(width: width, height: height, depth: 560),
            components: components
        )
    }

    // MARK: - Kontrola zespołu

    /// Regresja klasy błędu, która przeżyła kilkanaście przebiegów renderu
    /// w generatorze dokumentacji: nachodzące fronty wyglądają jak jedna płyta,
    /// więc nikt nie zauważył, że nie są osobnymi skrzydłami.
    @Test
    func overlappingFrontsAreAnError() throws {
        let asm = try assembly([
            front(code: "FR-1", x: 2, width: 700),
            front(code: "FR-2", x: 600, width: 598)
        ])
        let issues = AssemblyInspector.inspect(asm)
        #expect(issues.contains { $0.severity == .error })
        #expect(issues.contains { $0.message.contains("nachodzą") })
        #expect(!AssemblyInspector.isBuildable(asm))
    }

    @Test
    func correctlySpacedFrontsAreClean() throws {
        // Dwa moduły po 600: fronty 596, fuga 4, po 2 mm na licach skrajnych.
        let asm = try assembly([
            front(code: "FR-1", x: 2, width: 596),
            front(code: "FR-2", x: 602, width: 596)
        ])
        let issues = AssemblyInspector.inspect(asm)
        #expect(!issues.contains { $0.severity == .error })
        #expect(AssemblyInspector.isBuildable(asm))
    }

    @Test
    func wrongGapIsAWarningNotAnError() throws {
        // 8 mm w fudze — klasyczny skutek podania 4 tam, gdzie oczekiwany
        // jest luz na lico.
        let asm = try assembly([
            front(code: "FR-1", x: 4, width: 592),
            front(code: "FR-2", x: 604, width: 592)
        ])
        let issues = AssemblyInspector.inspect(asm)
        #expect(issues.contains { $0.severity == .warning })
        #expect(!issues.contains { $0.severity == .error })
    }

    @Test
    func componentOutsideAssemblyIsAnError() throws {
        let asm = try assembly(width: 600, [
            front(code: "FR-1", x: 2, width: 900)
        ])
        let issues = AssemblyInspector.inspect(asm)
        #expect(issues.contains { $0.severity == .error && $0.componentCode == "FR-1" })
    }

    @Test
    func panelTooBigForSheetIsAnError() throws {
        let maskownica = try FurnitureComponent(
            code: "MASK",
            role: .front,
            size: Size3MM(width: 3_560, height: 200, depth: 18),
            localPosition: Point3MM(x: .zero, y: .zero, z: .zero)
        )
        let asm = try assembly(width: 3_560, height: 200, [maskownica])
        let issues = AssemblyInspector.inspect(asm)
        #expect(issues.contains { $0.message.contains("nie mieści się w arkuszu") })
    }

    /// Fronty jeden nad drugim mają tę samą współrzędną X — poziomej fugi
    /// między nimi nie ma i kontrola nie może jej wymyślać.
    @Test
    func stackedFrontsInSameColumnAreNotComparedHorizontally() throws {
        let asm = try assembly(width: 600, height: 1_400, [
            front(code: "FR-DOL", x: 2, width: 596, height: 696),
            front(code: "FR-GORA", x: 2, width: 596, height: 696)
        ])
        let issues = AssemblyInspector.inspect(asm)
        #expect(!issues.contains { $0.message.contains("fuga") })
        #expect(!issues.contains { $0.message.contains("nachodzą") })
    }

    // MARK: - Kontrola na module z kreatora rysunkowego

    /// Spina kreator z kontrolą: moduł rysowany w elewacji przechodzi przez
    /// `makeAssembly`, a wynik przez `AssemblyInspector`. To jest ta sama
    /// droga, którą idzie każda zmiana w `ModulEdytorElewacjiView`.
    @Test
    func modulZKreatoraPrzechodziKontrole() throws {
        let modul = ElevationModule(
            width: 600,
            splits: [400],
            zones: [
                ElevationZone(kind: .drawers, drawerCount: 2),
                ElevationZone(kind: .doors)
            ]
        )
        let zespol = try modul.makeAssembly(named: "Kontrola")
        #expect(!zespol.components.isEmpty)

        let uwagi = AssemblyInspector.inspect(zespol)
        // Moduł zbudowany przez domenę nie może mieć elementów poza gabarytem
        // ani formatek większych niż arkusz — to byłby błąd buildera.
        let powazne = uwagi.filter { $0.severity == .error }
        #expect(powazne.isEmpty, "błędy: \(powazne.map(\.message))")
    }

    /// Szeroka zabudowa JAKO JEDEN MODUŁ jest niewykonalna i kontrola musi to
    /// powiedzieć.
    ///
    /// Pierwsza wersja tego testu zakładała, że moduł 4160 mm przejdzie czysto —
    /// błędne założenie. Taka bryła daje dno 4124×560 i plecy 4124×684, czego
    /// nie da się wyciąć z arkusza 2800×2070. Ciąg 4160 mm w projekcie Kamień
    /// to kilka korpusów, nie jeden. Kreator pozwala narysować go jako jeden
    /// moduł i właśnie po to jest ta kontrola.
    @Test
    func jedenSzerokiModulJestZglaszanyJakoNiewykonalny() throws {
        let modul = ElevationModule(width: 4_160, splits: [], zones: [
            ElevationZone(kind: .doors)
        ])
        let zespol = try modul.makeAssembly(named: "N-03 jako jeden moduł")
        let uwagi = AssemblyInspector.inspect(zespol)

        #expect(!AssemblyInspector.isBuildable(zespol))
        #expect(uwagi.contains { $0.message.contains("nie mieści się w arkuszu") })
    }

    /// Ten sam ciąg rozbity na korpusy mieszczące się w arkuszu przechodzi czysto.
    @Test
    func korpusMieszczacySieWArkuszuPrzechodziCzysto() throws {
        let modul = ElevationModule(width: 710, splits: [], zones: [
            ElevationZone(kind: .doors)
        ])
        let zespol = try modul.makeAssembly(named: "N-03 pierwszy korpus")
        let powazne = AssemblyInspector.inspect(zespol)
            .filter { $0.severity == .error }
        #expect(powazne.isEmpty, "błędy: \(powazne.map(\.message))")
    }
}

/// Fronty nakładane muszą wynikać z reguł produkcyjnych, a nie z liczb
/// zaszytych w generatorze. Ta suita utrwala regułę, żeby nikt nie wrócił
/// do liczenia frontu od światła korpusu z magiczną trójką.
struct FrontGeometryRulesTests {

    /// Front jednokolumnowy zakrywa moduł: podziałka minus fuga.
    @Test
    func frontJednokolumnowyMaSzerokoscPodzialkiMinusFuga() {
        for szerokosc in [Millimeters(400), 500, 600, 800, 900] {
            let modul = ElevationModule(width: szerokosc)
            #expect(modul.frontWidth(forColumns: 1)
                    == ProductionRules.frontWidth(forModulePitch: szerokosc))
        }
    }

    /// Przy wielu kolumnach fronty dzielą lico, zostawiając między sobą
    /// dokładnie jedną fugę.
    @Test
    func frontyWKolumnachZostawiajaDokladnieJednaFuge() {
        let modul = ElevationModule(width: 600)
        for kolumny in 1...4 {
            let w = modul.frontWidth(forColumns: kolumny)
            let pierwszy = modul.frontX(forColumn: 0, of: kolumny)
            let ostatni = modul.frontX(forColumn: kolumny - 1, of: kolumny)

            // Lico zaczyna się i kończy luzem 2 mm.
            #expect(pierwszy == ProductionRules.frontClearancePerEdge)
            #expect(abs((ostatni + w).rawValue
                        - (600 - ProductionRules.frontClearancePerEdge.rawValue)) < 0.01,
                    "kolumny \(kolumny): prawa krawędź \(ostatni + w)")

            // Fuga między sąsiadami.
            if kolumny > 1 {
                let a = modul.frontX(forColumn: 0, of: kolumny) + w
                let b = modul.frontX(forColumn: 1, of: kolumny)
                #expect(abs((b - a).rawValue
                            - ProductionRules.frontToFrontGap.rawValue) < 0.01,
                        "kolumny \(kolumny): fuga \(b - a)")
            }
        }
    }

    /// **Regresja klasy błędu:** front o poprawnej szerokości, ale liczony
    /// od wnętrza korpusu, wychodził poza gabaryt. Zbudowany moduł musi mieć
    /// wszystkie fronty w obrysie.
    @Test
    func frontyMieszczaSieWGabarycieModulu() throws {
        for kolumny in 1...3 {
            for szerokosc in [Millimeters(400), 600, 900] {
                let modul = ElevationModule(
                    width: szerokosc,
                    zones: [ElevationZone(kind: .doors, columns: kolumny)])
                let zespol = try modul.makeAssembly()
                for f in zespol.components where f.role == .front {
                    #expect(f.localPosition.x >= .zero)
                    let opis = "\(szerokosc)/\(kolumny): \(f.code) do "
                        + "\(f.localPosition.x + f.size.width)"
                    #expect(f.localPosition.x + f.size.width <= szerokosc, "\(opis)")
                }
            }
        }
    }
}

extension ProductionRulesTests {

    /// Rząd frontów zabiera **dwa luzy i n − 1 fug**, nie n + 1 fug.
    ///
    /// Podgląd przestrzenny karty liczył `(W − fuga × (n + 1)) / n` i rysował
    /// fronty o 2 mm węższe od tych, które wychodzą z listy formatek. Front
    /// nakładany jest cofnięty od krawędzi o luz (2 mm), a nie o fugę (4 mm).
    @Test
    func rzadFrontowZajmujeDwaLuzyIFugiMiedzyNimi() {
        // Moduł 600, jeden front: 600 − 2 − 2 = 596.
        #expect(ProductionRules.frontWidth(forModulePitch: 600, columns: 1)
                == Millimeters(596))
        // Dwa fronty: 600 − 4 luzu − 4 fugi = 592, po 296.
        #expect(ProductionRules.frontWidth(forModulePitch: 600, columns: 2)
                == Millimeters(296))
    }

    /// Fronty plus fugi plus luzy muszą dać dokładnie podziałkę modułu —
    /// inaczej albo widać korpus, albo skrzydła się ocierają.
    @Test
    func rzadFrontowDomykaPodzialkeModulu() {
        for podzialka in [Millimeters(400), 600, 800, 900] {
            for n in 1...4 {
                let front = ProductionRules.frontWidth(
                    forModulePitch: podzialka, columns: n)
                let suma = front * Double(n)
                    + ProductionRules.frontToFrontGap * Double(n - 1)
                    + ProductionRules.frontClearancePerEdge * 2
                #expect(abs(suma.rawValue - podzialka.rawValue) < 0.001,
                        "podziałka \(podzialka), \(n) frontów → \(suma)")
            }
        }
    }

    /// Jeden front to szczególny przypadek rzędu — obie funkcje muszą się
    /// zgadzać, bo są używane zamiennie.
    @Test
    func jedenFrontZgadzaSieZWariantemBezKolumn() {
        for podzialka in [Millimeters(300), 600, 1_200] {
            #expect(ProductionRules.frontWidth(forModulePitch: podzialka, columns: 1)
                    == ProductionRules.frontWidth(forModulePitch: podzialka))
        }
    }
}

/// Skrzynka szuflady jako osobna rola komponentu.
struct RolaSkrzynkiSzufladyTests {

    /// Dno skrzynki nie może udawać „elementu własnego".
    ///
    /// Z rolą `.custom` nie dało się go odróżnić od dowolnej listwy w rozkroju
    /// i BOM. A skrzynka rządzi się innymi regułami: inna grubość, inne
    /// obrzeże, i przy systemach z gotową skrzynką (Amix Slim Box, LEGRABOX)
    /// te formatki w ogóle nie idą na piłę.
    @Test
    func dnoSzufladyMaRoleSkrzynki() throws {
        var modul = ElevationModule(
            name: "Dolna 600 · 3 szuflady",
            width: 600, height: 720, depth: 560,
            zones: [ElevationZone(kind: .drawers, drawerCount: 3)]
        )
        modul.name = "Dolna 600"

        let zespol = try modul.makeAssembly()
        let dna = zespol.components.filter { $0.code.contains("DNOSZ") }

        #expect(!dna.isEmpty, "moduł z szufladami nie wygenerował den skrzynek")
        for dno in dna {
            #expect(dno.role == .drawerBox,
                    "\(dno.code) ma rolę \(dno.role), nie .drawerBox")
        }
    }

    /// Nowa rola nie psuje odczytu zapisanych modułów.
    ///
    /// `FurnitureComponentRole` jest `Codable` po `String`, więc stare rekordy
    /// nigdy nie mają nowej wartości — ale warto to utrwalić, bo dopisanie
    /// przypadku do enuma bywa robione w drugą stronę (zmiana istniejącej
    /// nazwy), a to już psuje archiwa.
    @Test
    func staraRolaKomponentuNadalSieDekoduje() throws {
        let json = #"{"role":"custom"}"#.data(using: .utf8)!
        struct Opakowanie: Codable { let role: FurnitureComponentRole }
        let odczytane = try JSONDecoder().decode(Opakowanie.self, from: json)
        #expect(odczytane.role == .custom)
    }
}
