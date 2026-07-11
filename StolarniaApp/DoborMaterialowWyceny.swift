import Foundation

struct WybranyMaterialWyceny: Hashable {
    var material: MaterialStolarski?
    var cenaJednostkowaNetto: Double
    var jednostka: String
    var zrodlo: String

    var opis: String {
        guard let material else {
            return "Wartość domyślna — brak pasującego aktywnego rekordu w bazie."
        }

        let kod = material.kodProducenta ?? material.kod
        return "\(material.producent) \(kod) — \(material.nazwa)"
    }
}

enum DoborMaterialowWyceny {
    static func plyta(
        wariant: WariantWyceny,
        materialy: [MaterialStolarski]
    ) -> WybranyMaterialWyceny {
        wybierz(
            wariant: wariant,
            typy: [.plytaLaminowana, .mdf],
            materialy: materialy,
            jednostka: "m²",
            fallback: 95,
            cena: { $0.cenaZaM2Netto }
        )
    }

    static func front(
        wariant: WariantWyceny,
        materialy: [MaterialStolarski]
    ) -> WybranyMaterialWyceny {
        let fallback: Double
        switch wariant {
        case .eco: fallback = 150
        case .standard: fallback = 240
        case .premium: fallback = 420
        case .vip: fallback = 650
        }

        return wybierz(
            wariant: wariant,
            typy: [.front],
            materialy: materialy,
            jednostka: "m²",
            fallback: fallback,
            cena: { $0.cenaZaM2Netto }
        )
    }

    static func dokladnyMaterialV068(
        id: UUID,
        materialy:
            [MaterialStolarski],
        jednostka:
            String = "m²"
    ) -> WybranyMaterialWyceny {
        guard let material =
            materialy.first(
                where: {
                    $0.id == id
                }
            )
        else {
            return WybranyMaterialWyceny(
                material: nil,
                cenaJednostkowaNetto:
                    0,
                jednostka:
                    jednostka,
                zrodlo:
                    "brak-materialu:\(id.uuidString.lowercased())"
            )
        }

        guard material.aktywny else {
            return WybranyMaterialWyceny(
                material:
                    material,
                cenaJednostkowaNetto:
                    0,
                jednostka:
                    jednostka,
                zrodlo:
                    "material-nieaktywny"
            )
        }

        let price: Double?

        switch jednostka {
        case "m²":
            price =
                material
                    .cenaZaM2Netto
        case "mb":
            price =
                material.jednostka
                    == .metrBiezacy
                ? material
                    .cenaPoRabacieNetto
                : nil
        default:
            price =
                material
                    .cenaPoRabacieNetto
        }

        guard let price,
              price > 0
        else {
            return WybranyMaterialWyceny(
                material:
                    material,
                cenaJednostkowaNetto:
                    0,
                jednostka:
                    jednostka,
                zrodlo:
                    "brak-ceny"
            )
        }

        return WybranyMaterialWyceny(
            material:
                material,
            cenaJednostkowaNetto:
                price,
            jednostka:
                jednostka,
            zrodlo:
                "material-id"
        )
    }

    static func blat(
        wariant: WariantWyceny,
        materialy: [MaterialStolarski]
    ) -> WybranyMaterialWyceny {
        let typy: [TypMaterialuStolarskiego]
        let fallback: Double

        switch wariant {
        case .eco:
            typy = [.blatLaminowany]
            fallback = 180
        case .standard:
            typy = [.blatLaminowany]
            fallback = 320
        case .premium:
            typy = [.blatKompaktowy, .blatLaminowany]
            fallback = 760
        case .vip:
            typy = [.blatKamienny, .blatKompaktowy]
            fallback = 1_350
        }

        return wybierz(
            wariant: wariant,
            typy: typy,
            materialy: materialy,
            jednostka: "mb",
            fallback: fallback,
            cena: { material in
                guard material.cenaPoRabacieNetto > 0 else {
                    return nil
                }
                return material.cenaPoRabacieNetto
            }
        )
    }

    private static func wybierz(
        wariant: WariantWyceny,
        typy: [TypMaterialuStolarskiego],
        materialy: [MaterialStolarski],
        jednostka: String,
        fallback: Double,
        cena: (MaterialStolarski) -> Double?
    ) -> WybranyMaterialWyceny {
        let kandydaci = materialy
            .filter { $0.aktywny && typy.contains($0.typ) }
            .compactMap { material -> (MaterialStolarski, Double)? in
                guard let value = cena(material), value > 0 else {
                    return nil
                }
                return (material, value)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.kod.localizedStandardCompare(rhs.0.kod)
                        == .orderedAscending
                }
                return lhs.1 < rhs.1
            }

        guard !kandydaci.isEmpty else {
            return WybranyMaterialWyceny(
                material: nil,
                cenaJednostkowaNetto: fallback,
                jednostka: jednostka,
                zrodlo: "fallback"
            )
        }

        let fraction: Double
        switch wariant {
        case .eco: fraction = 0.10
        case .standard: fraction = 0.40
        case .premium: fraction = 0.72
        case .vip: fraction = 0.95
        }

        let index = min(
            max(Int((Double(kandydaci.count - 1) * fraction).rounded()), 0),
            kandydaci.count - 1
        )
        let selected = kandydaci[index]

        return WybranyMaterialWyceny(
            material: selected.0,
            cenaJednostkowaNetto: selected.1,
            jednostka: jednostka,
            zrodlo: "baza-materialow"
        )
    }
}
