import Foundation
import Testing
@testable import DomainCore

struct FrontHardwareCalculatorTests {

    private typealias Kalk = FrontHardwareCalculator

    /// Front 600 × 700 × 18 z płyty wiórowej: 0,0075 m³ × 680 kg/m³ ≈ 5,1 kg.
    @Test
    func masaFrontuLiczySieZObjetosciIGestosci() {
        let masa = Kalk.frontMass(width: 600, height: 700)
        #expect(abs(masa - 5.14) < 0.05, "wyszło \(masa)")
    }

    /// Materiał realnie zmienia dobór — MDF jest wyraźnie cięższy od wiórowej.
    @Test
    func mdfJestCiezszyOdPlytyWiorowej() {
        let wiorowa = Kalk.frontMass(width: 600, height: 700, density: .chipboard)
        let mdf = Kalk.frontMass(width: 600, height: 700, density: .mdf)
        #expect(mdf > wiorowa)
        #expect(abs(mdf / wiorowa - 750.0 / 680.0) < 0.001)
    }

    /// Uchwyt, szkło albo listwa doliczają się do masy — podnośnik dobiera się
    /// do skrzydła realnego, nie do samej płyty.
    @Test
    func doliczkaWchodziDoMasy() {
        let bez = Kalk.frontMass(width: 600, height: 700)
        let z = Kalk.frontMass(width: 600, height: 700, extraLoad: 2.5)
        #expect(abs((z - bez) - 2.5) < 0.001)
    }

    /// Współczynnik mocy to wysokość × masa — nie sama masa i nie sama wysokość.
    /// Wysoki lekki front i niski ciężki mogą wymagać tego samego siłownika.
    @Test
    func wspolczynnikMocyLaczyWysokoscIMase() {
        let a = Kalk.selectLift(frontWidth: 600, frontHeight: 700)
        #expect(abs(a.powerFactor - 700 * a.frontMass) < 0.001)

        // Dwa różne fronty o zbliżonym współczynniku.
        let wysokiLekki = Kalk.selectLift(
            frontWidth: 400, frontHeight: 900, thickness: 16)
        let niskiCiezki = Kalk.selectLift(
            frontWidth: 900, frontHeight: 400, thickness: 16)
        #expect(wysokiLekki.frontMass == niskiCiezki.frontMass)
        // Ta sama masa, ale inny współczynnik — bo liczy się wysokość podnoszenia.
        #expect(wysokiLekki.powerFactor > niskiCiezki.powerFactor)
    }

    /// Szerokie fronty potrzebują dwóch siłowników, inaczej skrzydło się skręca.
    @Test
    func szerokiFrontDostajeUwageODwochSilownikach() {
        let szeroki = Kalk.selectLift(frontWidth: 1_000, frontHeight: 500)
        #expect(szeroki.issues.contains { $0.message.contains("dwa siłowniki") })

        let waski = Kalk.selectLift(frontWidth: 600, frontHeight: 500)
        #expect(!waski.issues.contains { $0.message.contains("dwa siłowniki") })
    }

    /// Ciężki front to ostrzeżenie o nośności i mocowaniu.
    @Test
    func ciezkiFrontJestOstrzezeniem() {
        // 1,2 × 1,2 × 0,022 m = 0,0317 m³ × 750 kg/m³ ≈ 23,8 kg.
        let ciezki = Kalk.selectLift(
            frontWidth: 1_200, frontHeight: 1_200, thickness: 22, density: .mdf)
        #expect(ciezki.frontMass > 20)
        #expect(ciezki.issues.contains { $0.severity == .warning })
    }

