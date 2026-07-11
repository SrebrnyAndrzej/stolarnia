import DomainCore
import Foundation

enum ProjektWycenyBuilder {
    static func zbuduj(
        nazwaProjektu: String,
        assemblies:
            [FurnitureAssembly],
        materialyPomieszczen:
            [String:
                GlobalneMaterialyPomieszczenia] = [:]
    ) -> ProjektWyceny {
        let totalBoardArea =
            assemblies.reduce(0) {
                partial,
                assembly in

                partial
                + calculateBoardArea(
                    for: assembly
                )
            }

        let totalFrontArea =
            assemblies.reduce(0) {
                partial,
                assembly in

                partial
                + calculateComponentArea(
                    for: assembly,
                    roles: [.front]
                )
            }

        let totalWorktopLength =
            assemblies.reduce(0) {
                partial,
                assembly in

                partial
                + calculateWorktopLength(
                    for: assembly
                )
            }

        let totalRunLength =
            assemblies.reduce(0) {
                partial,
                assembly in

                partial
                + assembly.size
                    .width.rawValue
                    / 1_000
            }

        let drawerCount =
            assemblies.reduce(0) {
                $0
                + calculateDrawerCount(
                    for: $1
                )
            }

        let hingeCount =
            assemblies.reduce(0) {
                $0
                + calculateHingeCount(
                    for: $1
                )
            }

        let cargoCount =
            assemblies.reduce(0) {
                partial,
                assembly in

                partial
                + calculateCargoCount(
                    for: assembly
                )
            }

        let floorModuleCount =
            assemblies.filter {
                isFloorCabinet($0)
            }.count

        let wallModuleCount =
            assemblies.filter {
                isWallCabinet($0)
            }.count

        let shelfCount =
            assemblies.reduce(0) {
                partial,
                assembly in

                partial
                + assembly
                    .components
                    .filter {
                        $0.role == .shelf
                    }
                    .count
            }

        let plinKolorunLength =
            assemblies
                .filter {
                    isFloorCabinet($0)
                }
                .reduce(0.0) {
                    $0
                    + $1.size
                        .width.rawValue
                        / 1_000
                }

        let frontCount =
            assemblies.reduce(0) {
                partial,
                assembly in

                partial
                + assembly.components
                    .filter {
                        $0.role == .front
                    }
                    .count
            }

        // 3,5 mb obrzeża na 1 m² płyty (standard branżowy)
        let bandingMB =
            totalBoardArea * 3.5

        let materialUsage =
            calculateMaterialUsageV068(
                assemblies:
                    assemblies,
                materialyPomieszczen:
                    materialyPomieszczen
            )
        let hardwareUsage =
            calculateHardwareUsageV068(
                assemblies:
                    assemblies
            )

        let productionHours =
            max(
                4,
                Double(
                    assemblies.count
                ) * 2.8
                + totalBoardArea
                    * 0.45
                + Double(drawerCount)
                    * 0.7
                + Double(cargoCount)
                    * 1.8
            )

        let installationHours =
            max(
                3,
                Double(
                    assemblies.count
                ) * 0.85
                + totalRunLength
                    * 0.6
            )

        return ProjektWyceny(
            nazwaProjektu:
                nazwaProjektu,
            liczbaModulow:
                assemblies.count,
            metryBiezaceZabudowy:
                totalRunLength,
            powierzchniaFrontowM2:
                totalFrontArea,
            powierzchniaPlytM2:
                totalBoardArea,
            metryBiezaceBlatu:
                totalWorktopLength,
            liczbaSzuflad:
                drawerCount,
            liczbaZawiasow:
                hingeCount,
            liczbaCargo:
                cargoCount,
            liczbaGodzinProdukcji:
                productionHours,
            liczbaGodzinMontazu:
                installationHours,
            liczbaTransportow:
                assemblies.count > 14
                ? 2
                : 1,
            liczbaModulowDolnych:
                floorModuleCount,
            liczbaModulowWiszacych:
                wallModuleCount,
            liczbaPólekWewnetrznych:
                shelfCount,
            dlugoscCokuluM:
                plinKolorunLength,
            metryKrawedziBanding:
                bandingMB,
            liczbaFrontow:
                frontCount,
            uzyciaMaterialowV068:
                materialUsage.usages,
            ostrzezeniaV068:
                Array(
                    Set(
                        materialUsage
                            .warnings
                        + hardwareUsage
                            .warnings
                    )
                )
                .sorted(),
            okuciaV068:
                hardwareUsage.items
        )
    }

