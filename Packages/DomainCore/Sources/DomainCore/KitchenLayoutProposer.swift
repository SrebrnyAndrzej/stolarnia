import Foundation

/// Proponuje gotowy ciąg dolny kuchni dla zadanej ściany.
///
/// Powstało z researchu ergonomii (2026-08-26). Planer IKEA prowadzi tak:
/// najpierw kilka pytań o AGD i kształt pomieszczenia, potem **planer sam
/// pokazuje gotowe propozycje kuchni**, a użytkownik wybiera jedną i dopiero ją
/// zmienia. Dopiero na końcu edytuje pojedyncze szafki.
///
/// StolarniaApp miała ten krok pominięty: po podaniu czterech wymiarów
/// projektant dostawał pusty plan i katalog stu kilkudziesięciu modułów.
/// To jest klasyczna „paraliżująca pusta kartka" — bez ograniczeń i podpowiedzi
/// więcej energii idzie na decyzję *od czego zacząć* niż na samą pracę.
///
/// Ten planer nie zastępuje projektanta. Ma dać **punkt wyjścia, który jest już
/// poprawny warsztatowo**, żeby praca zaczynała się od poprawiania, a nie od
/// pustego ekranu.
public enum KitchenLayoutProposer {

    // MARK: - Wejście

    /// Odpowiedniki pytań, które IKEA zadaje na samym początku.
    public struct Appliances: Hashable, Sendable {
        public var hasSink: Bool
        public var hasDishwasher: Bool
        public var hasOven: Bool
        public var hasHob: Bool
        /// Lodówka do zabudowy zajmuje moduł w ciągu; wolnostojąca nie.
        public var hasIntegratedFridge: Bool

        public init(
            hasSink: Bool = true,
            hasDishwasher: Bool = true,
            hasOven: Bool = true,
            hasHob: Bool = true,
            hasIntegratedFridge: Bool = false
        ) {
            self.hasSink = hasSink
            self.hasDishwasher = hasDishwasher
            self.hasOven = hasOven
            self.hasHob = hasHob
            self.hasIntegratedFridge = hasIntegratedFridge
        }
    }

    // MARK: - Wyjście

    public enum SlotKind: String, Codable, Hashable, Sendable, CaseIterable {
        case sink
        case dishwasher
        case oven
        case hob
        case fridge
        case drawers
        case doors
        case cargo
        case filler

        public var displayName: String {
            switch self {
            case .sink:       return "Zlewozmywak"
            case .dishwasher: return "Zmywarka"
            case .oven:       return "Piekarnik"
            case .hob:        return "Płyta grzewcza"
            case .fridge:     return "Lodówka do zabudowy"
            case .drawers:    return "Szuflady"
            case .doors:      return "Drzwi"
            case .cargo:      return "Cargo"
            case .filler:     return "Blenda"
            }
        }
    }

    public struct Slot: Hashable, Sendable, Identifiable {
        public var id: Int
        public var kind: SlotKind
        public var width: Millimeters
        /// Dlaczego akurat tu — do pokazania projektantowi przy propozycji.
        public var note: String

        public init(id: Int, kind: SlotKind, width: Millimeters, note: String = "") {
            self.id = id
            self.kind = kind
            self.width = width
            self.note = note
        }
    }

    public struct Proposal: Hashable, Sendable {
        public var slots: [Slot]
        public var reason: String
        public var warnings: [String]

        public var totalWidth: Millimeters {
            slots.reduce(Millimeters.zero) { $0 + $1.width }
        }

        public init(slots: [Slot], reason: String, warnings: [String] = []) {
            self.slots = slots
            self.reason = reason
            self.warnings = warnings
        }
    }

    // MARK: - Wymiary katalogowe

    /// Podziałki, które warsztat trzyma jako standard.
    ///
    /// Katalog ma też 1000 i 1200 mm, ale ich tu nie ma **celowo**:
    /// `RunSplitPlanner.maxShelfSpan` to 900 mm i powyżej tego półka się ugina.
    /// Planer, który proponuje moduł 1200, od razu produkuje pracę do poprawienia.
    public static let standardWidths: [Millimeters] = [
        300, 400, 450, 500, 600, 800, 900
    ]

    public static let sinkWidth: Millimeters = 800
    public static let dishwasherWidth: Millimeters = 600
    public static let ovenWidth: Millimeters = 600
    public static let fridgeWidth: Millimeters = 600
    /// Poniżej tej długości nie ma sensu mówić o ciągu roboczym.
    public static let minimumRunLength: Millimeters = 900

    /// Najwęższa blenda, którą da się wykonać i zamocować.
    ///
    /// Reszty poniżej tej wartości nie zamyka się paskiem płyty — w stolarce
    /// na wymiar **poszerza się sąsiednią szafkę**. Korpus 605 mm jest normalny,
    /// blenda 5 mm nie istnieje.
    public static let minimumFillerWidth: Millimeters = 30

