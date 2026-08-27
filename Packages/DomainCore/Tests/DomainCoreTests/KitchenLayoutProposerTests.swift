import Foundation
import Testing
@testable import DomainCore

struct KitchenLayoutProposerTests {

    /// Najważniejsza własność: propozycja **wypełnia ścianę co do milimetra**.
    /// Ciąg, który nie domyka się do ściany, zostawia szparę przy blendzie.
    @Test
    func propozycjaWypelniaScianeCoDoMilimetra() {
        for dlugosc in [Millimeters(3_600), 4_160, 2_510, 3_750, 1_805, 1_400] {
            let plan = KitchenLayoutProposer.proposeBaseRun(wallLength: dlugosc)
            #expect(!plan.slots.isEmpty, "\(dlugosc) nie dostała propozycji")
            #expect(plan.totalWidth == dlugosc,
                    "\(dlugosc) → \(plan.totalWidth) (\(plan.slots.map(\.width)))")
        }
    }

    /// Kolejność wynika z drogi pracy: lodówka poza strefą roboczą, zmywarka
    /// przy zlewie (wspólna instalacja), piekarnik na końcu.
    @Test
    func zmywarkaStoiObokZlewu() {
        let plan = KitchenLayoutProposer.proposeBaseRun(wallLength: 3_600)
        let rodzaje = plan.slots.map(\.kind)
        let zlew = rodzaje.firstIndex(of: .sink)
        let zmywarka = rodzaje.firstIndex(of: .dishwasher)
        #expect(zlew != nil && zmywarka != nil)
        #expect(zmywarka! == zlew! + 1, "kolejność: \(rodzaje)")
    }

    /// Ściana krótsza niż ciąg roboczy nie dostaje propozycji na siłę —
    /// planer mówi wprost, że to nie jest miejsce na kuchnię.
    @Test
    func zaKrotkaScianaNieDostajeCiagu() {
        let plan = KitchenLayoutProposer.proposeBaseRun(wallLength: 700)
        #expect(plan.slots.isEmpty)
        #expect(plan.reason.contains("za krótka"))
        #expect(!plan.warnings.isEmpty)
    }

    /// Przy 1200 mm mieści się już tylko zlew — reszta sprzętu jest zdejmowana,
    /// ale propozycja powstaje i wypełnia ścianę.
    @Test
    func sprzetSzerszyNizScianaJestZdejmowanyPoKolei() {
        let plan = KitchenLayoutProposer.proposeBaseRun(
            wallLength: 1_200,
            appliances: .init(hasSink: true, hasDishwasher: true,
                              hasOven: true, hasHob: true,
                              hasIntegratedFridge: true))
        #expect(plan.totalWidth == Millimeters(1_200))
        #expect(plan.slots.contains { $0.kind == .sink })
        #expect(!plan.slots.contains { $0.kind == .fridge })
        #expect(plan.warnings.contains { $0.contains("poza ciągiem zostało") })
    }

    /// Wybory AGD z pierwszego kroku faktycznie zmieniają propozycję.
    @Test
    func wyboryAGDZmieniajaPropozycje() {
        let zLodowka = KitchenLayoutProposer.proposeBaseRun(
            wallLength: 3_600, appliances: .init(hasIntegratedFridge: true))
        let bezLodowki = KitchenLayoutProposer.proposeBaseRun(
            wallLength: 3_600, appliances: .init(hasIntegratedFridge: false))
        #expect(zLodowka.slots.contains { $0.kind == .fridge })
        #expect(!bezLodowki.slots.contains { $0.kind == .fridge })
        // Obie i tak wypełniają ścianę.
        #expect(zLodowka.totalWidth == bezLodowki.totalWidth)
    }

    /// Krótka ściana nie dostaje odmowy, tylko propozycję bez części sprzętu —
    /// i jasną informację, co z niej wypadło.
    @Test
    func krotkaScianaDostajePropozycjeBezCzesciSprzetu() {
        let plan = KitchenLayoutProposer.proposeBaseRun(
            wallLength: 1_805,
            appliances: .init(hasIntegratedFridge: true))
        #expect(!plan.slots.isEmpty)
        #expect(plan.totalWidth == Millimeters(1_805))
        #expect(plan.slots.contains { $0.kind == .sink }, "zlew musi zostać")
        #expect(plan.warnings.contains { $0.contains("poza ciągiem zostało") },
                "ostrzeżenia: \(plan.warnings)")
    }

    /// Blenda 5 mm nie istnieje — taka reszta musi zostać wchłonięta przez
    /// sąsiednią szafkę. Wyszło to dopiero po wypisaniu przykładowych propozycji.
    @Test
    func zaWaskaBlendaJestWchlanianaPrzezSasiadaNieWykonywana() {
        for dlugosc in [Millimeters(1_805), 3_615, 2_312, 4_007] {
            let plan = KitchenLayoutProposer.proposeBaseRun(wallLength: dlugosc)
            let blendy = plan.slots.filter { $0.kind == .filler }
            #expect(blendy.allSatisfy { $0.width >= KitchenLayoutProposer.minimumFillerWidth },
                    "\(dlugosc): \(blendy.map(\.width))")
            #expect(plan.totalWidth == dlugosc, "ciąg musi nadal domykać ścianę")
        }
    }

    /// Moduł sprzętowy nigdy nie jest poszerzany — zmywarka 600 to zmywarka 600.
    @Test
    func modulSprzetowyNieJestPoszerzany() {
        for dlugosc in [Millimeters(1_805), 3_615, 2_312, 4_007, 2_905] {
            let plan = KitchenLayoutProposer.proposeBaseRun(wallLength: dlugosc)
            for slot in plan.slots where [.dishwasher, .oven, .fridge].contains(slot.kind) {
                let oczekiwana: Millimeters = slot.kind == .fridge
                    ? KitchenLayoutProposer.fridgeWidth
                    : (slot.kind == .oven ? KitchenLayoutProposer.ovenWidth
                                          : KitchenLayoutProposer.dishwasherWidth)
                #expect(slot.width == oczekiwana,
                        "\(slot.kind) ma \(slot.width) przy ścianie \(dlugosc)")
            }
        }
    }

    /// Blenda domyka ciąg przy ścianie — nigdy nie stoi między szafkami.
    /// Wyszło to dopiero po narysowaniu elewacji: 100 mm blendy wylądowało
    /// między zmywarką a piekarnikiem i wyglądało jak szafka bez funkcji.
    @Test
    func blendaStoiNaKoncuCiaguNieWSrodku() {
        for dlugosc in [Millimeters(3_600), 4_160, 3_100, 2_950, 5_200] {
            let plan = KitchenLayoutProposer.proposeBaseRun(
                wallLength: dlugosc,
                appliances: .init(hasIntegratedFridge: true))
            let indeksy = plan.slots.enumerated()
                .filter { $0.element.kind == .filler }
                .map(\.offset)
            for indeks in indeksy {
                let uklad = plan.slots.map { "\($0.kind)" }.joined(separator: ",")
                #expect(indeks == plan.slots.count - 1,
                        "blenda na pozycji \(indeks) z \(plan.slots.count) przy \(dlugosc): \(uklad)")
            }
        }
    }

    @Test
    func brakZlewuJestOstrzezeniem() {
        let plan = KitchenLayoutProposer.proposeBaseRun(
            wallLength: 3_000, appliances: .init(hasSink: false))
        #expect(plan.warnings.contains { $0.contains("bez zlewu") })
    }

    /// Żaden moduł z propozycji nie może przekraczać rozpiętości półki —
    /// inaczej planer proponowałby coś, co `RunSplitPlanner` zaraz każe dzielić.
    @Test
    func zadenModulNiePrzekraczaRozpietosciPolki() {
        for dlugosc in [Millimeters(3_600), 4_160, 5_000, 6_200] {
            let plan = KitchenLayoutProposer.proposeBaseRun(wallLength: dlugosc)
            for slot in plan.slots {
                #expect(slot.width <= RunSplitPlanner.maxShelfSpan,
                        "\(slot.kind) \(slot.width) mm przy ścianie \(dlugosc)")
            }
        }
    }

    /// Wąska reszta trafia do cargo, a nie do bezużytecznej szafeczki z drzwiami.
    @Test
    func waskaLukaDostajeCargo() {
        // 800 zlew + 600 zmywarka + 600 piekarnik = 2000; zostaje 300.
        let plan = KitchenLayoutProposer.proposeBaseRun(wallLength: 2_300)
        #expect(plan.slots.contains { $0.kind == .cargo && $0.width == Millimeters(300) },
                "sloty: \(plan.slots.map { "\($0.kind)=\($0.width)" })")
    }
}
