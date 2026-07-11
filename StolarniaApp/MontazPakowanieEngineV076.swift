import DomainCore
import Foundation

enum MontazPakowanieEngineV076 {
    static func build(
        list: ListaFormatekProjektuV070,
        settings:
            UstawieniaMontazuIPakowaniaV076
    ) -> RaportMontazuIPakowaniaV076 {
        guard settings.poprawne else {
            return RaportMontazuIPakowaniaV076(
                nazwaProjektu:
                    list.nazwaProjektu,
                dataUtworzenia: Date(),
                moduly: [],
                operacje: [],
                paczki: [],
                ostrzezenia: [
                    OstrzezeniePakowaniaV076(
                        id:
                            "USTAWIENIA-NIEPOPRAWNE",
                        poziom: .blad,
                        tytul:
                            "Niepoprawne ustawienia pakowania",
                        opis:
                            "Popraw limity masy, liczbę elementów, progi i gęstości materiałów.",
                        kodPaczki: nil
                    )
                ]
            )
        }

        let groups = Dictionary(
            grouping:
                list.formatki
        ) {
            ModuleKey(
                index:
                    $0.indeksModulu,
                name:
                    $0.nazwaModulu
            )
        }

        let orderedGroups = groups
            .map {
                (
                    key: $0.key,
                    parts: $0.value
                )
            }
            .sorted {
                if $0.key.index
                    != $1.key.index {
                    return $0.key.index
                        < $1.key.index
                }

                return $0.key.name
                    .localizedStandardCompare(
                        $1.key.name
                    )
                    == .orderedAscending
            }

        var allOperations:
            [OperacjaMontazowaV076] = []
        var allPackages:
            [PaczkaProdukcyjnaV076] = []
        var allWarnings:
            [OstrzezeniePakowaniaV076] = []
        var modules:
            [ModulMontazowyV076] = []

        for group in orderedGroups {
            let parts = group.parts.sorted(
                by: partOrder
            )
            let operations =
                operations(
                    module: group.key,
                    parts: parts
                )
            let packing =
                packages(
                    module: group.key,
                    parts: parts,
                    settings: settings
                )

            allOperations.append(
                contentsOf: operations
            )
            allPackages.append(
                contentsOf:
                    packing.packages
            )
            allWarnings.append(
                contentsOf:
                    packing.warnings
            )

            modules.append(
                ModulMontazowyV076(
                    id:
                        moduleID(group.key),
                    indeks:
                        group.key.index,
                    nazwa:
                        group.key.name,
                    operacje:
                        operations,
                    kodyPaczek:
                        packing.packages
                            .map(\.kod)
                )
            )
        }

        return RaportMontazuIPakowaniaV076(
            nazwaProjektu:
                list.nazwaProjektu,
            dataUtworzenia: Date(),
            moduly: modules,
            operacje:
                allOperations.sorted(
                    by: operationOrder
                ),
            paczki:
                allPackages.sorted(
                    by: packageOrder
                ),
            ostrzezenia:
                allWarnings.sorted(
                    by: warningOrder
                )
        )
    }

    private struct ModuleKey:
        Hashable
    {
        var index: Int
        var name: String
    }

    private struct PackageBuildResult {
        var packages:
            [PaczkaProdukcyjnaV076]
        var warnings:
            [OstrzezeniePakowaniaV076]
    }

