import Foundation
import Testing
@testable import DomainCore

struct DrawerBehindDoorPlannerTests {

    private typealias Planer = DrawerBehindDoorPlanner

    /// Sedno researchu: **problem jest niesymetryczny**. Front wystaje tylko po
    /// stronie zawiasu, więc odsuwanie skrzynki po obu stronach oddaje miejsce
    /// bez powodu.
    @Test
    func wcieciePowstajeTylkoPoStronieZawiasu() {
        for zawias in Planer.HingeBehaviour.allCases {
            let plan = Planer.plan(.init(innerWidth: 564, hinge: zawias))
            #expect(plan.freeSideInset == .zero,
                    "\(zawias) zabiera miejsce po stronie wolnej")
            #expect(plan.hingeSideInset > .zero)
        }
    }

    /// Zwykły zawias zostaje w świetle i zabiera pas grubości frontu plus luz.
    /// Front 18 mm → 21 mm, co odpowiada „martwej strefie" 12,7–19 mm
    /// z literatury powiększonej o zapas na regulację.
    @Test
    func zwyklyZawiasZabieraGruboscFrontuPlusLuz() {
        let plan = Planer.plan(.init(
            innerWidth: 564, hinge: .standard, doorThickness: 18))
        #expect(plan.hingeSideInset == Millimeters(21))
        #expect(plan.usableWidth == Millimeters(543))
    }

    /// Zero-protrusion 155° odrzuca skrzydło poza światło — zostaje sam luz.
    @Test
    func zeroProtrusion155ZostawiaSamLuz() {
        let plan = Planer.plan(.init(
            innerWidth: 564, hinge: .zeroProtrusion155, doorThickness: 18))
        #expect(plan.hingeSideInset == Planer.safetyGap)
        #expect(plan.usableWidth == Millimeters(561))
    }

    /// Warunek, którego aplikacja wcześniej nie znała wcale: zero-protrusion
    /// wymaga nakładki min. 16 mm (5/8″). Poniżej progu zawias **nie spełnia
    /// obietnicy** i liczymy jak zwykły — to błąd, nie ostrzeżenie, bo
    /// projektant dostałby szufladę ocierającą o front.
    @Test
    func zaMalaNakladkaUniewazniaZeroProtrusion() {
        let plan = Planer.plan(.init(
            innerWidth: 564, hinge: .zeroProtrusion155,
            doorThickness: 18, doorOverlay: 10))

        #expect(plan.issues.contains { $0.severity == .error })
        #expect(plan.issues.contains { $0.message.contains("nakładka") })
        // Liczone jak przy zwykłym zawiasie.
        #expect(plan.hingeSideInset == Millimeters(21))
    }

    @Test
    func nakladkaDokladnieNaProgiuJestJeszczeDobra() {
        let plan = Planer.plan(.init(
            innerWidth: 564, hinge: .zeroProtrusion155,
            doorThickness: 18,
            doorOverlay: Planer.minimumOverlayForZeroProtrusion))
        #expect(!plan.issues.contains { $0.severity == .error })
        #expect(plan.hingeSideInset == Planer.safetyGap)
    }

    /// Wariant 155° ma limit grubości frontu 24 mm — grubszy front to
    /// ostrzeżenie i obowiązek potwierdzenia SKU, nie cicha zgoda.
    @Test
    func grubyFrontPrzyZeroProtrusion155JestOstrzezeniem() {
        let plan = Planer.plan(.init(
            innerWidth: 564, hinge: .zeroProtrusion155, doorThickness: 28))
        #expect(plan.issues.contains {
            $0.severity == .warning && $0.message.contains("przekracza")
        })
    }

    /// Za wąski korpus nie może po cichu dać szuflady o zerowej szerokości.
    @Test
    func zaWaskiKorpusJestBledem() {
        let plan = Planer.plan(.init(
            innerWidth: 15, hinge: .standard, doorThickness: 18))
        #expect(plan.usableWidth == .zero)
        #expect(plan.issues.contains { $0.severity == .error })
    }

    /// Liczba, która uzasadnia dopłatę do lepszego zawiasu: w korpusie 600
    /// zero-protrusion odzyskuje 18 mm szerokości skrzynki.
    @Test
    func zyskZZeroProtrusionJestPoliczalny() {
        let zysk = Planer.widthGainFromZeroProtrusion(innerWidth: 564)
        #expect(zysk == Millimeters(18))
    }

    /// Zysk nie zależy od światła korpusu — to zawsze ta sama grubość frontu.
    @Test
    func zyskNieZalezyOdSzerokosciKorpusu() {
        let waski = Planer.widthGainFromZeroProtrusion(innerWidth: 364)
        let szeroki = Planer.widthGainFromZeroProtrusion(innerWidth: 864)
        #expect(waski == szeroki)
    }

    /// Zero-protrusion 125° odrzuca skrzydło ciaśniej niż 155°, więc potrzebuje
    /// więcej zapasu — ale nadal wyraźnie mniej niż zwykły zawias.
    @Test
    func wariant125JestMiedzyZwyklymA155() {
        let szerokosc = Millimeters(564)
        let zwykly = Planer.plan(.init(innerWidth: szerokosc, hinge: .standard))
        let w125 = Planer.plan(.init(innerWidth: szerokosc, hinge: .zeroProtrusion125))
        let w155 = Planer.plan(.init(innerWidth: szerokosc, hinge: .zeroProtrusion155))

        #expect(w155.hingeSideInset < w125.hingeSideInset)
        #expect(w125.hingeSideInset < zwykly.hingeSideInset)
    }
}
