import Foundation

enum JednostkaCenyRynkowejPlyty:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case sztuka
    case metrKwadratowy

    var id: String { rawValue }

    var skrot: String {
        switch self {
        case .sztuka:
            return "szt."
        case .metrKwadratowy:
            return "m²"
        }
    }
}

struct CenaRynkowaPlyty:
    Identifiable,
    Codable,
    Hashable
{
    var id: String
    var producent: String
    var kodProducenta: String
    var struktura: String
    var gruboscMM: Double
    var szerokoscMM: Double
    var wysokoscMM: Double
    var cenaSredniaBruttoPLN: Double
    var cenaMinimalnaBruttoPLN: Double
    var cenaMaksymalnaBruttoPLN: Double
    var liczbaProbek: Int
    var jednostka:
        JednostkaCenyRynkowejPlyty
    var dataResearchu: Date
    var opisZakresu: String
    var zrodla: [String]

    var cenaSredniaNettoPLN: Double {
        cenaSredniaBruttoPLN / 1.23
    }

    var powierzchniaArkuszaM2: Double {
        guard
            szerokoscMM > 0,
            wysokoscMM > 0
        else {
            return 0
        }

        return (
            szerokoscMM
            * wysokoscMM
        ) / 1_000_000
    }

    var cenaSredniaBruttoZaM2PLN:
        Double?
    {
        guard
            powierzchniaArkuszaM2 > 0
        else {
            return nil
        }

        return cenaSredniaBruttoPLN
            / powierzchniaArkuszaM2
    }
}

enum CennikRynkowyPlyt {
    static let migrationVersion =
        2026062001

    static let dataResearchu:
        Date = {
            var components =
                DateComponents()
            components.calendar =
                Calendar(
                    identifier:
                        .gregorian
                )
            components.timeZone =
                TimeZone(
                    secondsFromGMT: 0
                )
            components.year = 2026
            components.month = 6
            components.day = 20
            return components.date
                ?? Date(
                    timeIntervalSince1970: 0
                )
        }()

    static let pozycje:
        [CenaRynkowaPlyty] = [
            cena(
                id:
                    "egger.uni.18.2800x2070",
                producent: "EGGER",
                kod: "W1100",
                struktura: "ST9",
                srednia: 412.51,
                min: 395.92,
                max: 429.10,
                probki: 2,
                opis:
                    "Reprezentant grupy dekorów jednobarwnych EGGER: płyta laminowana W1100 ST9, 18 mm, 2800 × 2070 mm.",
                zrodla: [
                    "WIP Rumia — 429,10 zł brutto/szt.",
                    "M-HM — 395,92 zł brutto/szt."
                ]
            ),
            cena(
                id:
                    "egger.wood.18.2800x2070",
                producent: "EGGER",
                kod: "H3303",
                struktura: "ST10",
                srednia: 450.83,
                min: 407.28,
                max: 515.96,
                probki: 3,
                opis:
                    "Reprezentant grupy dekorów drewnopodobnych EGGER: płyta laminowana H3303 ST10, 18 mm, 2800 × 2070 mm.",
                zrodla: [
                    "M-HM — 407,28 zł brutto/szt.",
                    "Belmeb — 429,24 zł brutto/szt.",
                    "Hadson 2 — 515,96 zł brutto/szt."
                ]
            ),
            cena(
                id:
                    "egger.material.18.2800x2070",
                producent: "EGGER",
                kod: "F206",
                struktura: "ST9",
                srednia: 528.92,
                min: 526.93,
                max: 530.91,
                probki: 2,
                opis:
                    "Reprezentant grupy dekorów kamiennych i materiałowych EGGER: płyta laminowana F206 ST9, 18 mm, 2800 × 2070 mm.",
                zrodla: [
                    "WIP Rumia — 526,93 zł brutto/szt.",
                    "M-HM — 530,91 zł brutto/szt."
                ]
            ),
            cena(
                id:
                    "kronospan.uni.18.2800x2070",
                producent: "Kronospan",
                kod: "0101",
                struktura: "PE",
                srednia: 272.74,
                min: 272.41,
                max: 273.06,
                probki: 2,
                opis:
                    "Reprezentant grupy dekorów jednobarwnych Kronospan: płyta laminowana 0101 PE, 18 mm, 2800 × 2070 mm.",
                zrodla: [
                    "Kronosfera — 273,06 zł brutto/szt.",
                    "Beta Meble — 272,41 zł brutto/szt."
                ]
            ),
            cena(
                id:
                    "kronospan.wood.18.2800x2070",
                producent: "Kronospan",
                kod: "K003",
                struktura: "PW",
                srednia: 226.27,
                min: 184.00,
                max: 260.82,
                probki: 4,
                opis:
                    "Reprezentant grupy dekorów drewnopodobnych Kronospan: płyta laminowana K003 PW, 18 mm, 2800 × 2070 mm.",
                zrodla: [
                    "Modiy — 184,00 zł brutto/szt.",
                    "Intar — 227,78 zł brutto/szt.",
                    "Kronosfera — 232,47 zł brutto/szt.",
                    "Beta Meble — 260,82 zł brutto/szt."
                ]
            ),
            cena(
                id:
                    "kronospan.material.18.2800x2070",
                producent: "Kronospan",
                kod: "K349",
                struktura: "RT",
                srednia: 369.62,
                min: 360.39,
                max: 378.84,
                probki: 2,
                opis:
                    "Reprezentant grupy dekorów materiałowych Kronospan: płyta laminowana K349 RT, 18 mm, 2800 × 2070 mm.",
                zrodla: [
                    "Strefa Płyt — 360,39 zł brutto/szt.",
                    "Kronosfera / Strefa Projektanta — 378,84 zł brutto/szt."
                ]
            )
        ]

