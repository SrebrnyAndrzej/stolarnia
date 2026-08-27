import Foundation
import Testing
@testable import DomainCore

struct StaircaseGeometryTests {

    /// Typowy bieg domowy: 17,5 × 28, 16 stopni — wzorcowy przykład z normy.
    private var typowy: StaircaseGeometry {
        StaircaseGeometry(rise: 175, going: 280, stepCount: 16)
    }

    @Test
    func wzorcowyBiegPrzechodziKontroleCzysto() {
        let uwagi = typowy.inspect()
        #expect(uwagi.isEmpty, "\(uwagi.map(\.message))")
        // 2h + s = 2*175 + 280 = 630, czyli dokładnie cel Blondela.
        #expect(typowy.blondelValue == StaircaseGeometry.blondelTarget.rawValue)
    }

    @Test
    func gabarytyBieguSaPoliczalne() {
        #expect(typowy.totalRun == Millimeters(4_480))
        #expect(typowy.totalRise == Millimeters(2_800))
        #expect(abs(typowy.angleDegrees - 32.0) < 0.5)
    }

    /// Za wysoki stopień to błąd normowy, nie kwestia gustu.
    @Test
    func zaWysokiStopienJestBledem() {
        let strome = StaircaseGeometry(rise: 210, going: 240, stepCount: 14)
        let uwagi = strome.inspect()
        #expect(uwagi.contains { $0.severity == .error && $0.message.contains("stopień") })
        #expect(uwagi.contains { $0.severity == .error && $0.message.contains("głębokość") })
    }

    /// Bieg spełniający wymiary graniczne, ale łamiący Blondela, jest tylko
    /// ostrzeżeniem — da się go zbudować, chodzi się po nim źle.
    @Test
    func zlamanieBlondelaJestOstrzezeniemNieBledem() {
        let dziwny = StaircaseGeometry(rise: 150, going: 400, stepCount: 12)
        let uwagi = dziwny.inspect()
        #expect(!uwagi.contains { $0.severity == .error })
        #expect(uwagi.contains { $0.message.contains("2h+s") })
    }

    // MARK: - Obwiednia

    /// Obwiednia liczy się po spodzie biegu, więc jest niższa o grubość policzka.
    @Test
    func obwiedniaUwzgledniaGruboscPoliczka() {
        let s = StaircaseGeometry(rise: 175, going: 280, stepCount: 16,
                                  stringerThickness: 40)
        // Na 280 mm (jeden stopień) linia biegu ma 175 mm, minus policzek 40.
        #expect(s.availableHeight(atDistance: 280) == Millimeters(135))
    }

    @Test
    func pozaRzutemBieguNieMaZabudowy() {
        #expect(typowy.availableHeight(atDistance: -10) == .zero)
        #expect(typowy.availableHeight(atDistance: 9_000) == .zero)
    }

    /// **Sedno zabudowy pod schodami:** szafka jest prostopadłościanem, więc
    /// musi zmieścić się w NAJNIŻSZYM punkcie swojego zakresu. Branie wyższego
    /// końca to klasyczny błąd kończący się szafką wchodzącą w policzek.
    @Test
    func wysokoscSzafkiBierzeSieZNizszegoKonca() {
        let s = typowy
        let od = Millimeters(1_000), do_ = Millimeters(1_500)
        let h = s.maximumCabinetHeight(from: od, to: do_)
        #expect(h == s.availableHeight(atDistance: od))
        #expect(h < s.availableHeight(atDistance: do_))
    }

    // MARK: - Propozycja szafek

    @Test
    func propozycjaDajeSzafkiOMalejacejWysokosci() {
        let bays = typowy.proposeBays(bayWidth: 500)
        #expect(bays.count >= 4)
        // Idąc od najniższej strony biegu wysokości muszą rosnąć.
        let wysokosci = bays.sorted { $0.offset < $1.offset }.map(\.height)
        for (a, b) in zip(wysokosci, wysokosci.dropFirst()) {
            #expect(a < b, "wysokości nie rosną wzdłuż biegu: \(wysokosci)")
        }
    }

    /// Szafki nie mogą nachodzić na siebie ani wychodzić poza rzut biegu.
    @Test
    func szafkiNieNachodzaINieWychodzaPozaBieg() {
        for szerokosc in [Millimeters(400), 500, 600, 900] {
            let bays = typowy.proposeBays(bayWidth: szerokosc)
                .sorted { $0.offset < $1.offset }
            for (a, b) in zip(bays, bays.dropFirst()) {
                #expect(a.offset + a.width <= b.offset + Millimeters(0.001),
                        "nachodzą przy podziałce \(szerokosc)")
            }
            for bay in bays {
                #expect(bay.offset >= .zero)
                #expect(bay.offset + bay.width <= typowy.totalRun + Millimeters(0.001))
            }
        }
    }

    /// Za niska przestrzeń nie dostaje szafki na siłę — tam idzie front rewizyjny.
    @Test
    func zaNiskaPrzestrzenNieDostajeSzafki() {
        let bays = typowy.proposeBays(bayWidth: 500, minimumHeight: 300)
        #expect(bays.allSatisfy { $0.height >= Millimeters(300) })
        // Pierwszy odcinek przy najniższym stopniu jest za niski i wypada.
        #expect(bays.first!.offset > .zero || typowy.ascent == .toLeft)
    }

    /// Luz pod spodem biegu jest realnie odejmowany — bez niego korpus dociska
    /// się do konstrukcji.
    @Test
    func luzJestOdejmowanyOdWysokosci() {
        let bez = typowy.proposeBays(bayWidth: 500, clearance: 0)
        let z = typowy.proposeBays(bayWidth: 500, clearance: 20)
        let hBez = bez.first { $0.offset == z.first!.offset }!.height
        #expect(z.first!.height == hBez - Millimeters(20))
    }

    /// Bieg w lewo to lustrzane odbicie — offsety muszą się zgadzać z montażem.
    @Test
    func biegWLewoOdbijaOffsety() {
        let wPrawo = StaircaseGeometry(rise: 175, going: 280, stepCount: 16,
                                       ascent: .toRight)
        let wLewo = StaircaseGeometry(rise: 175, going: 280, stepCount: 16,
                                      ascent: .toLeft)
        let p = wPrawo.proposeBays(bayWidth: 500)
        let l = wLewo.proposeBays(bayWidth: 500)

        #expect(p.count == l.count)
        // Ta sama liczba szafek i te same wysokości, tylko w odwrotnej kolejności.
        #expect(p.map(\.height).sorted() == l.map(\.height).sorted())
        #expect(p.map(\.height) != l.map(\.height))
    }
}