    private static func operations(
        module: ModuleKey,
        parts: [FormatkaProjektuV070]
    ) -> [OperacjaMontazowaV076] {
        guard !parts.isEmpty else {
            return []
        }

        var result:
            [OperacjaMontazowaV076] = []

        result.append(
            makeOperation(
                module: module,
                stage: .przygotowanie,
                order: 0,
                code: "KOMPLET",
                title:
                    "Skompletuj elementy modułu",
                description:
                    "Porównaj etykiety z listą formatek i odłóż elementy uszkodzone albo niezgodne wymiarowo.",
                parts: parts,
                requiresVerification:
                    parts.contains {
                        $0.wspoldzielona
                    }
            )
        )

        let carcass = parts.filter {
            isCarcassRole(
                $0.rolaKomponentu
            )
        }

        if !carcass.isEmpty {
            result.append(
                makeOperation(
                    module: module,
                    stage: .korpus,
                    order: 10,
                    code: "KORPUS",
                    title:
                        "Zmontuj korpus",
                    description:
                        "Połącz boki, wieńce, dna i przegrody. Przed trwałym skręceniem sprawdź kąty oraz przekątne.",
                    parts: carcass,
                    requiresVerification:
                        carcass.contains {
                            $0.wspoldzielona
                        }
                )
            )
        }

        let backs = parts.filter {
            switch $0.rolaKomponentu {
            case .back:
                return true
            default:
                return false
            }
        }

        if !backs.isEmpty {
            result.append(
                makeOperation(
                    module: module,
                    stage: .plecy,
                    order: 20,
                    code: "PLECY",
                    title:
                        "Zamontuj plecy",
                    description:
                        "Ustaw korpus w kącie prostym, osadź plecy w rowku lub na krawędzi i skontroluj przekątne.",
                    parts: backs,
                    requiresVerification:
                        backs.contains {
                            $0.wspoldzielona
                        }
                )
            )
        }

        let shelves = parts.filter {
            switch $0.rolaKomponentu {
            case .shelf:
                return true
            default:
                return false
            }
        }

        if !shelves.isEmpty {
            result.append(
                makeOperation(
                    module: module,
                    stage: .wyposazenie,
                    order: 30,
                    code: "POLKI",
                    title:
                        "Osadź półki",
                    description:
                        "Sprawdź wysokości, kierunek dekoru oraz komplet podpórek przed włożeniem półek.",
                    parts: shelves,
                    requiresVerification: false
                )
            )
        }

        let legsAndRails = parts.filter {
            switch $0.rolaKomponentu {
            case .leg, .rail:
                return true
            default:
                return false
            }
        }

        if !legsAndRails.isEmpty {
            result.append(
                makeOperation(
                    module: module,
                    stage: .wyposazenie,
                    order: 31,
                    code: "WYPOSAZ",
                    title:
                        "Zamontuj wyposażenie konstrukcyjne",
                    description:
                        "Zamontuj nogi, listwy i elementy nośne. Sprawdź stabilność oraz przewidziane punkty mocowania.",
                    parts: legsAndRails,
                    requiresVerification:
                        legsAndRails.contains {
                            $0.wspoldzielona
                        }
                )
            )
        }

        let fronts = parts.filter {
            switch $0.rolaKomponentu {
            case .front:
                return true
            default:
                return false
            }
        }

        if !fronts.isEmpty {
            result.append(
                makeOperation(
                    module: module,
                    stage: .fronty,
                    order: 40,
                    code: "FRONTY",
                    title:
                        "Zamontuj i wyreguluj fronty",
                    description:
                        "Dobierz fronty według etykiet, zachowaj szczeliny projektu i wykonaj regulację w trzech osiach.",
                    parts: fronts,
                    requiresVerification: true
                )
            )
        }

        let worktops = parts.filter {
            switch $0.rolaKomponentu {
            case .worktop:
                return true
            default:
                return false
            }
        }

        if !worktops.isEmpty {
            result.append(
                makeOperation(
                    module: module,
                    stage: .wykonczenie,
                    order: 50,
                    code: "BLAT",
                    title:
                        "Przymierz i zamocuj blat",
                    description:
                        "Sprawdź stronę dekoru, wysunięcia, połączenia i miejsca wycięć przed ostatecznym mocowaniem.",
                    parts: worktops,
                    requiresVerification: true
                )
            )
        }

        let finishing = parts.filter {
            switch $0.rolaKomponentu {
            case .plinth,
                 .filler,
                 .maskingPanel,
                 .decorativeSide:
                return true
            default:
                return false
            }
        }

        if !finishing.isEmpty {
            result.append(
                makeOperation(
                    module: module,
                    stage: .wykonczenie,
                    order: 51,
                    code: "WYKONCZENIE",
                    title:
                        "Zamontuj cokoły i elementy maskujące",
                    description:
                        "Dopasuj elementy widoczne, sprawdź kierunek dekoru i zabezpiecz powierzchnie przed montażem.",
                    parts: finishing,
                    requiresVerification: true
                )
            )
        }

        let custom = parts.filter {
            switch $0.rolaKomponentu {
            case .custom:
                return true
            default:
                return false
            }
        }

        if !custom.isEmpty {
            result.append(
                makeOperation(
                    module: module,
                    stage: .wykonczenie,
                    order: 52,
                    code: "CUSTOM",
                    title:
                        "Zweryfikuj elementy niestandardowe",
                    description:
                        "Elementy niestandardowe wymagają potwierdzenia sposobu montażu na dokumentacji projektu.",
                    parts: custom,
                    requiresVerification: true
                )
            )
        }

        result.append(
            makeOperation(
                module: module,
                stage: .kontrola,
                order: 90,
                code: "KONTROLA",
                title:
                    "Wykonaj kontrolę końcową",
                description:
                    "Sprawdź wymiary, kąty, szczeliny, działanie frontów, komplet okuć, czystość i zabezpieczenie do transportu.",
                parts: [],
                requiresVerification: true
            )
        )

        return result.sorted(
            by: operationOrder
        )
    }

