import DomainCore
import Foundation

enum KrawedzFormatkiV072: String, CaseIterable, Codable, Hashable, Identifiable {
    case dlugaA
    case dlugaB
    case krotkaA
    case krotkaB

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .dlugaA: return "Długa A"
        case .dlugaB: return "Długa B"
        case .krotkaA: return "Krótka A"
        case .krotkaB: return "Krótka B"
        }
    }

    var skrot: String {
        switch self {
        case .dlugaA: return "DA"
        case .dlugaB: return "DB"
        case .krotkaA: return "KA"
        case .krotkaB: return "KB"
        }
    }

    func dlugoscMM(dla formatki: FormatkaProjektuV070) -> Double {
        switch self {
        case .dlugaA, .dlugaB:
            return formatki.dlugoscMM
        case .krotkaA, .krotkaB:
            return formatki.szerokoscMM
        }
    }
}

enum RodzajObrzezaV072: String, CaseIterable, Codable, Hashable, Identifiable {
    case brak
    case abs08
    case abs20

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .brak: return "Bez obrzeża"
        case .abs08: return "ABS 0,8 mm"
        case .abs20: return "ABS 2,0 mm"
        }
    }

    var skrot: String {
        switch self {
        case .brak: return "—"
        case .abs08: return "0,8"
        case .abs20: return "2,0"
        }
    }

    var gruboscMM: Double {
        switch self {
        case .brak: return 0
        case .abs08: return 0.8
        case .abs20: return 2
        }
    }

    var kolejny: Self {
        switch self {
        case .brak: return .abs08
        case .abs08: return .abs20
        case .abs20: return .brak
        }
    }
}

struct SpecyfikacjaObrzezaV072: Hashable, Identifiable {
    var rodzaj: RodzajObrzezaV072
    var kod: String
    var nazwa: String
    var producent: String
    var kolorHEX: String

    var id: String {
        [rodzaj.rawValue, producent, kod, kolorHEX]
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
            }
            .joined(separator: "|")
    }

    var opis: String {
        let p = producent.trimmingCharacters(in: .whitespacesAndNewlines)
        let k = kod.trimmingCharacters(in: .whitespacesAndNewlines)

        if p.isEmpty && k.isEmpty { return nazwa }
        if p.isEmpty { return "\(k) — \(nazwa)" }
        if k.isEmpty { return "\(p) — \(nazwa)" }
        return "\(p) \(k) — \(nazwa)"
    }

    static func wykonaj(
        rodzaj: RodzajObrzezaV072,
        material: MaterialFormatkiV070
    ) -> Self? {
        guard rodzaj != .brak else { return nil }

        let gruboscKod = rodzaj == .abs08 ? "08" : "20"
        let materialKod = material.kod
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let kod = materialKod.isEmpty
            ? "ABS-\(gruboscKod)"
            : "ABS-\(gruboscKod)-\(materialKod)"

        return Self(
            rodzaj: rodzaj,
            kod: kod,
            nazwa: "\(rodzaj.nazwa) — \(material.nazwa)",
            producent: material.producent,
            kolorHEX: material.kolorHEX
        )
    }
}

struct ObrobkaKrawedziV072: Hashable, Identifiable {
    var krawedz: KrawedzFormatkiV072
    var obrzeze: SpecyfikacjaObrzezaV072?

    var id: KrawedzFormatkiV072 { krawedz }
    var rodzaj: RodzajObrzezaV072 { obrzeze?.rodzaj ?? .brak }
}

struct PozycjaOkleinowaniaV072: Hashable, Identifiable {
    var formatka: FormatkaProjektuV070
    var obrobki: [ObrobkaKrawedziV072]

    var id: String { formatka.id }

    var liczbaOklejanychKrawedzi: Int {
        obrobki.filter { $0.obrzeze != nil }.count
    }

    var dlugoscNettoMM: Double {
        obrobki.reduce(0) { result, item in
            guard item.obrzeze != nil else { return result }
            return result + item.krawedz.dlugoscMM(dla: formatka)
        }
    }