    private static func calculateBoardArea(
        for assembly:
            FurnitureAssembly
    ) -> Double {
        let components =
            componentsForPricing(
                assembly
            )

        if components.isEmpty {
            let width =
                assembly.size
                    .width.rawValue
            let height =
                assembly.size
                    .height.rawValue
            let depth =
                assembly.size
                    .depth.rawValue

            let areaMM2 =
                2 * height * depth
                + 2 * width * depth
                + width * height

            return areaMM2
                / 1_000_000
        }

        return components.reduce(0) {
            partial,
            component in

            guard component.role
                != .leg
                && component.role
                    != .rail
                && component.role
                    != .front
                && component.role
                    != .worktop
            else {
                return partial
            }

            let dimensions = [
                component.size
                    .width.rawValue,
                component.size
                    .height.rawValue,
                component.size
                    .depth.rawValue
            ].sorted(
                by: >
            )

            return partial
                + dimensions[0]
                * dimensions[1]
                / 1_000_000
        }
    }

    private static func calculateComponentArea(
        for assembly:
            FurnitureAssembly,
        roles:
            Set<FurnitureComponentRole>
    ) -> Double {
        let pricingComponents =
            componentsForPricing(
                assembly
            )
        let components =
            pricingComponents.filter {
                roles.contains(
                    $0.role
                )
            }

        if components.isEmpty,
           roles.contains(.front) {
            return assembly.size
                .width.rawValue
                * assembly.size
                    .height.rawValue
                / 1_000_000
        }

        return components.reduce(0) {
            partial,
            component in

            let dimensions = [
                component.size
                    .width.rawValue,
                component.size
                    .height.rawValue,
                component.size
                    .depth.rawValue
            ].sorted(
                by: >
            )

            return partial
                + dimensions[0]
                * dimensions[1]
                / 1_000_000
        }
    }

    private static func componentsForPricing(
        _ assembly:
            FurnitureAssembly
    ) -> [FurnitureComponent] {
        guard !assembly
            .components
            .isEmpty
        else {
            return []
        }

        return GeometriaSzuflad3DV068
            .uzupelnioneKomponenty(
                assembly:
                    assembly,
                bazowe:
                    assembly
                    .components
            )
    }

    private static func calculateWorktopLength(
        for assembly:
            FurnitureAssembly
    ) -> Double {
        let worktops =
            assembly.components.filter {
                $0.role
                    == .worktop
            }

        if !worktops.isEmpty {
            return worktops.reduce(0) {
                $0
                + $1.size
                    .width.rawValue
                / 1_000
            }
        }

        let lowerName =
            assembly.name.lowercased()

        let isLower =
            containsAny(
                lowerName,
                phrases: [
                    "dolna",
                    "dolny",
                    "zlew",
                    "piekarnik",
                    "cargo"
                ]
            )

        return isLower
            ? assembly.size
                .width.rawValue
                / 1_000
            : 0
    }

    private static func calculateDrawerCount(
        for assembly:
            FurnitureAssembly
    ) -> Int {
        if let card =
            KonfiguracjaFunkcjonalnaModuluV068Resolver
                .karta(
                    dla: assembly
                ) {
            let count =
                card
                    .efektywneSzuflady
                    .filter(\.aktywna)
                    .count

            if count > 0 {
                return count
            }
        }

        let names =
            (
                [assembly.name]
                + assembly.components.map(
                    \.code
                )
                + assembly.subassemblies.map(
                    \.name
                )
            )
            .joined(
                separator: " "
            )
            .lowercased()

        let explicitCount =
            calculateOccurrences(
                in: names,
                phrases: [
                    "szuflada",
                    "drawer"
                ]
            )

        if explicitCount > 0 {
            return explicitCount
        }

        if names.contains(
            "space tower"
        ) {
            return 5
        }

        return 0
    }

    // Reguła zawiasów — polski standard branżowy (Blum, GTV):
    // ≤900 mm wysokości frontu → 2, ≤1400 → 3, ≤2000 → 4, >2000 → 5
    private static func hingesForFrontHeight(
        _ heightMM: Double
    ) -> Int {
        switch heightMM {
        case ..<900:
            return 2
        case ..<1_400:
            return 3
        case ..<2_000:
            return 4
        default:
            return 5
        }
    }

    private static func calculateHingeCount(
        for assembly:
            FurnitureAssembly
    ) -> Int {
        // 1. Karta techniczna — najwyższy priorytet
        if let card =
            KonfiguracjaFunkcjonalnaModuluV068Resolver
                .karta(
                    dla: assembly
                ) {
            let count =
                card
                    .efektywneAkcesoria
                    .filter {
                        $0.kategoria
                            == .zawias
                    }
                    .reduce(0) {
                        $0
                        + max(
                            $1.ilosc,
                            0
                        )
                    }

            if count > 0 {
                return count
            }
        }

        // 2. Komponenty frontu — sumuj zawiasy dla każdego frontu z osobna
        let frontComponents =
            assembly.components
                .filter {
                    $0.role == .front
                }

        if !frontComponents.isEmpty {
            return frontComponents
                .reduce(0) {
                    total,
                    front in

                    total
                    + hingesForFrontHeight(
                        front.size
                            .height
                            .rawValue
                    )
                }
        }

        // 3. Fallback — nazwa modułu i wysokość całej szafki jako przybliżenie
        guard containsAny(
            assembly.name,
            phrases: [
                "front",
                "drzwi"
            ]
        ) else {
            return 0
        }

        return hingesForFrontHeight(
            assembly.size
                .height.rawValue
        )
    }