    private static func makeOperation(
        module: ModuleKey,
        stage: EtapMontazuV076,
        order: Int,
        code: String,
        title: String,
        description: String,
        parts: [FormatkaProjektuV070],
        requiresVerification: Bool
    ) -> OperacjaMontazowaV076 {
        let orderedParts =
            parts.sorted {
                let labelResult =
                    $0.etykieta
                    .localizedStandardCompare(
                        $1.etykieta
                    )

                if labelResult == .orderedSame {
                    return $0.id
                        .localizedStandardCompare(
                            $1.id
                        )
                        == .orderedAscending
                }

                return labelResult
                    == .orderedAscending
            }

        return OperacjaMontazowaV076(
            id:
                [
                    moduleID(module),
                    stage.rawValue,
                    code
                ]
                .joined(separator: "|"),
            indeksModulu:
                module.index,
            nazwaModulu:
                module.name,
            etap: stage,
            kolejnosc: order,
            tytul: title,
            opis: description,
            formatkaIDs:
                orderedParts
                    .map(\.id),
            etykietyFormatek:
                orderedParts
                    .map(\.etykieta),
            wymagaWeryfikacji:
                requiresVerification
        )
    }

    private static func packages(
        module: ModuleKey,
        parts: [FormatkaProjektuV070],
        settings:
            UstawieniaMontazuIPakowaniaV076
    ) -> PackageBuildResult {
        let typed = Dictionary(
            grouping: parts
        ) {
            packageType(
                for: $0,
                settings: settings
            )
        }

        var packages:
            [PaczkaProdukcyjnaV076] = []
        var warnings:
            [OstrzezeniePakowaniaV076] = []

        for type in TypPaczkiV076.allCases {
            guard let typeParts =
                    typed[type],
                  !typeParts.isEmpty else {
                continue
            }

            let items = typeParts
                .map {
                    packageItem(
                        from: $0,
                        settings: settings
                    )
                }
                .sorted(
                    by: packageItemOrder
                )

            let buckets = makeBuckets(
                items: items,
                settings: settings
            )

            for (
                bucketOffset,
                bucket
            ) in buckets.enumerated() {
                let number =
                    bucketOffset + 1
                let code = packageCode(
                    module: module,
                    type: type,
                    number: number
                )
                let weight =
                    bucket.reduce(0) {
                        $0
                            + $1
                                .szacowanaMasaKG
                    }
                let longest =
                    bucket
                        .map(
                            \.najdluzszyWymiarMM
                        )
                        .max()
                    ?? 0
                let exceeds =
                    weight
                    > settings
                        .maksymalnaMasaPaczkiKG
                    + 0.000_1
                let handling =
                    handlingMethod(
                        weightKG: weight,
                        longestMM: longest,
                        settings: settings
                    )

                let package =
                    PaczkaProdukcyjnaV076(
                        id:
                            [
                                moduleID(module),
                                type.rawValue,
                                String(number)
                            ]
                            .joined(
                                separator: "|"
                            ),
                        kod: code,
                        indeksModulu:
                            module.index,
                        nazwaModulu:
                            module.name,
                        typ: type,
                        numerWTymTypie:
                            number,
                        pozycje: bucket,
                        szacowanaMasaKG:
                            weight,
                        najdluzszyWymiarMM:
                            longest,
                        sposobPrzenoszenia:
                            handling,
                        przekraczaLimitMasy:
                            exceeds
                    )

                packages.append(package)

                if exceeds {
                    warnings.append(
                        OstrzezeniePakowaniaV076(
                            id:
                                "\(code)|MASA",
                            poziom: .blad,
                            tytul:
                                "Przekroczony limit masy",
                            opis:
                                "\(code) waży szacunkowo \(formatKGV076(weight)) kg przy limicie \(formatKGV076(settings.maksymalnaMasaPaczkiKG)) kg. Podziel paczkę ręcznie lub zmień limit.",
                            kodPaczki: code
                        )
                    )
                }

                if handling
                    == .dlugiElement {
                    warnings.append(
                        OstrzezeniePakowaniaV076(
                            id:
                                "\(code)|DLUGOSC",
                            poziom: .uwaga,
                            tytul:
                                "Długi element",
                            opis:
                                "\(code) zawiera element o długości \(formatMMV076(longest)) mm. Zaplanuj podparcie i transport bez ugięcia.",
                            kodPaczki: code
                        )
                    )
                } else if handling
                    == .dwieOsoby {
                    warnings.append(
                        OstrzezeniePakowaniaV076(
                            id:
                                "\(code)|DWA",
                            poziom:
                                .informacja,
                            tytul:
                                "Przenoszenie przez dwie osoby",
                            opis:
                                "\(code) wymaga dwóch osób ze względu na szacowaną masę lub gabaryt.",
                            kodPaczki: code
                        )
                    )
                }
            }
        }

        return PackageBuildResult(
            packages:
                packages.sorted(
                    by: packageOrder
                ),
            warnings:
                warnings.sorted(
                    by: warningOrder
                )
        )
    }

