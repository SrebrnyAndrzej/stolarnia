import DomainCore
import Foundation

enum TypOperacjiCNCV073: String, CaseIterable, Codable, Hashable, Identifiable {
    case otworNieprzelotowy, otworPrzelotowy, puszkaZawiasu
    case rzadSystem32, kolkowanie, rowek, frezowanie, znakowanie

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .otworNieprzelotowy: return "Otwór nieprzelotowy"
        case .otworPrzelotowy: return "Otwór przelotowy"
        case .puszkaZawiasu: return "Puszka zawiasu"
        case .rzadSystem32: return "Rząd System 32"
        case .kolkowanie: return "Kołkowanie"
        case .rowek: return "Rowek"
        case .frezowanie: return "Frezowanie"
        case .znakowanie: return "Znakowanie"
        }
    }

    var symbol: String {
        switch self {
        case .otworNieprzelotowy: return "circle"
        case .otworPrzelotowy: return "circle.circle"
        case .puszkaZawiasu: return "circle.dashed"
        case .rzadSystem32: return "ellipsis"
        case .kolkowanie: return "smallcircle.filled.circle"
        case .rowek: return "line.diagonal"
        case .frezowanie: return "scribble.variable"
        case .znakowanie: return "tag"
        }
    }

    var wymagaSrednicy: Bool {
        self != .rowek && self != .frezowanie && self != .znakowanie
    }

    var jestLiniowa: Bool {
        self == .rowek || self == .frezowanie
    }
}

enum PowierzchniaObrobkiV073: String, CaseIterable, Codable, Hashable, Identifiable {
    case stronaA, stronaB
    case krawedzDlugaA, krawedzDlugaB
    case krawedzKrotkaA, krawedzKrotkaB

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .stronaA: return "Strona A"
        case .stronaB: return "Strona B"
        case .krawedzDlugaA: return "Krawędź długa A"
        case .krawedzDlugaB: return "Krawędź długa B"
        case .krawedzKrotkaA: return "Krawędź krótka A"
        case .krawedzKrotkaB: return "Krawędź krótka B"
        }
    }

    var skrot: String {
        switch self {
        case .stronaA: return "A"
        case .stronaB: return "B"
        case .krawedzDlugaA: return "DA"
        case .krawedzDlugaB: return "DB"
        case .krawedzKrotkaA: return "KA"
        case .krawedzKrotkaB: return "KB"
        }
    }

    var jestPowierzchnia: Bool {
        self == .stronaA || self == .stronaB
    }
}

enum KierunekPowtorzenV073: String, CaseIterable, Codable, Hashable, Identifiable {
    case wzdluzX, wzdluzY
    var id: String { rawValue }
    var nazwa: String { self == .wzdluzX ? "Wzdłuż X" : "Wzdłuż Y" }
}

enum StatusOperacjiCNCV073: String, CaseIterable, Codable, Hashable, Identifiable {
    case gotowa, doWeryfikacji, blad
    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .gotowa: return "Gotowa"
        case .doWeryfikacji: return "Do weryfikacji"
        case .blad: return "Błąd"
        }
    }

    var symbol: String {
        switch self {
        case .gotowa: return "checkmark.circle.fill"
        case .doWeryfikacji: return "exclamationmark.triangle.fill"
        case .blad: return "xmark.octagon.fill"
        }
    }
}

struct UstawieniaObrobekCNCV073: Hashable {
    var generujSystem32 = true
    var generujRowekPlecy = true
    var generujLaczeniaKorpusu = true
    var generujPuszkiZawiasow = true

    var odsuniecieSystem32MM = 37.0
    var pierwszyOtworMM = 64.0
    var skokSystem32MM = 32.0
    var srednicaSystem32MM = 5.0
    var glebokoscSystem32MM = 12.0

    var odsuniecieRowkaMM = 10.0
    var szerokoscRowkaMM = 4.0
    var glebokoscRowkaMM = 8.0

    var odsuniecieLaczeniaMM = 50.0
    var srednicaKolkaMM = 8.0
    var glebokoscKolkaMM = 12.0

    var srednicaPuszkiMM = 35.0
    var glebokoscPuszkiMM = 13.0
    var osPuszkiOdKrawedziMM = 22.5
    var puszkaOdKoncaMM = 100.0

    static let standard = Self()

    var poprawne: Bool {
        let values = [
            odsuniecieSystem32MM, pierwszyOtworMM, skokSystem32MM,
            srednicaSystem32MM, glebokoscSystem32MM,
            odsuniecieRowkaMM, szerokoscRowkaMM, glebokoscRowkaMM,
            odsuniecieLaczeniaMM, srednicaKolkaMM, glebokoscKolkaMM,
            srednicaPuszkiMM, glebokoscPuszkiMM,
            osPuszkiOdKrawedziMM, puszkaOdKoncaMM
        ]
        return values.allSatisfy { $0.isFinite && $0 > 0 }
            && skokSystem32MM >= srednicaSystem32MM
    }
}

