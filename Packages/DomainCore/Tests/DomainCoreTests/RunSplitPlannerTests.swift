import Foundation
import Testing
@testable import DomainCore

struct RunSplitPlannerTests {

    /// Korpus mieszczący się w limicie zostaje jednym korpusem — planer nie może
    /// dzielić dla samego dzielenia.
    @Test
    func waskiCiagZostajeJednymKorpusem() {
        let plan = RunSplitPlanner.plan(runWidth: 710)
        #expect(plan.count == 1)
        #expect(plan.widths == [Millimeters(710)])
        #expect(!RunSplitPlanner.needsSplit(runWidth: 710))
    }

    /// Ciąg N-03 z projektu Kamień: 4160 mm. To ten sam przypadek, który
    /// `AssemblyInspector` zgłasza jako niewykonalny — planer ma podać wyjście.
    @Test
    func ciagCztery160DzieliSieNaPiecKorpusow() {
        let plan = RunSplitPlanner.plan(runWidth: 4_160)
        #expect(plan.count == 5)          // ceil(4160 / 900)
        #expect(plan.widths.allSatisfy { $0 <= RunSplitPlanner.maxShelfSpan })
        #expect(RunSplitPlanner.needsSplit(runWidth: 4_160))
    }

    /// Podziałki muszą sumować się DOKŁADNIE do szerokości ciągu. Ciąg ma
    /// wypełnić ścianę — brakujący milimetr to szpara przy blendzie.
    @Test
    func podzialkiSumujaSieDokladnieDoSzerokosciCiagu() {
        for szerokosc in [Millimeters(4_160), 3_750, 3_560, 2_510, 1_001, 899] {
            let plan = RunSplitPlanner.plan(runWidth: szerokosc)
            let suma = plan.widths.reduce(Millimeters.zero, +)
            #expect(suma == szerokosc, "\(szerokosc) → \(plan.widths)")
        }
    }

    /// Reszta rozdzielana po milimetrze, więc korpusy różnią się co najwyżej
    /// o krok siatki — nie o całą resztę wrzuconą w ostatni moduł.
    @Test
    func korpusyRozniaSieCoNajwyzejOKrokSiatki() {
        let plan = RunSplitPlanner.plan(runWidth: 4_163, grid: 10)
        let najwiekszy = plan.widths.max()!.rawValue
        let najmniejszy = plan.widths.min()!.rawValue
        #expect(najwiekszy - najmniejszy <= 10)
    }

    /// Podział narzucony przez projektanta jest wykonywany, ale planer mówi
    /// wprost, że półka się ugnie — decyzja zostaje po stronie człowieka.
    @Test
    func narzuconyPodzialOstrzegaOUgieciuPolki() {
        let plan = RunSplitPlanner.plan(runWidth: 4_160, count: 2)
        #expect(plan.count == 2)
        #expect(plan.reason.contains("rozpiętości półki"))
    }

    @Test
    func narzuconyPodzialOstrzegaOZaWaskimKorpusie() {
        let plan = RunSplitPlanner.plan(runWidth: 800, count: 4)
        #expect(plan.widths == Array(repeating: Millimeters(200), count: 4))
        #expect(plan.reason.contains("okucia nie wejdą"))
    }

    @Test
    func zerowyCiagNieProdukujeKorpusow() {
        #expect(RunSplitPlanner.plan(runWidth: 0).widths.isEmpty)
    }

    /// Spina planer z kontrolą: korpusy z propozycji muszą przejść
    /// `AssemblyInspector` czysto. Bez tego planer mógłby proponować podział,
    /// który nadal się nie da wykonać.
    @Test
    func korpusyZProponowanegoPodzialuPrzechodzaKontroleCzysto() throws {
        let plan = RunSplitPlanner.plan(runWidth: 4_160)
        for (i, szerokosc) in plan.widths.enumerated() {
            let modul = ElevationModule(
                width: szerokosc, splits: [], zones: [ElevationZone(kind: .doors)])
            let zespol = try modul.makeAssembly(named: "N-03/\(i + 1)")
            let bledy = AssemblyInspector.inspect(zespol)
                .filter { $0.severity == .error }
            #expect(bledy.isEmpty,
                    "korpus \(szerokosc): \(bledy.map(\.message))")
        }
    }
}
