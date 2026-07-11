import Combine
import Foundation

// MARK: - Blat kuchenny

enum BlatKuchennyKsztaltV082: String, Codable, CaseIterable, Identifiable {
    case prosty    = "Prosty"
    case L         = "Kształt L"
    case U         = "Kształt U"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .prosty: return "rectangle"
        case .L:      return "arrow.turn.down.right"
        case .U:      return "arrow.uturn.right"
        }
    }
}

enum BlatKuchennyGruboscV082: Int, Codable, CaseIterable, Identifiable {
    case mm12 = 12
    case mm28 = 28
    case mm38 = 38

    var id: Int { rawValue }
    var label: String { "\(rawValue) mm" }
}

enum BlatWyciecieV082: String, Codable, CaseIterable, Identifiable, Hashable {
    case zlew      = "Zlew jednokomorowy"
    case zlewDwu   = "Zlew dwukomorowy"
    case indukcja  = "Indukcja / płyta grzewcza"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .zlew:     return "drop.circle"
        case .zlewDwu:  return "drop.degreesign.fill"
        case .indukcja: return "flame.circle"
        }
    }
}

struct BlatKuchennyV082: Identifiable, Codable, Hashable {
    var id = UUID()
    var roomID: String
    var nazwa: String = "Blat"
    var ksztalt: BlatKuchennyKsztaltV082 = .prosty
    var grubosc: BlatKuchennyGruboscV082 = .mm38

    /// Długości odcinków w mm. Odcinek 2 i 3 używane tylko dla L i U.
    var dlugoscCiagu1MM: Double = 2400
    var dlugoscCiagu2MM: Double = 0
    var dlugoscCiagu3MM: Double = 0
    var szerokoscMM: Double = 600

    var wycięcia: [BlatWyciecieV082] = []
    var materialNazwa: String = ""
    var uwagi: String = ""

    var calkowitaDlugoscMM: Double {
        dlugoscCiagu1MM
        + (ksztalt == .L || ksztalt == .U ? dlugoscCiagu2MM : 0)
        + (ksztalt == .U ? dlugoscCiagu3MM : 0)
    }

    var calkowitaDlugoscM: Double { calkowitaDlugoscMM / 1_000 }
}

// MARK: - Fartuch (backsplash)

enum FartuchMaterialTypV082: String, Codable, CaseIterable, Identifiable {
    case plytki          = "Płytki ceramiczne"
    case szkloLakierowane = "Szkło lakierowane"
    case hpl             = "HPL / laminat"
    case beton           = "Beton architektoniczny"
    case kamien          = "Kamień / konglomerat"
    case inne            = "Inny"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .plytki:           return "square.grid.2x2"
        case .szkloLakierowane: return "sparkle"
        case .hpl:              return "rectangle.fill"
        case .beton:            return "building.2"
        case .kamien:           return "mountain.2"
        case .inne:             return "questionmark.circle"
        }
    }
}

struct FartuchPomieszczeniaV082: Identifiable, Codable, Hashable {
    var id = UUID()
    var roomID: String
    var nazwa: String = "Fartuch"
    var materialTyp: FartuchMaterialTypV082 = .plytki
    var materialNazwa: String = ""

    /// Czy długość jest obliczana automatycznie z ciągów dolnych projektu.
    var liczyAutoZ: Bool = true
    var dlugoscMM: Double = 0   // ręczna, gdy liczyAutoZ == false
    var wysokoscMM: Double = 600

    var uwagi: String = ""

    func powierzchniaM2(bazowaDlugoscCiaguMM: Double) -> Double {
        let dl = liczyAutoZ ? bazowaDlugoscCiaguMM : dlugoscMM
        return (dl / 1_000) * (wysokoscMM / 1_000)
    }
}

// MARK: - Wieniec / listwa wykończeniowa

enum WieniecTypV082: String, Codable, CaseIterable, Identifiable {
    case listwaCokołowa    = "Listwa cokołowa"
    case listwaNadszafkowa = "Listwa nadszafkowa"
    case wieniecGorny      = "Wieniec górny (do sufitu)"
    case listwaPionowa     = "Listwa zamykająca pionowa"
    case kanalLED          = "Wieniec z kanałem LED"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .listwaCokołowa:    return "align.horizontal.bottom"
        case .listwaNadszafkowa: return "square.topthird.inset.filled"
        case .wieniecGorny:      return "align.horizontal.top.fill"
        case .listwaPionowa:     return "sidebar.left"
        case .kanalLED:          return "lightbulb.led.wide.fill"
        }
    }
}