    private static func makeBuckets(
        items: [PozycjaPaczkiV076],
        settings:
            UstawieniaMontazuIPakowaniaV076
    ) -> [[PozycjaPaczkiV076]] {
        var buckets:
            [[PozycjaPaczkiV076]] = []

        for item in items {
            if item.najdluzszyWymiarMM
                >= settings
                    .progDlugiegoElementuMM {
                buckets.append([item])
                continue
            }

            var bestIndex: Int?
            var bestRemaining =
                Double.greatestFiniteMagnitude

            for index in buckets.indices {
                let bucket =
                    buckets[index]

                guard bucket.count
                    < settings
                        .maksymalnaLiczbaElementow,
                      bucket.allSatisfy({
                          $0.najdluzszyWymiarMM
                              < settings
                                  .progDlugiegoElementuMM
                      }) else {
                    continue
                }

                let weight =
                    bucket.reduce(0) {
                        $0
                            + $1
                                .szacowanaMasaKG
                    }
                let combined =
                    weight
                    + item
                        .szacowanaMasaKG

                guard combined
                    <= settings
                        .maksymalnaMasaPaczkiKG
                    + 0.000_1 else {
                    continue
                }

                let remaining =
                    settings
                        .maksymalnaMasaPaczkiKG
                    - combined

                if remaining < bestRemaining {
                    bestRemaining =
                        remaining
                    bestIndex = index
                }
            }

            if let bestIndex {
                buckets[bestIndex]
                    .append(item)
            } else {
                buckets.append([item])
            }
        }

        return buckets
    }

    private static func packageItem(
        from part: FormatkaProjektuV070,
        settings:
            UstawieniaMontazuIPakowaniaV076
    ) -> PozycjaPaczkiV076 {
        let density:
            Double

        switch part.kategoria {
        case .plecy:
            density =
                settings
                    .gestoscPlecowKGNaM3
        case .blat:
            density =
                settings
                    .gestoscBlatuKGNaM3
        default:
            density =
                settings
                    .gestoscPlytyKGNaM3
        }

        let volumeM3 =
            part.dlugoscMM
            * part.szerokoscMM
            * part.gruboscMM
            / 1_000_000_000

        let reserveFactor =
            1
            + settings
                .zapasMasyProcent
                / 100
        let weight =
            max(
                0,
                volumeM3
                    * density
                    * reserveFactor
            )

        return PozycjaPaczkiV076(
            id: part.id,
            etykieta:
                part.etykieta,
            nazwaModulu:
                part.nazwaModulu,
            kodKomponentu:
                part.kodKomponentu,
            kategoria:
                part.kategoria,
            material:
                part.material,
            dlugoscMM:
                part.dlugoscMM,
            szerokoscMM:
                part.szerokoscMM,
            gruboscMM:
                part.gruboscMM,
            szacowanaMasaKG:
                weight
        )
    }

    private static func packageType(
        for part: FormatkaProjektuV070,
        settings:
            UstawieniaMontazuIPakowaniaV076
    ) -> TypPaczkiV076 {
        switch part.kategoria {
        case .front:
            return settings.osobnoFronty
                ? .fronty
                : .korpus
        case .plecy:
            return .plecy
        case .blat:
            return settings.osobnoBlaty
                ? .blaty
                : .korpus
        case .maskownice,
             .cokół:
            return .maskownice
        case .korpus:
            return .korpus
        case .pozostale:
            return .pozostale
        }
    }