    // MARK: - Propozycja

    /// Buduje propozycję ciągu dolnego dla ściany o zadanej długości.
    ///
    /// Kolejność slotów nie jest przypadkowa — wynika z tego, jak się w kuchni
    /// pracuje: **lodówka → blat roboczy → zlew → zmywarka obok zlewu →
    /// blat → płyta z piekarnikiem**. To jest trójkąt roboczy rozłożony na
    /// jedną ścianę.
    public static func proposeBaseRun(
        wallLength: Millimeters,
        appliances: Appliances = Appliances()
    ) -> Proposal {
        guard wallLength >= minimumRunLength else {
            return Proposal(
                slots: [],
                reason: String(
                    format: "Ściana %.0f mm jest za krótka na ciąg roboczy "
                        + "(minimum %.0f mm).",
                    wallLength.rawValue, minimumRunLength.rawValue),
                warnings: ["Rozważ tu słupek albo szafkę pojedynczą."])
        }

        var kolejnosc: [(SlotKind, Millimeters, String)] = []

        if appliances.hasIntegratedFridge {
            kolejnosc.append((.fridge, fridgeWidth, "na końcu ciągu, poza strefą roboczą"))
        }
        if appliances.hasSink {
            kolejnosc.append((.sink, sinkWidth, "szerszy korpus mieści syfon i kosze"))
        }
        if appliances.hasDishwasher {
            kolejnosc.append((.dishwasher, dishwasherWidth, "przy zlewie, wspólna instalacja"))
        }
        if appliances.hasOven {
            let opis = appliances.hasHob
                ? "piekarnik pod płytą — jedno przyłącze, jedna strefa gorąca"
                : "zabudowa piekarnika"
            kolejnosc.append((.oven, ovenWidth, opis))
        } else if appliances.hasHob {
            kolejnosc.append((.hob, ovenWidth, "korpus pod płytą, szuflady niskie"))
        }

        var ostrzezenia: [String] = []

        // Gdy sprzęt nie mieści się w całości, **zdejmujemy go po kolei**, zamiast
        // odmawiać propozycji. Krótka ściana też zasługuje na punkt wyjścia, a
        // projektant i tak zobaczy w ostrzeżeniach, co wypadło i dlaczego.
        // Kolejność zdejmowania jest odwrotnością ważności: lodówkę da się
        // postawić wolnostojącą, piekarnik przenieść do słupka, zmywarkę na
        // drugą ścianę. Zlew zostaje do końca, bo bez niego to nie jest kuchnia.
        let priorytetZdejmowania: [SlotKind] = [.fridge, .oven, .hob, .dishwasher]
        var zdjete: [SlotKind] = []
        while kolejnosc.reduce(Millimeters.zero, { $0 + $1.1 }) > wallLength {
            guard let doZdjecia = priorytetZdejmowania.first(
                where: { kind in kolejnosc.contains { $0.0 == kind } }),
                  let indeks = kolejnosc.firstIndex(where: { $0.0 == doZdjecia })
            else { break }
            kolejnosc.remove(at: indeks)
            zdjete.append(doZdjecia)
        }
        let zajete = kolejnosc.reduce(Millimeters.zero) { $0 + $1.1 }

        if zajete > wallLength {
            return Proposal(
                slots: [],
                reason: String(
                    format: "Nawet sam zlew (%.0f mm) nie mieści się na ścianie %.0f mm.",
                    zajete.rawValue, wallLength.rawValue),
                warnings: ["To miejsce na szafkę pojedynczą, nie na ciąg roboczy."])
        }
        if !zdjete.isEmpty {
            let nazwy = zdjete.map(\.displayName).joined(separator: ", ")
            let dlugosc = String(format: "%.0f", wallLength.rawValue)
            ostrzezenia.append(
                "Ściana \(dlugosc) mm nie pomieściła całego sprzętu — "
                + "poza ciągiem zostało: \(nazwy).")
        }

        // Resztę wypełniamy szafkami roboczymi: najpierw szuflady (dostęp
        // z góry, bez klękania), dopiero potem drzwi.
        let dostepne = wallLength - zajete
        let wypelniacze = wypelnij(dostepne)

        var slots: [Slot] = []
        var i = 0
        // Szafka robocza między lodówką a zlewem — blat do odkładania.
        // Blenda musi trafić na **koniec ciągu, przy ścianie** — nigdy między
        // szafki. Wstawiona w środku wygląda jak wąska szafka bez funkcji
        // i psuje linię frontów. Widać to dopiero na elewacji, nie na liczbach.
        var wypelnieniaDoWstawienia = wypelniacze.filter { $0.0 != .filler }
        let blendy = wypelniacze.filter { $0.0 == .filler }
        func wezWypelniacz() -> (SlotKind, Millimeters, String)? {
            wypelnieniaDoWstawienia.isEmpty ? nil : wypelnieniaDoWstawienia.removeFirst()
        }

        for (indeks, pozycja) in kolejnosc.enumerated() {
            slots.append(Slot(id: i, kind: pozycja.0, width: pozycja.1, note: pozycja.2))
            i += 1
            // Po lodówce i po zlewie wstawiamy blat roboczy, jeśli jest z czego.
            let poLodowce = pozycja.0 == .fridge
            let poZmywarce = pozycja.0 == .dishwasher
            if (poLodowce || poZmywarce), indeks < kolejnosc.count - 1,
               let w = wezWypelniacz() {
                slots.append(Slot(id: i, kind: w.0, width: w.1, note: w.2))
                i += 1
            }
        }
        // Co zostało z szafek — na koniec ciągu.
        while let w = wezWypelniacz() {
            slots.append(Slot(id: i, kind: w.0, width: w.1, note: w.2))
            i += 1
        }
        // Blenda dopiero teraz, jako ostatnia — domyka ciąg do ściany.
        for b in blendy {
            slots.append(Slot(id: i, kind: b.0, width: b.1, note: b.2))
            i += 1
        }

        slots = wchlonMalaBlende(slots)

        if slots.contains(where: { $0.kind == .filler }) {
            ostrzezenia.append(
                "Ciąg nie dzieli się na całe podziałki — resztę zamyka blenda.")
        }
        if !appliances.hasSink {
            ostrzezenia.append("Ciąg bez zlewu — sprawdź, czy to zamierzone.")
        }

        return Proposal(
            slots: slots,
            reason: String(
                format: "%d modułów na %.0f mm: sprzęt rozłożony wzdłuż drogi "
                    + "pracy, reszta jako szafki robocze.",
                slots.count, wallLength.rawValue),
            warnings: ostrzezenia)
    }