struct WieniecDekoracyjnyV082: Identifiable, Codable, Hashable {
    var id = UUID()
    var roomID: String
    var wallID: String?     // nil = całe pomieszczenie / bez przypisania ściany
    var nazwa: String = ""
    var typ: WieniecTypV082
    var liczyAutoZ: Bool = true
    var dlugoscMM: Double = 0
    var materialNazwa: String = ""
    var uwagi: String = ""

    func dlugoscM(bazowaDlugoscCiaguMM: Double) -> Double {
        let mm = liczyAutoZ ? bazowaDlugoscCiaguMM : dlugoscMM
        return mm / 1_000
    }
}

// MARK: - Repository

final class WykonczeniaKuchenneRepositoryV082: ObservableObject {
    @Published var blaty: [BlatKuchennyV082] = []
    @Published var fartuchy: [FartuchPomieszczeniaV082] = []
    @Published var wienceDekory: [WieniecDekoracyjnyV082] = []

    private(set) var roomID: String = ""
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {}

    /// Wywołaj po uzyskaniu roomID (np. w .onAppear). Ładuje dane jeśli roomID się zmieniło.
    func setup(roomID: String) {
        guard self.roomID != roomID else { return }
        self.roomID = roomID
        load()
    }

    // MARK: Blaty

    func dodajBlat() {
        blaty.append(BlatKuchennyV082(roomID: roomID.isEmpty ? "unknown" : roomID, nazwa: "Blat \(blaty.count + 1)"))
        save()
    }

    func usunBlat(id: UUID) {
        blaty.removeAll { $0.id == id }
        save()
    }

    func zaktualizujBlat(_ blat: BlatKuchennyV082) {
        guard let idx = blaty.firstIndex(where: { $0.id == blat.id }) else { return }
        blaty[idx] = blat
        save()
    }

    // MARK: Fartuchy

    func dodajFartuch() {
        fartuchy.append(FartuchPomieszczeniaV082(roomID: roomID.isEmpty ? "unknown" : roomID, nazwa: "Fartuch \(fartuchy.count + 1)"))
        save()
    }

    func usunFartuch(id: UUID) {
        fartuchy.removeAll { $0.id == id }
        save()
    }

    func zaktualizujFartuch(_ fartuch: FartuchPomieszczeniaV082) {
        guard let idx = fartuchy.firstIndex(where: { $0.id == fartuch.id }) else { return }
        fartuchy[idx] = fartuch
        save()
    }

    // MARK: Wieńce

    func dodajWieniec(typ: WieniecTypV082) {
        wienceDekory.append(WieniecDekoracyjnyV082(roomID: roomID.isEmpty ? "unknown" : roomID, nazwa: typ.rawValue, typ: typ))
        save()
    }

    func usunWieniec(id: UUID) {
        wienceDekory.removeAll { $0.id == id }
        save()
    }

    func zaktualizujWieniec(_ wieniec: WieniecDekoracyjnyV082) {
        guard let idx = wienceDekory.firstIndex(where: { $0.id == wieniec.id }) else { return }
        wienceDekory[idx] = wieniec
        save()
    }

    // MARK: Wycena helpers

    func sumaBlatomMB() -> Double {
        blaty.reduce(0) { $0 + $1.calkowitaDlugoscM }
    }

    func sumaFartuchowM2(bazowaDlugoscCiaguMM: Double) -> Double {
        fartuchy.reduce(0) { sum, f in sum + f.powierzchniaM2(bazowaDlugoscCiaguMM: bazowaDlugoscCiaguMM) }
    }

    func sumaWiencowMB(bazowaDlugoscCiaguMM: Double) -> Double {
        wienceDekory.reduce(0) { sum, w in sum + w.dlugoscM(bazowaDlugoscCiaguMM: bazowaDlugoscCiaguMM) }
    }

    var maPozycje: Bool {
        !blaty.isEmpty || !fartuchy.isEmpty || !wienceDekory.isEmpty
    }

    // MARK: Persistence

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("wykonczeniaKuchenne_\(roomID).json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? decoder.decode(StoredData.self, from: data)
        else { return }
        blaty = stored.blaty
        fartuchy = stored.fartuchy
        wienceDekory = stored.wienceDekory
    }

    private func save() {
        let stored = StoredData(blaty: blaty, fartuchy: fartuchy, wienceDekory: wienceDekory)
        if let data = try? encoder.encode(stored) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private struct StoredData: Codable {
        var blaty: [BlatKuchennyV082]
        var fartuchy: [FartuchPomieszczeniaV082]
        var wienceDekory: [WieniecDekoracyjnyV082]
    }
}