    func rodzaj(dla krawedzi: KrawedzFormatkiV072) -> RodzajObrzezaV072 {
        obrobki.first { $0.krawedz == krawedzi }?.rodzaj ?? .brak
    }

    mutating func ustaw(
        _ rodzaj: RodzajObrzezaV072,
        dla krawedzi: KrawedzFormatkiV072
    ) {
        let spec = SpecyfikacjaObrzezaV072.wykonaj(
            rodzaj: rodzaj,
            material: formatka.material
        )

        if let index = obrobki.firstIndex(where: { $0.krawedz == krawedzi }) {
            obrobki[index].obrzeze = spec
        } else {
            obrobki.append(
                ObrobkaKrawedziV072(krawedz: krawedzi, obrzeze: spec)
            )
            obrobki.sort {
                let lhs = KrawedzFormatkiV072.allCases.firstIndex(of: $0.krawedz) ?? 0
                let rhs = KrawedzFormatkiV072.allCases.firstIndex(of: $1.krawedz) ?? 0
                return lhs < rhs
            }
        }
    }

    mutating func przelacz(_ krawedz: KrawedzFormatkiV072) {
        ustaw(rodzaj(dla: krawedz).kolejny, dla: krawedz)
    }
}

struct UstawieniaOkleinowaniaV072: Hashable {
    var naddatekNaKrawedzMM: Double
    var zapasProcent: Double

    static let standard = Self(
        naddatekNaKrawedzMM: 20,
        zapasProcent: 10
    )

    var poprawne: Bool {
        naddatekNaKrawedzMM.isFinite
            && zapasProcent.isFinite
            && naddatekNaKrawedzMM >= 0
            && zapasProcent >= 0
            && zapasProcent <= 100
    }
}

struct ZuzycieObrzezaV072: Hashable {
    var specyfikacja: SpecyfikacjaObrzezaV072
    var liczbaKrawedzi: Int
    var dlugoscNettoMM: Double
    var dlugoscTechnologicznaMM: Double
}

struct ZapotrzebowanieObrzezaV072: Hashable, Identifiable {
    var specyfikacja: SpecyfikacjaObrzezaV072
    var liczbaKrawedzi: Int
    var dlugoscNettoM: Double
    var dlugoscTechnologicznaM: Double
    var dlugoscZakupuM: Double

    var id: String { specyfikacja.id }
}

struct RaportOkleinowaniaV072: Hashable {
    var nazwaProjektu: String
    var dataUtworzenia: Date
    var ustawienia: UstawieniaOkleinowaniaV072
    var pozycje: [PozycjaOkleinowaniaV072]
    var zapotrzebowanie: [ZapotrzebowanieObrzezaV072]

    var liczbaFormatek: Int { pozycje.count }

    var liczbaFormatekDoOklejenia: Int {
        pozycje.filter { $0.liczbaOklejanychKrawedzi > 0 }.count
    }

    var liczbaKrawedzi: Int {
        zapotrzebowanie.reduce(0) { $0 + $1.liczbaKrawedzi }
    }

    var dlugoscNettoM: Double {
        zapotrzebowanie.reduce(0) { $0 + $1.dlugoscNettoM }
    }

    var dlugoscZakupuM: Double {
        zapotrzebowanie.reduce(0) { $0 + $1.dlugoscZakupuM }
    }
}

extension FurnitureComponentRole {
    var nazwaProdukcyjnaV072: String {
        switch self {
        case .side: return "Bok"
        case .top: return "Wieniec górny"
        case .bottom: return "Wieniec dolny"
        case .shelf: return "Półka"
        case .divider: return "Przegroda"
        case .back: return "Plecy"
        case .front: return "Front"
        case .worktop: return "Blat"
        case .plinth: return "Cokół"
        case .filler: return "Blenda"
        case .maskingPanel: return "Maskownica"
        case .decorativeSide: return "Bok dekoracyjny"
        case .reinforcement: return "Wzmocnienie"
        case .rail: return "Listwa"
        case .leg: return "Noga"
        case .custom: return "Element niestandardowy"
        }
    }
}