    /// Dobór zawsze wymaga potwierdzenia w tabeli producenta — wzór wskazuje
    /// współczynnik, nie konkretny SKU.
    @Test
    func doborZawszeWymagaPotwierdzeniaSKU() {
        #expect(Kalk.selectLift(frontWidth: 600, frontHeight: 700)
            .requiresSKUConfirmation)
    }

    // MARK: - Prowadnice

    /// Korpus 560: 560 − 20 pleców − 10 przód = 530 → najdłuższa mieszcząca 500.
    @Test
    func prowadnicaNieSiegaPlecow() {
        #expect(Kalk.runnerLength(forCabinetDepth: 560) == Millimeters(500))
        #expect(Kalk.runnerLength(forCabinetDepth: 600) == Millimeters(550))
        #expect(Kalk.runnerLength(forCabinetDepth: 350) == Millimeters(300))
    }

    /// Za płytki korpus nie dostaje prowadnicy na siłę.
    @Test
    func zaPlytkiKorpusNieDostajeProwadnicy() {
        #expect(Kalk.runnerLength(forCabinetDepth: 200) == nil)
    }

    /// Dobrana prowadnica nigdy nie może przekroczyć dostępnej głębokości.
    @Test
    func dobranaProwadnicaZawszeSieMiesci() {
        for glebokosc in [Millimeters(300), 350, 400, 450, 500, 560, 600, 650] {
            guard let p = Kalk.runnerLength(forCabinetDepth: glebokosc) else { continue }
            #expect(p <= glebokosc - Millimeters(30),
                    "prowadnica \(p) w korpusie \(glebokosc)")
        }
    }

    /// Niewykorzystana głębokość to realna strata przechowywania — projektant
    /// powinien ją widzieć.
    @Test
    func niewykorzystanaGlebokoscJestPoliczalna() {
        let p = Kalk.runnerLength(forCabinetDepth: 560)!
        #expect(Kalk.unusedDepth(cabinetDepth: 560, runner: p) == Millimeters(60))
    }

    @Test
    func doborProwadnicyNieUdajeWyboruSKU() throws {
        let dobor = try #require(Kalk.selectRunner(forCabinetDepth: 560))

        #expect(dobor.nominalLength == 500)
        #expect(dobor.unusedDepth == 60)
        #expect(dobor.requiresSKUConfirmation)
    }

    /// Dobór trzyma się drabinki **podanego systemu**, a nie ogólnej listy.
    ///
    /// **Poprawione 2026-08-27:** pierwsza wersja tego testu żądała prowadnicy
    /// 270 w korpusie 297 mm. Kalkulator zostawia 20 mm na plecy i 10 mm z przodu,
    /// więc przy 297 mm zostaje 267 mm — prowadnica **nie wchodzi**. Test
    /// utrwalałby zamówienie sztuki, która nie pasuje; to ta sama klasa błędu,
    /// którą złapaliśmy przy `hardwareList()` na korpusie 522 mm.
    @Test
    func doborProwadnicyRespektujeDrabinkeWybranegoSystemu() throws {
        // 320 − 20 − 10 = 290 → z drabinki [270, 300, 350] mieści się 270.
        let dobor = try #require(Kalk.selectRunner(
            forCabinetDepth: 320,
            availableLengths: [270, 300, 350]
        ))

        #expect(dobor.nominalLength == 270)
        #expect(dobor.requiresSKUConfirmation)
    }

    /// Korpus za płytki nie dostaje prowadnicy „na siłę".
    ///
    /// `nil` jest tu jedyną uczciwą odpowiedzią — zwrócenie najkrótszej
    /// z drabinki oznaczałoby zamówienie sztuki, która nie wejdzie.
    ///
    /// **Zaktualizowane 2026-08-27** po ujednoliceniu zapasu głębokości.
    /// Kalkulator miał własne 20 + 10 = 30 mm, niezależne od
    /// `DrawerProfile.requiredDepthMargin` (22 mm). Teraz liczy
    /// `backPanelThickness + requiredDepthMargin` = 25 mm, więc granica
    /// przesunęła się o 5 mm. Wartość z `DrawerProfile` jest prawdą, bo
    /// pochodzi z danych producenta.
    @Test
    func zaPlytkiKorpusNieDostajeProwadnicyZDrabinki() {
        // 294 − 25 = 269 → prowadnica 270 nie wchodzi.
        #expect(
            Kalk.selectRunner(
                forCabinetDepth: 294,
                availableLengths: [270, 300, 350]
            ) == nil
        )
    }

    /// Zapas kalkulatora i zapas doboru per system **muszą się zgadzać**.
    ///
    /// Obie drogi liczą to samo: ile głębokości zabiera plecy i luz montażowy.
    /// Rozjazd między nimi oznaczał prowadnicę dobraną inaczej zależnie od
    /// tego, którą funkcję wywołał generator.
    @Test
    func zapasGlebokosciJestJednaRegula() {
        #expect(
            Kalk.cabinetDepthAllowance
            == ProductionRules.backPanelThickness + DrawerProfile.requiredDepthMargin
        )

        // Ta sama głębokość → ta sama prowadnica obiema drogami.
        for glebokosc in stride(from: 300.0, through: 700.0, by: 1.0) {
            let gabaryt = Millimeters(glebokosc)
            let swiatlo = gabaryt - ProductionRules.backPanelThickness

            let zKalkulatora = Kalk.selectRunner(
                forCabinetDepth: gabaryt,
                availableLengths: DrawerProfile.nominalLengths(for: .gtvAxisPro)
            )?.nominalLength
            let zProfilu = DrawerProfile.nominalLength(
                for: .gtvAxisPro, cabinetInnerDepth: swiatlo
            )

            #expect(zKalkulatora == zProfilu,
                    "głębokość \(glebokosc): kalkulator \(String(describing: zKalkulatora)), profil \(String(describing: zProfilu))")
        }
    }
}