    private static func calculateCargoCount(
        for assembly:
            FurnitureAssembly
    ) -> Int {
        if let card =
            KonfiguracjaFunkcjonalnaModuluV068Resolver
                .karta(
                    dla: assembly
                ) {
            let count =
                card
                    .efektywneAkcesoria
                    .filter {
                        $0.kategoria
                            == .cargoIOrganizer
                    }
                    .reduce(0) {
                        $0
                        + max(
                            $1.ilosc,
                            0
                        )
                    }

            if count > 0 {
                return count
            }
        }

        return containsAny(
            assembly.name,
            phrases: [
                "cargo",
                "space tower",
                "spacetower"
            ]
        )
        ? 1
        : 0
    }

    private static func calculateHardwareUsageV068(
        assemblies:
            [FurnitureAssembly]
    ) -> (
        items:
            [PozycjaOkuciaProjektuV068],
        warnings:
            [String]
    ) {
        var grouped:
            [String:
                PozycjaOkuciaProjektuV068] = [:]
        var warnings:
            [String] = []

        for assembly in assemblies {
            guard let card =
                KonfiguracjaFunkcjonalnaModuluV068Resolver
                    .karta(
                        dla: assembly
                    )
            else {
                continue
            }

            for accessory in card
                .efektywneAkcesoria {
                guard !accessory
                    .profilID
                    .isEmpty
                else {
                    continue
                }

                let profile =
                    KatalogRegulAkcesoriow
                        .profil(
                            id:
                                accessory
                                    .profilID
                        )
                let price =
                    accessory
                        .cenaJednostkowaNettoPLN
                    ?? profile?
                        .cenaRynkowa?
                        .cenaSredniaNettoPLN
                    ?? 0
                let unit =
                    accessory
                        .jednostkaCeny
                    ?? profile?
                        .cenaRynkowa?
                        .jednostka
                        .skrot
                    ?? "szt."
                let key =
                    [
                        accessory.profilID,
                        accessory
                            .nominalnaDlugoscMM
                            .map {
                                String(
                                    Int(
                                        $0.rounded()
                                    )
                                )
                            }
                        ?? "-",
                        accessory
                            .wariantWysokosciMM
                            .map {
                                String(
                                    Int(
                                        $0.rounded()
                                    )
                                )
                            }
                        ?? "-"
                    ]
                    .joined(
                        separator: "|"
                    )

                let item =
                    PozycjaOkuciaProjektuV068(
                        profilID:
                            accessory
                                .profilID,
                        producent:
                            accessory
                                .producent,
                        rodzina:
                            accessory
                                .rodzina,
                        model:
                            accessory
                                .model,
                        kategoria:
                            accessory
                                .kategoria,
                        ilosc:
                            Double(
                                max(
                                    accessory
                                        .ilosc,
                                    0
                                )
                            ),
                        jednostka:
                            unit,
                        cenaJednostkowaNetto:
                            price,
                        zrodlo:
                            accessory
                                .cenaJednostkowaNettoPLN
                                != nil
                            ? "snapshot-karty"
                            : (
                                price > 0
                                ? "katalog-regul"
                                : "brak-ceny"
                            )
                    )

                if var existing =
                    grouped[key] {
                    existing.ilosc +=
                        item.ilosc
                    grouped[key] =
                        existing
                } else {
                    grouped[key] =
                        item
                }

                if price <= 0 {
                    warnings.append(
                        "Brak ceny okucia \(accessory.producent) \(accessory.rodzina) \(accessory.model) w module \(assembly.name)."
                    )
                }
            }
        }

        return (
            grouped
                .values
                .sorted {
                    let left =
                        "\($0.producent) \($0.rodzina) \($0.model)"
                    let right =
                        "\($1.producent) \($1.rodzina) \($1.model)"
                    return left
                        .localizedStandardCompare(
                            right
                        )
                        == .orderedAscending
                },
            Array(
                Set(
                    warnings
                )
            )
            .sorted()
        )
    }

