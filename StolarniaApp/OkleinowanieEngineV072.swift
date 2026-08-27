import DomainCore
import Foundation

enum OkleinowanieEngineV072 {
    static func automatycznePozycje(
        dla listy: ListaFormatekProjektuV070
    ) -> [PozycjaOkleinowaniaV072] {
        listy.formatki.map { automatycznaPozycja(dla: $0) }
    }

    static func automatycznaPozycja(
        dla formatki: FormatkaProjektuV070
    ) -> PozycjaOkleinowaniaV072 {
        var result = PozycjaOkleinowaniaV072(
            formatka: formatki,
            obrobki: KrawedzFormatkiV072.allCases.map {
                ObrobkaKrawedziV072(krawedz: $0, obrzeze: nil)
            }
        )

        for (edge, type) in regula(dla: formatki.rolaKomponentu) {
            result.ustaw(type, dla: edge)
        }
        return result
    }

    static func raport(
        nazwaProjektu: String,
        pozycje: [PozycjaOkleinowaniaV072],
        ustawienia: UstawieniaOkleinowaniaV072
    ) -> RaportOkleinowaniaV072 {
        guard ustawienia.poprawne else {
            return RaportOkleinowaniaV072(
                nazwaProjektu: nazwaProjektu,
                dataUtworzenia: Date(),
                ustawienia: ustawienia,
                pozycje: pozycje,
                zapotrzebowanie: []
            )
        }

        var groups: [SpecyfikacjaObrzezaV072: ZuzycieObrzezaV072] = [:]

        for item in pozycje {
            for operation in item.obrobki {
                guard let edgeBand = operation.obrzeze else { continue }

                let net = operation.krawedz.dlugoscMM(dla: item.formatka)
                guard net.isFinite, net > 0 else { continue }

                var usage = groups[edgeBand] ?? ZuzycieObrzezaV072(
                    specyfikacja: edgeBand,
                    liczbaKrawedzi: 0,
                    dlugoscNettoMM: 0,
                    dlugoscTechnologicznaMM: 0
                )
                usage.liczbaKrawedzi += 1
                usage.dlugoscNettoMM += net
                usage.dlugoscTechnologicznaMM +=
                    net + ustawienia.naddatekNaKrawedzMM
                groups[edgeBand] = usage
            }
        }

        let reserve = 1 + ustawienia.zapasProcent / 100
        let demand = groups.values.map { usage in
            ZapotrzebowanieObrzezaV072(
                specyfikacja: usage.specyfikacja,
                liczbaKrawedzi: usage.liczbaKrawedzi,
                dlugoscNettoM: usage.dlugoscNettoMM / 1_000,
                dlugoscTechnologicznaM:
                    usage.dlugoscTechnologicznaMM / 1_000,
                dlugoscZakupuM:
                    usage.dlugoscTechnologicznaMM / 1_000 * reserve
            )
        }
        .sorted {
            let lhs = $0.specyfikacja.rodzaj.gruboscMM
            let rhs = $1.specyfikacja.rodzaj.gruboscMM
            if lhs != rhs { return lhs < rhs }
            return $0.specyfikacja.opis.localizedStandardCompare(
                $1.specyfikacja.opis
            ) == .orderedAscending
        }

        return RaportOkleinowaniaV072(
            nazwaProjektu: nazwaProjektu,
            dataUtworzenia: Date(),
            ustawienia: ustawienia,
            pozycje: pozycje,
            zapotrzebowanie: demand
        )
    }

    static func wyczysc(
        _ pozycje: [PozycjaOkleinowaniaV072]
    ) -> [PozycjaOkleinowaniaV072] {
        pozycje.map { item in
            var copy = item
            for edge in KrawedzFormatkiV072.allCases {
                copy.ustaw(.brak, dla: edge)
            }
            return copy
        }
    }

    private static func regula(
        dla roli: FurnitureComponentRole
    ) -> [(KrawedzFormatkiV072, RodzajObrzezaV072)] {
        switch roli {
        case .front, .filler, .maskingPanel, .decorativeSide:
            return [
                (.dlugaA, .abs20),
                (.dlugaB, .abs20),
                (.krotkaA, .abs20),
                (.krotkaB, .abs20)
            ]
        case .worktop:
            return [
                (.dlugaA, .abs20),
                (.krotkaA, .abs20),
                (.krotkaB, .abs20)
            ]
        case .side, .top, .bottom, .shelf, .divider:
            return [(.dlugaA, .abs08)]
        case .plinth:
            return [
                (.dlugaA, .abs08),
                (.krotkaA, .abs08),
                (.krotkaB, .abs08)
            ]
        case .reinforcement, .rail:
            return [(.dlugaA, .abs08)]
        // Skrzynka szuflady: obrzeże **tylko na górnej krawędzi** boków,
        // tyłu i dna — to jedyna krawędź, której się dotyka przy wkładaniu
        // rzeczy. Pozostałe są zakryte przez sąsiednie elementy skrzynki.
        case .drawerBox:
            return [(.dlugaA, .abs08)]
        case .back, .leg, .custom:
            return []
        }
    }
}