    static func cena(
        id: String
    ) -> CenaRynkowaPlyty? {
        pozycje.first {
            $0.id
                .caseInsensitiveCompare(
                    id
                )
            == .orderedSame
        }
    }

    static func cenaDokladna(
        producent: String,
        kodProducenta: String,
        struktura: String
    ) -> CenaRynkowaPlyty? {
        pozycje.first {
            $0.producent
                .caseInsensitiveCompare(
                    producent
                )
            == .orderedSame
            && $0.kodProducenta
                .caseInsensitiveCompare(
                    kodProducenta
                )
            == .orderedSame
            && $0.struktura
                .caseInsensitiveCompare(
                    struktura
                )
            == .orderedSame
        }
    }

    static func cenaReferencyjna(
        producent: String,
        grupaDekoru: String
    ) -> CenaRynkowaPlyty? {
        let producer =
            producent
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()

        let group =
            grupaDekoru
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()
                .folding(
                    options:
                        .diacriticInsensitive,
                    locale:
                        Locale(
                            identifier:
                                "pl_PL"
                        )
                )
                .replacingOccurrences(
                    of: "ł",
                    with: "l"
                )

        let id: String?

        if producer == "egger" {
            if group.contains("drew") {
                id =
                    "egger.wood.18.2800x2070"
            } else if group.contains("kam")
                || group.contains("material") {
                id =
                    "egger.material.18.2800x2070"
            } else {
                id =
                    "egger.uni.18.2800x2070"
            }
        } else if producer
            .contains("kronospan") {
            if group.contains("drew") {
                id =
                    "kronospan.wood.18.2800x2070"
            } else if group.contains("kam")
                || group.contains("material") {
                id =
                    "kronospan.material.18.2800x2070"
            } else {
                id =
                    "kronospan.uni.18.2800x2070"
            }
        } else {
            id = nil
        }

        guard let id else {
            return nil
        }

        return cena(id: id)
    }

    private static func cena(
        id: String,
        producent: String,
        kod: String,
        struktura: String,
        srednia: Double,
        min: Double,
        max: Double,
        probki: Int,
        opis: String,
        zrodla: [String]
    ) -> CenaRynkowaPlyty {
        CenaRynkowaPlyty(
            id: id,
            producent: producent,
            kodProducenta: kod,
            struktura: struktura,
            gruboscMM: 18,
            szerokoscMM: 2800,
            wysokoscMM: 2070,
            cenaSredniaBruttoPLN:
                srednia,
            cenaMinimalnaBruttoPLN:
                min,
            cenaMaksymalnaBruttoPLN:
                max,
            liczbaProbek:
                probki,
            jednostka: .sztuka,
            dataResearchu:
                dataResearchu,
            opisZakresu: opis,
            zrodla: zrodla
        )
    }
}

extension MaterialStolarski {
    var cenaRynkowaPlyty:
        CenaRynkowaPlyty?
    {
        if let referenceID =
            cenaReferencyjnaPlytyID,
           let exact =
            CennikRynkowyPlyt
                .cena(
                    id: referenceID
                ) {
            return exact
        }

        if let producerCode =
            kodProducenta,
           let structure =
            struktura,
           let exact =
            CennikRynkowyPlyt
                .cenaDokladna(
                    producent:
                        producent,
                    kodProducenta:
                        producerCode,
                    struktura:
                        structure
                ) {
            return exact
        }

        return CennikRynkowyPlyt
            .cenaReferencyjna(
                producent:
                    producent,
                grupaDekoru:
                    grupaDekoru
                    ?? ""
            )
    }

    var cenaRynkowaPlytyJestDokladna:
        Bool
    {
        guard
            let producerCode =
                kodProducenta,
            let structure =
                struktura,
            let price =
                cenaRynkowaPlyty
        else {
            return false
        }

        return price.producent
            .caseInsensitiveCompare(
                producent
            )
            == .orderedSame
            && price.kodProducenta
                .caseInsensitiveCompare(
                    producerCode
                )
            == .orderedSame
            && price.struktura
                .caseInsensitiveCompare(
                    structure
                )
            == .orderedSame
    }
}