    private static func handlingMethod(
        weightKG: Double,
        longestMM: Double,
        settings:
            UstawieniaMontazuIPakowaniaV076
    ) -> SposobPrzenoszeniaV076 {
        if longestMM
            >= settings
                .progDlugiegoElementuMM {
            return .dlugiElement
        }

        if weightKG
            >= settings
                .progDwochOsobKG
            || longestMM >= 1_800 {
            return .dwieOsoby
        }

        return .jednaOsoba
    }

    private static func packageCode(
        module: ModuleKey,
        type: TypPaczkiV076,
        number: Int
    ) -> String {
        String(
            format:
                "P-M%02d-%@-%02d",
            module.index,
            type.skrot,
            number
        )
    }

    private static func moduleID(
        _ module: ModuleKey
    ) -> String {
        [
            String(module.index),
            module.name
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()
        ]
        .joined(separator: "|")
    }

    private static func isCarcassRole(
        _ role: FurnitureComponentRole
    ) -> Bool {
        switch role {
        case .side,
             .top,
             .bottom,
             .divider,
             .reinforcement:
            return true
        default:
            return false
        }
    }

    private static func partOrder(
        _ lhs: FormatkaProjektuV070,
        _ rhs: FormatkaProjektuV070
    ) -> Bool {
        if lhs.indeksModulu
            != rhs.indeksModulu {
            return lhs.indeksModulu
                < rhs.indeksModulu
        }

        return standardOrder(
            lhs.etykieta,
            rhs.etykieta
        )
    }

    private static func operationOrder(
        _ lhs: OperacjaMontazowaV076,
        _ rhs: OperacjaMontazowaV076
    ) -> Bool {
        if lhs.indeksModulu
            != rhs.indeksModulu {
            return lhs.indeksModulu
                < rhs.indeksModulu
        }

        if lhs.etap.kolejnosc
            != rhs.etap.kolejnosc {
            return lhs.etap.kolejnosc
                < rhs.etap.kolejnosc
        }

        if lhs.kolejnosc
            != rhs.kolejnosc {
            return lhs.kolejnosc
                < rhs.kolejnosc
        }

        return standardOrder(
            lhs.tytul,
            rhs.tytul
        )
    }

    private static func packageOrder(
        _ lhs: PaczkaProdukcyjnaV076,
        _ rhs: PaczkaProdukcyjnaV076
    ) -> Bool {
        if lhs.indeksModulu
            != rhs.indeksModulu {
            return lhs.indeksModulu
                < rhs.indeksModulu
        }

        if lhs.typ.rawValue
            != rhs.typ.rawValue {
            return lhs.typ.rawValue
                < rhs.typ.rawValue
        }

        return lhs.numerWTymTypie
            < rhs.numerWTymTypie
    }

    private static func packageItemOrder(
        _ lhs: PozycjaPaczkiV076,
        _ rhs: PozycjaPaczkiV076
    ) -> Bool {
        if lhs.najdluzszyWymiarMM
            != rhs.najdluzszyWymiarMM {
            return lhs
                .najdluzszyWymiarMM
                > rhs
                    .najdluzszyWymiarMM
        }

        if lhs.szacowanaMasaKG
            != rhs.szacowanaMasaKG {
            return lhs
                .szacowanaMasaKG
                > rhs
                    .szacowanaMasaKG
        }

        return standardOrder(
            lhs.etykieta,
            rhs.etykieta
        )
    }

    private static func warningOrder(
        _ lhs: OstrzezeniePakowaniaV076,
        _ rhs: OstrzezeniePakowaniaV076
    ) -> Bool {
        if warningRank(lhs.poziom)
            != warningRank(rhs.poziom) {
            return warningRank(
                lhs.poziom
            )
            > warningRank(
                rhs.poziom
            )
        }

        return standardOrder(
            lhs.id,
            rhs.id
        )
    }

    private static func warningRank(
        _ level:
            PoziomOstrzezeniaPakowaniaV076
    ) -> Int {
        switch level {
        case .informacja:
            return 0
        case .uwaga:
            return 1
        case .blad:
            return 2
        }
    }

    private static func standardOrder(
        _ lhs: String,
        _ rhs: String
    ) -> Bool {
        lhs.localizedStandardCompare(
            rhs
        ) == .orderedAscending
    }
}