    private static func calculateMaterialUsageV068(
        assemblies:
            [FurnitureAssembly],
        materialyPomieszczen:
            [String:
                GlobalneMaterialyPomieszczenia]
    ) -> (
        usages:
            [UzycieMaterialuWycenyV068],
        warnings:
            [String]
    ) {
        guard !materialyPomieszczen.isEmpty else {
            return (
                [],
                [
                    "Projekt nie zawiera mapy materiałów pomieszczeń. Wycena użyje trybu wariantowego dla danych legacy."
                ]
            )
        }

        var usageByKey:
            [String:
                UzycieMaterialuWycenyV068] = [:]
        var warnings:
            [String] = []

        let assembliesByRoom =
            Dictionary(
                grouping:
                    assemblies
            ) {
                $0.placement?
                    .roomID
                    .description
                ?? ""
            }

        for (
            roomID,
            roomAssemblies
        ) in assembliesByRoom {
            guard !roomID.isEmpty else {
                warnings.append(
                    "Co najmniej jeden moduł nie ma przypisanego pomieszczenia; jego materiał zostanie wyceniony wariantowo."
                )
                continue
            }

            guard let selection =
                materialyPomieszczen[
                    roomID
                ]
            else {
                warnings.append(
                    "Brak ustawień materiałowych dla pomieszczenia \(roomID)."
                )
                continue
            }

            let boardArea =
                roomAssemblies
                    .reduce(0) {
                        $0
                        + calculateBoardArea(
                            for: $1
                        )
                    }
            let frontArea =
                roomAssemblies
                    .reduce(0) {
                        $0
                        + calculateComponentArea(
                            for: $1,
                            roles: [
                                .front
                            ]
                        )
                    }

            if let materialID =
                selection
                    .korpus
                    .id {
                appendMaterialUsageV068(
                    roomID:
                        roomID,
                    role:
                        .korpus,
                    materialID:
                        materialID,
                    quantity:
                        boardArea,
                    to:
                        &usageByKey
                )
            } else {
                warnings.append(
                    "Korpus w pomieszczeniu \(roomID) używa materiału domyślnego bez identyfikatora cennika."
                )
            }

            if let materialID =
                selection
                    .front
                    .id {
                appendMaterialUsageV068(
                    roomID:
                        roomID,
                    role:
                        .front,
                    materialID:
                        materialID,
                    quantity:
                        frontArea,
                    to:
                        &usageByKey
                )
            } else {
                warnings.append(
                    "Front w pomieszczeniu \(roomID) używa materiału domyślnego bez identyfikatora cennika."
                )
            }
        }

        return (
            usageByKey
                .values
                .sorted {
                    if $0.rola
                        .rawValue
                        == $1.rola
                            .rawValue {
                        return $0.materialID
                            .uuidString
                            < $1.materialID
                                .uuidString
                    }

                    return $0.rola
                        .rawValue
                        < $1.rola
                            .rawValue
                },
            Array(
                Set(
                    warnings
                )
            )
            .sorted()
        )
    }

    private static func appendMaterialUsageV068(
        roomID: String,
        role:
            RolaMaterialuWycenyV068,
        materialID: UUID,
        quantity: Double,
        to result:
            inout [
                String:
                    UzycieMaterialuWycenyV068
            ]
    ) {
        guard quantity > 0 else {
            return
        }

        let key =
            role.rawValue
            + "|"
            + materialID
                .uuidString
                .lowercased()

        if var existing =
            result[key] {
            existing.iloscM2 +=
                quantity
            result[key] =
                existing
        } else {
            result[key] =
                UzycieMaterialuWycenyV068(
                    roomID:
                        roomID,
                    rola: role,
                    materialID:
                        materialID,
                    iloscM2:
                        quantity
                )
        }
    }

    private static func isFloorCabinet(
        _ assembly:
            FurnitureAssembly
    ) -> Bool {
        containsAny(
            assembly.name,
            phrases: [
                "dolna",
                "dolny",
                "dolne",
                "stół",
                "stol",
                "zlew",
                "piekarnik",
                "cargo",
                "agd"
            ]
        )
        || assembly.components.contains {
            $0.role == .leg
        }
    }

    private static func isWallCabinet(
        _ assembly:
            FurnitureAssembly
    ) -> Bool {
        containsAny(
            assembly.name,
            phrases: [
                "górna",
                "gorna",
                "wiszą",
                "wisząca",
                "wiszący",
                "wiszaca",
                "wiszacy"
            ]
        )
    }

    private static func calculateOccurrences(
        in text: String,
        phrases: [String]
    ) -> Int {
        phrases.reduce(0) {
            result,
            phrase in

            result
            + text.components(
                separatedBy: phrase
            ).count
            - 1
        }
    }

    private static func containsAny(
        _ text: String,
        phrases: [String]
    ) -> Bool {
        let normalized =
            text.lowercased()

        return phrases.contains {
            normalized.contains($0)
        }
    }
}