    /// Wchłania zbyt wąską blendę w najbliższą szafkę roboczą.
    ///
    /// Moduły sprzętowe zachowują swoją szerokość co do milimetra — zmywarka
    /// 600 to zmywarka 600 i nie wolno jej „dociąć". Poszerzana jest wyłącznie
    /// szafka z szufladami, drzwiami albo cargo.
    private static func wchlonMalaBlende(_ slots: [Slot]) -> [Slot] {
        guard let indeksBlendy = slots.lastIndex(where: { $0.kind == .filler }),
              slots[indeksBlendy].width < minimumFillerWidth
        else { return slots }

        let reszta = slots[indeksBlendy].width
        var wynik = slots
        let poszerzalne: Set<SlotKind> = [.drawers, .doors, .cargo]
        guard let cel = wynik[..<indeksBlendy].lastIndex(where: {
            poszerzalne.contains($0.kind)
        }) else { return slots }   // nie ma czego poszerzyć — blenda zostaje

        wynik.remove(at: indeksBlendy)
        wynik[cel].width = wynik[cel].width + reszta
        let szer = String(format: "%.0f", wynik[cel].width.rawValue)
        wynik[cel].note = "korpus na wymiar \(szer) mm — wchłania resztę ciągu"
        return wynik
    }

    // MARK: - Wypełnienie

    /// Dzieli wolną długość na szafki katalogowe.
    ///
    /// Preferuje szerokie szuflady, bo w ciągu dolnym to one dają realny dostęp
    /// do zawartości — po szafkę z drzwiami trzeba klęknąć i sięgnąć w głąb.
    /// Resztę poniżej najwęższej podziałki zamyka blenda, żeby ciąg domknął się
    /// do ściany co do milimetra.
    private static func wypelnij(_ dlugosc: Millimeters) -> [(SlotKind, Millimeters, String)] {
        var pozostalo = dlugosc
        var wynik: [(SlotKind, Millimeters, String)] = []
        let malejaco = standardWidths.sorted(by: >)

        while pozostalo > .zero {
            guard let podzialka = malejaco.first(where: { $0 <= pozostalo }) else {
                // Reszta mniejsza niż najwęższa szafka — blenda.
                if pozostalo.rawValue >= 1 {
                    wynik.append((.filler, pozostalo, "domyka ciąg do ściany"))
                }
                break
            }
            // Cargo tam, gdzie zostaje wąska szczelina 150–400 mm.
            if podzialka <= 400, pozostalo <= 400 {
                wynik.append((.cargo, podzialka, "wąska luka — cargo zamiast szafki"))
            } else if podzialka >= 600 {
                wynik.append((.drawers, podzialka, "szuflady: dostęp bez klękania"))
            } else {
                wynik.append((.doors, podzialka, "szafka z drzwiami i półką"))
            }
            pozostalo = pozostalo - podzialka
        }
        return wynik
    }
}
