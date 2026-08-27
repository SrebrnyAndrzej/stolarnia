import Foundation
import Testing
@testable import DomainCore

struct DecorSurfaceTests {

    /// Sedno zmiany: dekor o kodzie zamiast nazwy opisowej ma dostać poprawną
    /// powierzchnię. Wcześniej renderer szukał w nazwie słowa „dab"/„oak",
    /// więc `K358` albo „Silk Flow" nie trafiały w żaden wzorzec.
    @Test
    func kodStrukturyDecydujeNieNazwaDekoru() {
        let pw = DecorSurfaceCatalog.resolve(structureCode: "PW", group: "Drewno")
        #expect(pw.family == .wood)
        #expect(pw.synchronisedPore, "Pure Wood ma por zsynchronizowany")
        #expect(pw.embossDepth > 0.5)
    }

    /// Grupa dekoru wygrywa z domyślną rodziną struktury — ST9 występuje
    /// zarówno na uni, jak i na drewnie.
    @Test
    func grupaNadpisujeDomyslnaRodzineStruktury() {
        let uni = DecorSurfaceCatalog.resolve(structureCode: "ST9", group: "Uni")
        let drewno = DecorSurfaceCatalog.resolve(structureCode: "ST9", group: "Drewno")
        #expect(uni.family == .uni)
        #expect(drewno.family == .wood)
        // Parametry powierzchni zostają te same — zmienia się tylko rysunek.
        #expect(uni.glossLevel == drewno.glossLevel)
        #expect(uni.embossDepth == drewno.embossDepth)
    }

    /// Struktury łączące mat i połysk mają wyraźnie żywsze usłojenie —
    /// tak je opisuje producent i tak muszą się renderować.
    @Test
    func deepskinExcellentMaZywszeUslojenieNizRough() {
        let rough = DecorSurfaceCatalog.byStructure["ST10"]!
        let excellent = DecorSurfaceCatalog.byStructure["ST19"]!
        #expect(excellent.grainContrast > rough.grainContrast)
        #expect(excellent.glossLevel > rough.glossLevel)
    }

    /// Feelwood to pory zsynchronizowane z nadrukiem — najdroższa i najbardziej
    /// charakterystyczna cecha struktury.
    @Test
    func tylkoFeelwoodIPureWoodMajaPorZsynchronizowany() {
        let zsynchronizowane = DecorSurfaceCatalog.byStructure
            .filter { $0.value.synchronisedPore }
            .keys.sorted()
        #expect(zsynchronizowane == ["PW", "ST37", "ST38", "ST40"])
    }

    /// Połysk rośnie w oczekiwanej kolejności: super mat → mat → supreme → brilliant.
    @Test
    func poziomPolyskuRosnieWZgodzieZOpisemProducenta() {
        let k = DecorSurfaceCatalog.byStructure
        #expect(k["SM"]!.glossLevel < k["ST9"]!.glossLevel)
        #expect(k["ST9"]!.glossLevel < k["SU"]!.glossLevel)
        #expect(k["SU"]!.glossLevel < k["BS"]!.glossLevel)
    }

    /// Nieznana albo pusta struktura nie może dać błyszczącej płyty —
    /// mat pomylony z połyskiem razi dużo bardziej niż odwrotnie.
    @Test
    func nieznanaStrukturaDajeMatNiePolysk() {
        for kod in [nil, "", "   ", "XYZ99"] {
            let p = DecorSurfaceCatalog.resolve(structureCode: kod, group: nil)
            #expect(p.glossLevel < 0.15, "\(String(describing: kod)) dało połysk")
        }
    }

    /// Kod struktury bywa zapisany małymi literami albo ze spacjami.
    @Test
    func kodStrukturyJestOdpornyNaZapis() {
        let a = DecorSurfaceCatalog.resolve(structureCode: "st37", group: "Drewno")
        let b = DecorSurfaceCatalog.resolve(structureCode: "  ST37 ", group: "Drewno")
        #expect(a == b)
        #expect(a.synchronisedPore)
    }

    /// Grupy z bazy materiałów muszą się mapować mimo polskich znaków.
    @Test
    func grupyZBazyMaterialowSaRozpoznawane() {
        #expect(DecorSurfaceCatalog.family(forGroup: "Kamień") == .stone)
        #expect(DecorSurfaceCatalog.family(forGroup: "Drewno") == .wood)
        #expect(DecorSurfaceCatalog.family(forGroup: "Uni") == .uni)
        // „Materiał" to zbiorcza grupa techniczna — najbliżej jej do betonu.
        #expect(DecorSurfaceCatalog.family(forGroup: "Materiał") == .concrete)
        #expect(DecorSurfaceCatalog.family(forGroup: "cokolwiek") == nil)
    }
}