struct OperacjaCNCV073: Identifiable, Hashable {
    var id: String
    var formatkaID: String
    var typ: TypOperacjiCNCV073
    var powierzchnia: PowierzchniaObrobkiV073
    var xMM: Double
    var yMM: Double
    var srednicaMM: Double?
    var glebokoscMM: Double
    var dlugoscMM: Double?
    var szerokoscMM: Double?
    var liczbaPowtorzen: Int
    var rozstawMM: Double?
    var kierunekPowtorzen: KierunekPowtorzenV073
    var status: StatusOperacjiCNCV073
    var automatyczna: Bool
    var uwagi: String

    var liczbaRzeczywistychOperacji: Int { max(1, liczbaPowtorzen) }

    var opisParametrow: String {
        var parts: [String] = []
        if let d = srednicaMM { parts.append("Ø\(d.formatted(.number.precision(.fractionLength(0...2))))") }
        if glebokoscMM > 0 { parts.append("gł. \(glebokoscMM.formatted(.number.precision(.fractionLength(0...2)))) mm") }
        if let l = dlugoscMM { parts.append("L \(l.formatted(.number.precision(.fractionLength(0...2)))) mm") }
        if let w = szerokoscMM { parts.append("W \(w.formatted(.number.precision(.fractionLength(0...2)))) mm") }
        if liczbaPowtorzen > 1 {
            let pitch = rozstawMM.map { " co \($0.formatted(.number.precision(.fractionLength(0...2)))) mm" } ?? ""
            parts.append("\(liczbaPowtorzen)×\(pitch)")
        }
        return parts.isEmpty ? "Brak parametrów" : parts.joined(separator: " · ")
    }
}

struct PozycjaObrobekCNCV073: Identifiable, Hashable {
    var formatka: FormatkaProjektuV070
    var operacje: [OperacjaCNCV073]
    var id: String { formatka.id }

    var liczbaOperacji: Int {
        operacje.reduce(0) { $0 + $1.liczbaRzeczywistychOperacji }
    }
    var liczbaDoWeryfikacji: Int { operacje.filter { $0.status == .doWeryfikacji }.count }
    var liczbaBledow: Int { operacje.filter { $0.status == .blad }.count }
}

struct RaportObrobekCNCV073: Hashable {
    var nazwaProjektu: String
    var dataUtworzenia: Date
    var ustawienia: UstawieniaObrobekCNCV073
    var pozycje: [PozycjaObrobekCNCV073]

    var liczbaFormatekZObrobka: Int { pozycje.filter { !$0.operacje.isEmpty }.count }
    var liczbaOperacji: Int { pozycje.reduce(0) { $0 + $1.liczbaOperacji } }
    var liczbaDoWeryfikacji: Int { pozycje.reduce(0) { $0 + $1.liczbaDoWeryfikacji } }
    var liczbaBledow: Int { pozycje.reduce(0) { $0 + $1.liczbaBledow } }

    mutating func dodaj(_ operation: OperacjaCNCV073) {
        guard let i = pozycje.firstIndex(where: { $0.id == operation.formatkaID }) else { return }
        pozycje[i].operacje.append(operation)
        pozycje[i].operacje.sort(by: ObrobkiCNCOrderingV073.operacje)
    }

    mutating func aktualizuj(_ operation: OperacjaCNCV073) {
        guard let i = pozycje.firstIndex(where: { $0.id == operation.formatkaID }),
              let j = pozycje[i].operacje.firstIndex(where: { $0.id == operation.id }) else { return }
        pozycje[i].operacje[j] = operation
        pozycje[i].operacje.sort(by: ObrobkiCNCOrderingV073.operacje)
    }

    mutating func usun(id: String) {
        for i in pozycje.indices { pozycje[i].operacje.removeAll { $0.id == id } }
    }
}

enum ObrobkiCNCOrderingV073 {
    static func operacje(_ lhs: OperacjaCNCV073, _ rhs: OperacjaCNCV073) -> Bool {
        if lhs.powierzchnia.rawValue != rhs.powierzchnia.rawValue {
            return lhs.powierzchnia.rawValue < rhs.powierzchnia.rawValue
        }
        if lhs.xMM != rhs.xMM { return lhs.xMM < rhs.xMM }
        if lhs.yMM != rhs.yMM { return lhs.yMM < rhs.yMM }
        return lhs.id < rhs.id
    }
}
