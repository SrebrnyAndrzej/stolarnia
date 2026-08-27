import DomainCore
import Foundation

enum KartaTechnicznaSzafkiBuilder {
    static func build(
        from draft:
            FurnitureCreatorDraftV018
    ) -> KartaTechnicznaSzafki {
        var points:
            [PunktWierceniaSzafki] = []

        let sideHeight =
            max(
                draft.heightMM,
                1
            )

        for (
            index,
            front
        ) in draft.fronts.enumerated() {
            switch front.openingKind {
            case .drawer:
                let centerY =
                    sideHeight
                    * (
                        Double(index) + 0.5
                    )
                    / Double(
                        max(
                            draft.fronts.count,
                            1
                        )
                    )

                points.append(
                    drawerPoint(
                        element:
                            "Bok lewy",
                        yMM: centerY,
                        mirrored: false
                    )
                )

                points.append(
                    drawerPoint(
                        element:
                            "Bok prawy",
                        yMM: centerY,
                        mirrored: true
                    )
                )

            case .leftHinged,
                 .rightHinged:
                let hingeX =
                    front.openingKind
                    == .leftHinged
                    ? 22
                    : max(
                        draft.widthMM - 22,
                        22
                    )

                for y in hingeYPositions(
                    height:
                        draft.heightMM
                ) {
                    points.append(
                        PunktWierceniaSzafki(
                            element:
                                "Front \(index + 1)",
                            typ: .zawias,
                            strona:
                                .wewnetrzna,
                            xMM: hingeX,
                            yMM: y,
                            srednicaMM: 35,
                            glebokoscMM: 13,
                            opis:
                                "Otwór puszki zawiasu. Dokładny odsuw od krawędzi należy pobrać z wybranego modelu zawiasu."
                        )
                    )
                }

            default:
                break
            }
        }

        let cabinetNumber =
            shortNumber(
                draft.id
            )

        let elements =
            generateElements(
                cabinetNumber:
                    cabinetNumber,
                width:
                    draft.widthMM,
                height:
                    draft.heightMM,
                depth:
                    draft.depthMM,
                shelfCount:
                    max(
                        draft.segmentCount - 1,
                        0
                    ),
                frontCount:
                    draft.fronts.count,
                drawerCount:
                    draft.fronts.filter {
                        $0.openingKind
                            == .drawer
                    }.count,
                materialCarcass:
                    draft.carcassFinish.title,
                materialFront:
                    draft.frontFinish.title,
                enclosure:
                    ZamkniecieBrylySzafki(),
                drillPoints:
                    points
            )

        var card = KartaTechnicznaSzafki(
            draftID: draft.id,
            numerSzafki:
                cabinetNumber,
            nazwa: draft.name,
            szerokoscMM:
                draft.widthMM,
            wysokoscMM:
                draft.heightMM,
            glebokoscMM:
                draft.depthMM,
            rodzajKonstrukcji:
                draft
                    .effectiveConstructionKind
                    .title,
            materialKorpusu:
                draft.carcassFinish.title,
            materialFrontu:
                draft.frontFinish.title,
            liczbaSegmentow:
                draft.segmentCount,
            punktyWiercenia:
                points,
            dataAktualizacji:
                Date(),
            kodSzablonuZrodlowego:
                nil,
            jestGotowymModulem:
                false,
            liczbaPolek:
                nil,
            zamkniecieBryly:
                ZamkniecieBrylySzafki(),
            elementy:
                elements
        )

        // v0.80: wnęki specjalne z customCarcass
        if !draft.wneki.isEmpty {
            card.wnekiSpecjalneV080 = draft.wneki
        }

        if draft.effectiveConstructionKind == .slidingWardrobe {
            var definition =
                draft.systemPrzesuwnV075
                ?? SzafaPrzesuwnaDefinicjaV075()
            definition.szerokoscCalkowitaMM =
                draft.widthMM
            definition.wysokoscCalkowitaMM =
                draft.heightMM
            definition.glebokoscMM =
                draft.depthMM
            definition.liczbaDrzwi =
                max(
                    draft
                        .wardrobeV021?
                        .slidingDoorCount
                    ?? definition.liczbaDrzwi,
                    2
                )
            definition.normalize()

            applySlidingWardrobeRules(
                to:
                    &card,
                definition:
                    definition
            )
        }

        applySpecialCabinetRules(
            to:
                &card
        )

        return card
    }

    static func build(
        assembly:
            FurnitureAssembly,
        numer: Int
    ) -> KartaTechnicznaSzafki {
        if let card =
            buildSlidingWardrobeSystemCardV087(
                assembly:
                    assembly,
                numer:
                    numer
            ) {
            return card
        }

        let production =
            productionDrillingInput(
                for:
                    assembly
            )
        let moduleKey =
            assembly.id.rawValue.uuidString
        let cabinetNumber =
            String(numer)

        let elements =
            generateElements(
                cabinetNumber:
                    cabinetNumber,
                width:
                    assembly.size.width.rawValue,
                height:
                    assembly.size.height.rawValue,
                depth:
                    assembly.size.depth.rawValue,
                shelfCount:
                    production.shelfCount,
                frontCount:
                    production.frontCount,
                drawerCount:
                    production.drawerCount,
                materialCarcass:
                    "Do wyboru",
                materialFront:
                    "Do wyboru",
                enclosure:
                    ZamkniecieBrylySzafki(),
                drillPoints:
                    production.points
            )

        var card =
            KartaTechnicznaSzafki(
            id:
                assembly.id.rawValue,
            draftID:
                assembly.id.rawValue,
            numerSzafki:
                cabinetNumber,
            nazwa:
                assembly.name,
            szerokoscMM:
                assembly.size.width.rawValue,
            wysokoscMM:
                assembly.size.height.rawValue,
            glebokoscMM:
                assembly.size.depth.rawValue,
            rodzajKonstrukcji:
                assembly.kind.rawValue,
            materialKorpusu:
                "Do wyboru",
            materialFrontu:
                "Do wyboru",
            liczbaSegmentow:
                max(
                    production.frontCount,
                    1
                ),
            punktyWiercenia:
                production.points,
            dataAktualizacji:
                Date(),
            kluczModulu:
                moduleKey,
            kodSzablonuZrodlowego:
                assembly
                    .templateID?
                    .rawValue
                    .uuidString,
            jestGotowymModulem:
                true,
            liczbaPolek:
                production.shelfCount,
            zamkniecieBryly:
                ZamkniecieBrylySzafki(),
            elementy:
                elements
        )

        // Strona zawiasu z komponentu frontu — od 2026-08-27 zespół ją niesie.
        //
        // Bierzemy pierwszy front z jednoznacznym kierunkiem. Gdy front jest
        // szufladowy, przesuwny albo stały, pytanie o stronę zawiasu nie ma
        // sensu i zostaje `nil`.
        card.stronaZawiasuV0104 = assembly.components
            .first {
                $0.role == .front
                && ($0.opening == .leftHinged || $0.opening == .rightHinged)
            }?
            .opening

        applyFrontHardwareCalculations(
            to: &card,
            assembly: assembly
        )

        applySpecialCabinetRules(
            to:
                &card
        )

        return card
    }

    /// Przenosi wynik kalkulatora do dokumentacji produkcyjnej bez wymyślania
    /// modelu podnośnika. Karta dostaje masę i współczynnik mocy, a pole
    /// `wymagaPotwierdzeniaSKU` zostaje jawnie ustawione przez kalkulator.
    private static func applyFrontHardwareCalculations(
        to card: inout KartaTechnicznaSzafki,
        assembly: FurnitureAssembly
    ) {
        for front in assembly.components where
            front.role == .front
            && (front.opening == .liftUp || front.opening == .flapDown) {
            let dobor = FrontHardwareCalculator.selectLift(
                frontWidth: front.size.width,
                frontHeight: front.size.height,
                thickness: front.size.depth
            )

            var accessory = InstancjaAkcesoriumSzafki()
            accessory.profilID = "calculated.front-lift.\(front.code)"
            accessory.producent = "Dobór geometryczny"
            accessory.rodzina = "Podnośnik frontu"
            accessory.model = "SKU do potwierdzenia"
            accessory.kategoria = .podnosnikFrontu
            accessory.ilosc = front.size.width
                >= FrontHardwareCalculator.twoActuatorWidthThreshold ? 2 : 1
            accessory.docelowaEtykietaElementu = front.code
            accessory.wysokoscFrontuMM = front.size.height.rawValue
            accessory.masaFrontuKG = dobor.frontMass
            accessory.wspolczynnikMocy = dobor.powerFactor
            accessory.wymagaPotwierdzeniaSKU =
                dobor.requiresSKUConfirmation
            accessory.uwagi = dobor.issues
                .map { issue in
                    issue.hint.isEmpty
                        ? issue.message
                        : "\(issue.message) — \(issue.hint)"
                }
                .joined(separator: "; ")
            card.efektywneAkcesoria.append(accessory)
        }
    }

    static func applyProductionDrillings(
        to card:
            inout KartaTechnicznaSzafki,
        assembly:
            FurnitureAssembly,
        numer: Int
    ) {
        let generated =
            build(
                assembly:
                    assembly,
                numer:
                    numer
            )

        card.kluczModulu =
            card.kluczModulu
            ?? assembly.id.rawValue.uuidString

        card.punktyWiercenia =
            mergedDrillPoints(
                existing:
                    card.punktyWiercenia,
                generated:
                    generated.punktyWiercenia
            )

        let generatedElements =
            generateElements(
                cabinetNumber:
                    card.numerSzafki.isEmpty
                    ? generated.numerSzafki
                    : card.numerSzafki,
                width:
                    card.szerokoscMM > 0
                    ? card.szerokoscMM
                    : generated.szerokoscMM,
                height:
                    card.wysokoscMM > 0
                    ? card.wysokoscMM
                    : generated.wysokoscMM,
                depth:
                    card.glebokoscMM > 0
                    ? card.glebokoscMM
                    : generated.glebokoscMM,
                shelfCount:
                    card.liczbaPolek
                    ?? generated.liczbaPolek
                    ?? 0,
                frontCount:
                    max(
                        generated
                            .efektywneElementy
                            .filter {
                                $0.typ == .front
                            }
                            .count,
                        1
                    ),
                drawerCount:
                    generated
                        .efektywneElementy
                        .filter {
                            $0.nazwa
                                .localizedCaseInsensitiveContains(
                                    "szuflad"
                                )
                        }
                        .count,
                materialCarcass:
                    card.materialKorpusu
                        .isEmpty
                    ? generated.materialKorpusu
                    : card.materialKorpusu,
                materialFront:
                    card.materialFrontu
                        .isEmpty
                    ? generated.materialFrontu
                    : card.materialFrontu,
                enclosure:
                    card
                        .efektywneZamkniecieBryly,
                drillPoints:
                    card.punktyWiercenia
            )

        if card.efektywneElementy.isEmpty {
            card.efektywneElementy =
                generatedElements
        } else {
            card.efektywneElementy =
                mergedProductionElements(
                    existing:
                        card.efektywneElementy,
                    generated:
                        generatedElements
                    )
        }

        applySpecialCabinetRules(
            to:
                &card
        )
    }

    static func applyProductionDrillings(
        to card:
            inout KartaTechnicznaSzafki,
        generated:
            KartaTechnicznaSzafki
    ) {
        card.punktyWiercenia =
            mergedDrillPoints(
                existing:
                    card.punktyWiercenia,
                generated:
                    generated.punktyWiercenia
            )

        if card.efektywneElementy.isEmpty {
            card.efektywneElementy =
                generated.efektywneElementy
        } else {
            card.efektywneElementy =
                mergedProductionElements(
                    existing:
                        card.efektywneElementy,
                    generated:
                        generated.efektywneElementy
                )
        }

        if card.liczbaPolek == nil {
            card.liczbaPolek =
                generated.liczbaPolek
        }
    }

    static func build(
        template:
            FurnitureTemplate,
        moduleName: String,
        width: Millimeters,
        height: Millimeters,
        depth: Millimeters,
        shelfCount: Int,
        existingID:
            UUID = UUID()
    ) -> KartaTechnicznaSzafki {
        let categoryName =
            template.category.rawValue

        let lowerName =
            (
                template.name
                + " "
                + template.code
            )
            .lowercased()

        let isDrawerModule =
            lowerName.contains("szuflad")
            || lowerName.contains("drawer")
            || lowerName.contains("cargo")

        let isLiftModule =
            lowerName.contains("uchyl")
            || lowerName.contains("lift")

        var points:
            [PunktWierceniaSzafki] = []

        if isDrawerModule {
            let drawerCount =
                max(
                    estimatedDrawerCount(
                        templateName:
                            lowerName
                    ),
                    1
                )

            for index in 0..<drawerCount {
                let y =
                    height.rawValue
                    * (
                        Double(index) + 0.5
                    )
                    / Double(drawerCount)

                points.append(
                    drawerPoint(
                        element:
                            "Bok lewy",
                        yMM: y,
                        mirrored: false
                    )
                )

                points.append(
                    drawerPoint(
                        element:
                            "Bok prawy",
                        yMM: y,
                        mirrored: true
                    )
                )
            }
        } else if !isLiftModule {
            for y in hingeYPositions(
                height:
                    height.rawValue
            ) {
                    points.append(
                        PunktWierceniaSzafki(
                            element:
                            "Front 1",
                            typ: .zawias,
                            strona:
                                .wewnetrzna,
                        xMM: 22,
                        yMM: y,
                        srednicaMM: 35,
                        glebokoscMM: 13,
                        opis:
                            "Punkt puszki zawiasu wygenerowany dla gotowego modułu. Zweryfikuj odsuw według wybranego zawiasu."
                    )
                )
            }
        }

        if shelfCount > 0 {
            for shelfIndex in 0..<shelfCount {
                let y =
                    height.rawValue
                    * Double(
                        shelfIndex + 1
                    )
                    / Double(
                        shelfCount + 1
                    )

                for side in [
                    "Bok lewy",
                    "Bok prawy"
                ] {
                    points.append(
                        PunktWierceniaSzafki(
                            element: side,
                            typ:
                                .podporaPolki,
                            strona:
                                .wewnetrzna,
                            xMM: 37,
                            yMM: y,
                            srednicaMM: 5,
                            glebokoscMM: 12,
                            opis:
                                "Punkt bazowy podpory półki. Drugi punkt należy rozmieścić zgodnie z głębokością korpusu."
                        )
                    )
                }
            }
        }

        let cabinetNumber =
            shortNumber(
                existingID
            )

        let elements =
            generateElements(
                cabinetNumber:
                    cabinetNumber,
                width:
                    width.rawValue,
                height:
                    height.rawValue,
                depth:
                    depth.rawValue,
                shelfCount:
                    shelfCount,
                frontCount:
                    isDrawerModule
                    ? max(
                        estimatedDrawerCount(
                            templateName:
                                lowerName
                        ),
                        1
                    )
                    : 1,
                drawerCount:
                    isDrawerModule
                    ? max(
                        estimatedDrawerCount(
                            templateName:
                                lowerName
                        ),
                        1
                    )
                    : 0,
                materialCarcass:
                    "Do wyboru",
                materialFront:
                    "Do wyboru",
                enclosure:
                    ZamkniecieBrylySzafki(),
                drillPoints:
                    points
            )

        var card =
            KartaTechnicznaSzafki(
            id: existingID,
            draftID: existingID,
            numerSzafki:
                cabinetNumber,
            nazwa: moduleName,
            szerokoscMM:
                width.rawValue,
            wysokoscMM:
                height.rawValue,
            glebokoscMM:
                depth.rawValue,
            rodzajKonstrukcji:
                categoryName,
            materialKorpusu:
                "Do wyboru",
            materialFrontu:
                "Do wyboru",
            liczbaSegmentow: 1,
            punktyWiercenia:
                points,
            dataAktualizacji:
                Date(),
            kodSzablonuZrodlowego:
                template.code,
            jestGotowymModulem:
                true,
            liczbaPolek:
                shelfCount,
            zamkniecieBryly:
                ZamkniecieBrylySzafki(),
            elementy:
                elements
        )

        applySpecialCabinetRules(
            to:
                &card
        )

        return card
    }

    private static func generateElements(
        cabinetNumber: String,
        width: Double,
        height: Double,
        depth: Double,
        shelfCount: Int,
        frontCount: Int,
        drawerCount: Int,
        materialCarcass: String,
        materialFront: String,
        enclosure:
            ZamkniecieBrylySzafki,
        drillPoints:
            [PunktWierceniaSzafki]
    ) -> [ElementTechnicznySzafki] {
        let boardThickness = 18.0
        let backThickness = 3.0
        let innerWidth =
            max(
                width
                - boardThickness * 2,
                0
            )

        var elements:
            [ElementTechnicznySzafki] = []

        func nextLabel(
            _ type:
                TypElementuSzafki
        ) -> String {
            let index =
                elements.filter {
                    $0.typ == type
                }.count + 1

            return "\(cabinetNumber)_\(type.kod)_\(index)"
        }

        func points(
            for elementName: String
        ) -> [PunktWierceniaSzafki] {
            drillPoints.filter {
                drillPointElement(
                    $0.element,
                    matches:
                        elementName,
                    frontCount:
                        frontCount
                )
            }
        }

        let leftSidePoints =
            points(
                for:
                    "Bok lewy"
            )
        var leftSide =
            ElementTechnicznySzafki(
                etykieta:
                    nextLabel(
                        .scianaBoczna
                    ),
                typ:
                    .scianaBoczna,
                nazwa:
                    "Ściana boczna lewa",
                dlugoscMM:
                    height,
                szerokoscMM:
                    depth,
                gruboscMM:
                    boardThickness,
                material:
                    materialCarcass,
                kierunek:
                    .pionowy,
                punktyWiercenia:
                    leftSidePoints
            )
        leftSide.efektywneLinieWiercenia =
            runnerAxisLines(
                for:
                    leftSidePoints,
                elementName:
                    leftSide.etykieta,
                depth:
                    depth
            )
        elements.append(leftSide)

        let rightSidePoints =
            points(
                for:
                    "Bok prawy"
            )
        var rightSide =
            ElementTechnicznySzafki(
                etykieta:
                    nextLabel(
                        .scianaBoczna
                    ),
                typ:
                    .scianaBoczna,
                nazwa:
                    "Ściana boczna prawa",
                dlugoscMM:
                    height,
                szerokoscMM:
                    depth,
                gruboscMM:
                    boardThickness,
                material:
                    materialCarcass,
                kierunek:
                    .pionowy,
                punktyWiercenia:
                    rightSidePoints
            )
        rightSide.efektywneLinieWiercenia =
            runnerAxisLines(
                for:
                    rightSidePoints,
                elementName:
                    rightSide.etykieta,
                depth:
                    depth
            )
        elements.append(rightSide)

        elements.append(
            ElementTechnicznySzafki(
                etykieta:
                    nextLabel(.dno),
                typ: .dno,
                nazwa: "Dno",
                dlugoscMM:
                    innerWidth,
                szerokoscMM:
                    depth,
                gruboscMM:
                    boardThickness,
                material:
                    materialCarcass,
                kierunek:
                    .poziomy
            )
        )

        elements.append(
            ElementTechnicznySzafki(
                etykieta:
                    nextLabel(
                        .wieniecGorny
                    ),
                typ:
                    .wieniecGorny,
                nazwa:
                    "Wieniec górny",
                dlugoscMM:
                    innerWidth,
                szerokoscMM:
                    depth,
                gruboscMM:
                    boardThickness,
                material:
                    materialCarcass,
                kierunek:
                    .poziomy
            )
        )

        elements.append(
            ElementTechnicznySzafki(
                etykieta:
                    nextLabel(.plecy),
                typ: .plecy,
                nazwa: "Plecy",
                dlugoscMM:
                    max(
                        height
                        - boardThickness * 2,
                        0
                    ),
                szerokoscMM:
                    innerWidth,
                gruboscMM:
                    backThickness,
                material:
                    materialCarcass,
                kierunek:
                    .pionowy
            )
        )

        for shelfIndex in 0..<max(
            shelfCount,
            0
        ) {
            elements.append(
                ElementTechnicznySzafki(
                    etykieta:
                        nextLabel(.polka),
                    typ: .polka,
                    nazwa:
                        "Półka \(shelfIndex + 1)",
                    dlugoscMM:
                        innerWidth,
                    szerokoscMM:
                        max(
                            depth - 20,
                            0
                        ),
                    gruboscMM:
                        boardThickness,
                    material:
                        materialCarcass,
                    kierunek:
                        .poziomy
                )
            )
        }

        for frontIndex in 0..<max(
            frontCount,
            0
        ) {
            elements.append(
                ElementTechnicznySzafki(
                    etykieta:
                        nextLabel(.front),
                    typ: .front,
                    nazwa:
                        drawerCount > 0
                        ? "Front szuflady \(frontIndex + 1)"
                        : "Front \(frontIndex + 1)",
                    dlugoscMM:
                        max(
                            height
                            / Double(
                                max(
                                    frontCount,
                                    1
                                )
                            )
                            - 3,
                            0
                        ),
                    szerokoscMM:
                        max(
                            width - 3,
                            0
                        ),
                    gruboscMM:
                        boardThickness,
                    material:
                        materialFront,
                    kierunek:
                        .pionowy,
                    punktyWiercenia:
                        points(
                            for:
                                "Front \(frontIndex + 1)"
                        )
                )
            )
        }

        appendEnclosureElements(
            to: &elements,
            cabinetNumber:
                cabinetNumber,
            width: width,
            height: height,
            depth: depth,
            material:
                materialFront,
            enclosure:
                enclosure
        )

        let defaultParameters =
            ParametrySystemu32()

        for index in elements.indices
        where elements[index].typ
            == .scianaBoczna
            || elements[index].typ
                == .sciankaMaskujaca {
            elements[index]
                .parametrySystemu32 =
                    defaultParameters

            let systemPoints =
                System32Generator.generate(
                    for:
                        elements[index],
                    parameters:
                        defaultParameters
                )

            elements[index]
                .punktyWiercenia
                .removeAll {
                    $0.opis
                        .hasPrefix(
                            "System 32"
                        )
                }

            elements[index]
                .punktyWiercenia
                .append(
                    contentsOf:
                        systemPoints
                )
        }

        return elements
    }

    static func regenerateElements(
        for card:
            KartaTechnicznaSzafki
    ) -> [ElementTechnicznySzafki] {
        generateElements(
            cabinetNumber:
                card.numerSzafki,
            width:
                card.szerokoscMM,
            height:
                card.wysokoscMM,
            depth:
                card.glebokoscMM,
            shelfCount:
                card.liczbaPolek
                ?? max(
                    card.liczbaSegmentow - 1,
                    0
                ),
            frontCount:
                max(
                    card
                        .efektywneElementy
                        .filter {
                            $0.typ == .front
                        }
                        .count,
                    1
                ),
            drawerCount:
                card
                    .efektywneElementy
                    .filter {
                        $0.typ == .szuflada
                    }
                    .count,
            materialCarcass:
                card.materialKorpusu,
            materialFront:
                card.materialFrontu,
            enclosure:
                card
                    .efektywneZamkniecieBryly,
            drillPoints:
                card.punktyWiercenia
        )
    }

    private static func appendEnclosureElements(
        to elements:
            inout [ElementTechnicznySzafki],
        cabinetNumber: String,
        width: Double,
        height: Double,
        depth: Double,
        material: String,
        enclosure:
            ZamkniecieBrylySzafki
    ) {
        func nextLabel(
            _ type:
                TypElementuSzafki
        ) -> String {
            let index =
                elements.filter {
                    $0.typ == type
                }.count + 1

            return "\(cabinetNumber)_\(type.kod)_\(index)"
        }

        if enclosure.blendaLewa {
            elements.append(
                ElementTechnicznySzafki(
                    etykieta:
                        nextLabel(.blenda),
                    typ: .blenda,
                    nazwa:
                        "Blenda lewa",
                    dlugoscMM:
                        height,
                    szerokoscMM:
                        enclosure
                            .szerokoscBlendyLewejMM,
                    gruboscMM:
                        enclosure
                            .gruboscScianekMM,
                    material:
                        material,
                    kierunek:
                        .pionowy
                )
            )
        }

        if enclosure.blendaPrawa {
            elements.append(
                ElementTechnicznySzafki(
                    etykieta:
                        nextLabel(.blenda),
                    typ: .blenda,
                    nazwa:
                        "Blenda prawa",
                    dlugoscMM:
                        height,
                    szerokoscMM:
                        enclosure
                            .szerokoscBlendyPrawejMM,
                    gruboscMM:
                        enclosure
                            .gruboscScianekMM,
                    material:
                        material,
                    kierunek:
                        .pionowy
                )
            )
        }

        if enclosure.wieniecGorny {
            elements.append(
                ElementTechnicznySzafki(
                    etykieta:
                        nextLabel(
                            .wieniecGorny
                        ),
                    typ:
                        .wieniecGorny,
                    nazwa:
                        "Wieniec górny zewnętrzny",
                    dlugoscMM:
                        width,
                    szerokoscMM:
                        depth
                        + enclosure
                            .wysuniecieWiencaGornegoMM,
                    gruboscMM:
                        enclosure
                            .gruboscWiencaGornegoMM,
                    material:
                        material,
                    kierunek:
                        .poziomy
                )
            )
        }

        if enclosure.wieniecDolny {
            elements.append(
                ElementTechnicznySzafki(
                    etykieta:
                        nextLabel(
                            .wieniecDolny
                        ),
                    typ:
                        .wieniecDolny,
                    nazwa:
                        "Wieniec dolny zewnętrzny",
                    dlugoscMM:
                        width,
                    szerokoscMM:
                        depth
                        + enclosure
                            .wysuniecieWiencaDolnegoMM,
                    gruboscMM:
                        enclosure
                            .gruboscWiencaDolnegoMM,
                    material:
                        material,
                    kierunek:
                        .poziomy
                )
            )
        }

        if enclosure.sciankaBocznaLewa {
            elements.append(
                ElementTechnicznySzafki(
                    etykieta:
                        nextLabel(
                            .sciankaMaskujaca
                        ),
                    typ:
                        .sciankaMaskujaca,
                    nazwa:
                        "Ścianka maskująca lewa",
                    dlugoscMM:
                        height,
                    szerokoscMM:
                        depth
                        + enclosure
                            .wysuniecieScianekPrzedFrontMM,
                    gruboscMM:
                        enclosure
                            .gruboscScianekMM,
                    material:
                        material,
                    kierunek:
                        .pionowy,
                    uwagi:
                        "Wysunięcie przed front: \(enclosure.wysuniecieScianekPrzedFrontMM.formatted(.number.precision(.fractionLength(0...1)))) mm."
                )
            )
        }

        if enclosure.sciankaBocznaPrawa {
            elements.append(
                ElementTechnicznySzafki(
                    etykieta:
                        nextLabel(
                            .sciankaMaskujaca
                        ),
                    typ:
                        .sciankaMaskujaca,
                    nazwa:
                        "Ścianka maskująca prawa",
                    dlugoscMM:
                        height,
                    szerokoscMM:
                        depth
                        + enclosure
                            .wysuniecieScianekPrzedFrontMM,
                    gruboscMM:
                        enclosure
                            .gruboscScianekMM,
                    material:
                        material,
                    kierunek:
                        .pionowy,
                    uwagi:
                        "Wysunięcie przed front: \(enclosure.wysuniecieScianekPrzedFrontMM.formatted(.number.precision(.fractionLength(0...1)))) mm."
                )
            )
        }
    }

    private static func productionDrillingInput(
        for assembly:
            FurnitureAssembly
    ) -> (
        points: [PunktWierceniaSzafki],
        shelfCount: Int,
        frontCount: Int,
        drawerCount: Int
    ) {
        let fronts =
            assembly
                .components
                .filter {
                    $0.role == .front
                }
                .sorted {
                    if abs(
                        $0.localPosition.y.rawValue
                        - $1.localPosition.y.rawValue
                    ) > 0.5 {
                        return $0.localPosition.y.rawValue
                            < $1.localPosition.y.rawValue
                    }

                    return $0.localPosition.x.rawValue
                        < $1.localPosition.x.rawValue
                }
        let shelfCount =
            assembly
                .components
                .filter {
                    $0.role == .shelf
                }
                .count
        let drawerCenters =
            drawerRunnerCenters(
                for:
                    assembly
            )
        let lowerName =
            assembly
                .name
                .lowercased()
        let drawerFrontCount =
            fronts
                .filter(componentSuggestsDrawer)
                .count
        let looksLikeDrawerModule =
            !drawerCenters.isEmpty
            || drawerFrontCount > 0
            || lowerName.contains("szuf")
            || lowerName.contains("drawer")
            || lowerName.contains("cargo")
        let measuredDrawerCount =
            max(
                drawerCenters.count,
                drawerFrontCount
            )
        let drawerCount =
            looksLikeDrawerModule
            ? (
                measuredDrawerCount > 0
                ? measuredDrawerCount
                : max(
                    estimatedDrawerCount(
                        templateName:
                            lowerName
                    ),
                    1
                )
            )
            : 0
        let frontCount =
            max(
                fronts.count,
                drawerCount,
                1
            )
        var points:
            [PunktWierceniaSzafki] = []

        if drawerCount > 0 {
            let centers =
                drawerCenters.isEmpty
                ? evenlyDistributedCenters(
                    count:
                        drawerCount,
                    height:
                        assembly.size.height.rawValue
                )
                : drawerCenters

            for centerY in centers {
                points.append(
                    drawerPoint(
                        element:
                            "Bok lewy",
                        yMM:
                            centerY,
                        mirrored:
                            false
                    )
                )
                points.append(
                    drawerPoint(
                        element:
                            "Bok prawy",
                        yMM:
                            centerY,
                        mirrored:
                            true
                    )
                )
            }
        } else if shouldGenerateFrontHinges(
            for:
                assembly
        ) {
            for index in 0..<frontCount {
                let front =
                    fronts.indices.contains(index)
                    ? fronts[index]
                    : nil
                let frontWidth =
                    front?
                        .size
                        .width
                        .rawValue
                    ?? assembly.size.width.rawValue
                let hingeX =
                    hingeCupX(
                        forFrontAt:
                            index,
                        frontCount:
                            frontCount,
                        frontWidth:
                            frontWidth,
                        assemblyWidth:
                            assembly.size.width.rawValue,
                        xPosition:
                            front?
                                .localPosition
                                .x
                                .rawValue
                    )
                let hingeHeight =
                    front?
                        .size
                        .height
                        .rawValue
                    ?? assembly.size.height.rawValue

                for y in hingeYPositions(
                    height:
                        hingeHeight
                ) {
                    points.append(
                        PunktWierceniaSzafki(
                            element:
                                "Front \(index + 1)",
                            typ:
                                .zawias,
                            strona:
                                .wewnetrzna,
                            xMM:
                                hingeX,
                            yMM:
                                y,
                            srednicaMM:
                                35,
                            glebokoscMM:
                                13,
                            opis:
                                "AUTO-PRODUKCJA: otwór puszki zawiasu frontowego. Odsuw X zweryfikować według wybranego zawiasu i prowadnika."
                        )
                    )
                }
            }
        }

        if shelfCount > 0 {
            for shelfIndex in 0..<shelfCount {
                let y =
                    assembly.size.height.rawValue
                    * Double(shelfIndex + 1)
                    / Double(shelfCount + 1)

                for side in [
                    "Bok lewy",
                    "Bok prawy"
                ] {
                    points.append(
                        PunktWierceniaSzafki(
                            element:
                                side,
                            typ:
                                .podporaPolki,
                            strona:
                                .wewnetrzna,
                            xMM:
                                37,
                            yMM:
                                y,
                            srednicaMM:
                                5,
                            glebokoscMM:
                                12,
                            opis:
                                "AUTO-PRODUKCJA: punkt bazowy podpory półki. Drugi punkt rozmieścić według głębokości korpusu."
                        )
                    )
                }
            }
        }

        return (
            points:
                points,
            shelfCount:
                shelfCount,
            frontCount:
                frontCount,
            drawerCount:
                drawerCount
        )
    }

    private static func drawerRunnerCenters(
        for assembly:
            FurnitureAssembly
    ) -> [Double] {
        let rails =
            assembly
                .components
                .filter {
                    $0.role == .rail
                    || $0.code
                        .localizedCaseInsensitiveContains(
                            "PROW"
                        )
                    || $0.code
                        .localizedCaseInsensitiveContains(
                            "RUNNER"
                        )
                    || $0.code
                        .localizedCaseInsensitiveContains(
                            "GUIDE"
                        )
                }

        var centers:
            [Int: Double] = [:]

        for rail in rails {
            let center =
                rail.localPosition.y.rawValue
                + rail.size.height.rawValue / 2
            let key =
                Int(
                    (center / 5).rounded()
                )

            centers[key] =
                center
        }

        return centers
            .values
            .sorted()
    }

    private static func evenlyDistributedCenters(
        count: Int,
        height: Double
    ) -> [Double] {
        let safeCount =
            max(
                count,
                1
            )

        return (0..<safeCount).map {
            index in

            height
            * (Double(index) + 0.5)
            / Double(safeCount)
        }
    }

    private static func componentSuggestsDrawer(
        _ component:
            FurnitureComponent
    ) -> Bool {
        let code =
            component
                .code
                .lowercased()

        return code.contains("front-sz")
            || code.contains("front-szuf")
            || code.contains("drawer")
    }

    private static func shouldGenerateFrontHinges(
        for assembly:
            FurnitureAssembly
    ) -> Bool {
        guard assembly.kind != .slidingWardrobe else {
            return false
        }

        let lowerName =
            assembly
                .name
                .lowercased()

        return !lowerName.contains("przesuw")
            && !lowerName.contains("sliding")
            && !lowerName.contains("otwart")
            && !lowerName.contains("open")
            && !lowerName.contains("uchyl")
            && !lowerName.contains("lift")
    }

    private static func hingeCupX(
        forFrontAt index: Int,
        frontCount: Int,
        frontWidth: Double,
        assemblyWidth: Double,
        xPosition: Double?
    ) -> Double {
        let safeWidth =
            max(
                frontWidth,
                44
            )

        if frontCount <= 1 {
            return 22
        }

        if let xPosition {
            let center =
                xPosition
                + safeWidth / 2

            return center
                > assemblyWidth / 2
                ? max(
                    safeWidth - 22,
                    22
                )
                : 22
        }

        return index % 2 == 0
            ? 22
            : max(
                safeWidth - 22,
                22
            )
    }

    private static func drillPointElement(
        _ pointElement: String,
        matches elementName: String,
        frontCount: Int
    ) -> Bool {
        let point =
            pointElement
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()
        let element =
            elementName
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()

        guard !point.isEmpty,
              !element.isEmpty else {
            return false
        }

        if point == element {
            return true
        }

        if point.hasPrefix("front")
            || element.hasPrefix("front") {
            return point == "front"
                && element == "front 1"
                && frontCount <= 1
        }

        return point.contains(element)
            || element.contains(point)
    }

    private static func runnerAxisLines(
        for points:
            [PunktWierceniaSzafki],
        elementName: String,
        depth: Double
    ) -> [LiniaWierceniaSzafki] {
        points
            .filter {
                $0.typ == .prowadnica
            }
            .enumerated()
            .map {
                index,
                point in

                let xStart =
                    clamp(
                        point.xMM,
                        minimum:
                            0,
                        maximum:
                            max(depth, 0)
                    )
                let xEnd =
                    clamp(
                        max(
                            depth - 37,
                            xStart
                        ),
                        minimum:
                            xStart,
                        maximum:
                            max(depth, xStart)
                    )

                return LiniaWierceniaSzafki(
                    element:
                        elementName,
                    typ:
                        .osProwadnicySzuflady,
                    strona:
                        .wewnetrzna,
                    xStartMM:
                        xStart,
                    xEndMM:
                        xEnd,
                    yMM:
                        point.yMM,
                    etykieta:
                        "Prowadnica \(index + 1)",
                    opis:
                        "AUTO-PRODUKCJA: oś montażowa prowadnicy szuflady. Punkt bazowy X=\(Int(point.xMM.rounded())) mm od przedniej krawędzi; rozstaw wierceń potwierdzić z wybranym systemem."
                )
            }
    }

    private static func mergedProductionElements(
        existing:
            [ElementTechnicznySzafki],
        generated:
            [ElementTechnicznySzafki]
    ) -> [ElementTechnicznySzafki] {
        var result =
            existing

        for index in result.indices {
            guard let generatedElement =
                matchingGeneratedElement(
                    forExistingAt:
                        index,
                    in:
                        result,
                    generated:
                        generated
                )
            else {
                continue
            }

            result[index].punktyWiercenia =
                mergedDrillPoints(
                    existing:
                        result[index].punktyWiercenia,
                    generated:
                        generatedElement
                            .punktyWiercenia
                )
            result[index].efektywneLinieWiercenia =
                mergedDrillLines(
                    existing:
                        result[index]
                            .efektywneLinieWiercenia,
                    generated:
                        generatedElement
                            .efektywneLinieWiercenia
                )

            if result[index].parametrySystemu32 == nil {
                result[index].parametrySystemu32 =
                    generatedElement
                        .parametrySystemu32
            }
        }

        return result
    }

    private static func matchingGeneratedElement(
        forExistingAt index: Int,
        in existing:
            [ElementTechnicznySzafki],
        generated:
            [ElementTechnicznySzafki]
    ) -> ElementTechnicznySzafki? {
        let element =
            existing[index]
        let ordinal =
            existing[..<index]
                .filter {
                    $0.typ == element.typ
                }
                .count
        let candidates =
            generated
                .filter {
                    $0.typ == element.typ
                }

        guard candidates.indices.contains(ordinal) else {
            return nil
        }

        return candidates[ordinal]
    }

    private static func mergedDrillPoints(
        existing:
            [PunktWierceniaSzafki],
        generated:
            [PunktWierceniaSzafki]
    ) -> [PunktWierceniaSzafki] {
        var result =
            existing

        for point in generated
        where !result.contains(
            where: {
                drillPoint(
                    $0,
                    matches:
                        point
                )
            }
        ) {
            result.append(point)
        }

        return result
    }

    private static func drillPoint(
        _ lhs: PunktWierceniaSzafki,
        matches rhs: PunktWierceniaSzafki
    ) -> Bool {
        guard lhs.typ == rhs.typ,
              drillPointElement(
                lhs.element,
                matches:
                    rhs.element,
                frontCount:
                    1
              )
        else {
            return false
        }

        if lhs.typ == .prowadnica
            || lhs.typ == .zawias {
            return abs(lhs.yMM - rhs.yMM) < 1
        }

        return abs(lhs.xMM - rhs.xMM) < 1
            && abs(lhs.yMM - rhs.yMM) < 1
            && abs(lhs.srednicaMM - rhs.srednicaMM) < 0.5
    }

    private static func mergedDrillLines(
        existing:
            [LiniaWierceniaSzafki],
        generated:
            [LiniaWierceniaSzafki]
    ) -> [LiniaWierceniaSzafki] {
        var result =
            existing

        for line in generated
        where !result.contains(
            where: {
                drillLine(
                    $0,
                    matches:
                        line
                )
            }
        ) {
            result.append(line)
        }

        return result
    }

    private static func drillLine(
        _ lhs: LiniaWierceniaSzafki,
        matches rhs: LiniaWierceniaSzafki
    ) -> Bool {
        guard lhs.typ == rhs.typ else {
            return false
        }

        if lhs.typ == .osProwadnicySzuflady {
            return abs(lhs.yMM - rhs.yMM) < 1
        }

        return abs(lhs.xStartMM - rhs.xStartMM) < 1
            && abs(lhs.xEndMM - rhs.xEndMM) < 1
            && abs(lhs.yMM - rhs.yMM) < 1
    }

    private static func drawerPoint(
        element: String,
        yMM: Double,
        mirrored: Bool
    ) -> PunktWierceniaSzafki {
        PunktWierceniaSzafki(
            element: element,
            typ: .prowadnica,
            strona: .wewnetrzna,
            xMM: 37,
            yMM: yMM,
            srednicaMM: 5,
            glebokoscMM: 12,
            opis:
                mirrored
                ? "Lustrzany punkt bazowy prowadnicy. Rozstaw kolejnych otworów zgodnie z systemem."
                : "Pierwszy punkt bazowy prowadnicy: 37 mm od przedniej krawędzi. Rozstaw kolejnych otworów zgodnie z systemem."
        )
    }

    private static func hingeYPositions(
        height: Double
    ) -> [Double] {
        let h = max(height, 1)

        if h <= 900 {
            return [
                100,
                max(
                    h - 100,
                    100
                )
            ]
        }

        if h <= 1_600 {
            return [
                100,
                h / 2,
                max(
                    h - 100,
                    100
                )
            ]
        }

        return [
            100,
            h * 0.36,
            h * 0.64,
            max(
                h - 100,
                100
            )
        ]
    }

    private static func estimatedDrawerCount(
        templateName: String
    ) -> Int {
        for count in stride(
            from: 8,
            through: 1,
            by: -1
        ) {
            if templateName.contains(
                "\(count)"
            ) {
                return count
            }
        }

        return 3
    }

    private static func shortNumber(
        _ id: UUID
    ) -> String {
        String(
            id.uuidString.prefix(6)
        )
        .uppercased()
    }

    // MARK: - Special cabinet production rules

    private static let specialCabinetMarkerV087 =
        "[KORPUS_SPECJALNY_V087]"
    private static let specialCabinetBlockStartV087 =
        "[KORPUS_SPECJALNY_V087_START]"
    private static let specialCabinetBlockEndV087 =
        "[KORPUS_SPECJALNY_V087_END]"

    static func applySpecialCabinetRules(
        to card:
            inout KartaTechnicznaSzafki
    ) {
        let kinds =
            specialCabinetKinds(
                card
            )

        guard !kinds.isEmpty else {
            card.uwagi =
                replacingSpecialCabinetBlock(
                    in:
                        card.uwagi,
                    with:
                        []
                )
            return
        }

        card.efektywneElementy
            .removeAll {
                $0.uwagi.contains(
                    specialCabinetMarkerV087
                )
            }
        card.efektywneAkcesoria
            .removeAll {
                $0.uwagi.contains(
                    specialCabinetMarkerV087
                )
            }

        for kind in kinds {
            applySpecialCabinetKind(
                kind,
                to:
                    &card
            )
        }

        card.uwagi =
            replacingSpecialCabinetBlock(
                in:
                    card.uwagi,
                with:
                    kinds.flatMap {
                        specialCabinetNotes(
                            $0,
                            card:
                                card
                        )
                    }
            )
    }

    private enum SpecialCabinetKindV087:
        CaseIterable
    {
        case sink
        case dishwasher
        case oven
        case refrigerator
        case cargo
    }

    private static func specialCabinetKinds(
        _ card:
            KartaTechnicznaSzafki
    ) -> [SpecialCabinetKindV087] {
        let text =
            [
                card.nazwa,
                card.rodzajKonstrukcji,
                card.kodSzablonuZrodlowego ?? ""
            ]
            .joined(separator: " ")
            .lowercased()

        return SpecialCabinetKindV087
            .allCases
            .filter {
                switch $0 {
                case .sink:
                    return text.contains("zlew")
                        || text.contains("sink")
                case .dishwasher:
                    return text.contains("zmyw")
                        || text.contains("dishwasher")
                case .oven:
                    return text.contains("piekarnik")
                        || text.contains("oven")
                case .refrigerator:
                    return text.contains("lodów")
                        || text.contains("lodow")
                        || text.contains("fridge")
                        || text.contains("refrigerator")
                case .cargo:
                    return text.contains("cargo")
                }
            }
    }

    private static func applySpecialCabinetKind(
        _ kind:
            SpecialCabinetKindV087,
        to card:
            inout KartaTechnicznaSzafki
    ) {
        switch kind {
        case .sink:
            addServiceRail(
                to:
                    &card,
                code:
                    "ZLEW",
                name:
                    "Listwa serwisowa pod zlew",
                width:
                    90,
                note:
                    "Zamiast pełnych pleców przewidzieć dostęp do syfonu i przyłączy; wycięcia blatu/korpusu wg realnego zlewu."
            )

        case .dishwasher:
            addVentilationAccessory(
                to:
                    &card,
                model:
                    "Mocowanie frontu zmywarki",
                note:
                    "Front zmywarki traktować jako panel AGD, nie jako front zawiasowy. Sprawdzić ślizgi, cokoł i podcięcie wg instrukcji urządzenia."
            )

        case .oven:
            addVentilationAccessory(
                to:
                    &card,
                model:
                    "Wentylacja piekarnika",
                note:
                    "Korpus AGD wymaga szczelin wentylacyjnych oraz podpory urządzenia według instrukcji producenta."
            )

        case .refrigerator:
            addVentilationAccessory(
                to:
                    &card,
                model:
                    "Wentylacja lodówki",
                note:
                    "Słupek chłodniczy wymaga drogi powietrza dół-góra, kratki/podcięcia cokołu i luzów wg instrukcji AGD."
            )

        case .cargo:
            addVentilationAccessory(
                to:
                    &card,
                model:
                    "System cargo",
                note:
                    "Cargo wymaga pełnej kontroli głębokości, pionu boków i osi prowadnic; obciążenie oraz otwory wg konkretnego SKU."
            )
        }
    }

    private static func addServiceRail(
        to card:
            inout KartaTechnicznaSzafki,
        code: String,
        name: String,
        width: Double,
        note: String
    ) {
        let boardThickness =
            card
                .efektywneElementy
                .first {
                    $0.typ == .dno
                    || $0.typ == .scianaBoczna
                }?
                .gruboscMM
            ?? 18
        let material =
            card.materialKorpusu
                .isEmpty
            ? "Materiał korpusu"
            : card.materialKorpusu

        card.efektywneElementy
            .append(
                ElementTechnicznySzafki(
                    etykieta:
                        "\(card.numerSzafki)_\(code)_SERWIS",
                    typ:
                        .listwa,
                    nazwa:
                        name,
                    dlugoscMM:
                        max(
                            card.szerokoscMM
                            - boardThickness * 2,
                            0
                        ),
                    szerokoscMM:
                        width,
                    gruboscMM:
                        boardThickness,
                    material:
                        material,
                    kierunek:
                        .poziomy,
                    uwagi:
                        "\(specialCabinetMarkerV087) \(note)"
                )
            )
    }

    private static func addVentilationAccessory(
        to card:
            inout KartaTechnicznaSzafki,
        model: String,
        note: String
    ) {
        var accessory =
            InstancjaAkcesoriumSzafki()
        accessory.profilID =
            "special.\(model.lowercased().replacingOccurrences(of: " ", with: "-"))"
        accessory.producent =
            "Reguła produkcyjna"
        accessory.rodzina =
            "Korpus specjalny"
        accessory.model =
            model
        accessory.kategoria =
            model
                .localizedCaseInsensitiveContains(
                    "wentylacja"
                )
            ? .wentylacjaAGD
            : .inne
        accessory.ilosc = 1
        accessory.docelowaEtykietaElementu =
            card.numerSzafki
        accessory.uwagi =
            "\(specialCabinetMarkerV087) \(note)"
        card.efektywneAkcesoria
            .append(accessory)
    }

    private static func specialCabinetNotes(
        _ kind:
            SpecialCabinetKindV087,
        card:
            KartaTechnicznaSzafki
    ) -> [String] {
        switch kind {
        case .sink:
            return [
                "Zlew: zostaw dostęp serwisowy do syfonu/przyłączy; nie zamykaj pełnymi plecami bez rewizji.",
                "Zlew: wycięcia i wzmocnienia potwierdzić z realnym modelem zlewu oraz baterią."
            ]
        case .dishwasher:
            return [
                "Zmywarka: front jest panelem AGD; wiercenia, ślizgi i wysokość cokołu wg instrukcji urządzenia.",
                "Zmywarka: sprawdź kolizję frontu z cokołem przy otwieraniu."
            ]
        case .oven:
            return [
                "Piekarnik: przewidzieć wentylację, podparcie i luzy montażowe zgodnie z kartą AGD.",
                "Piekarnik: nie projektować pełnej przegrody blokującej przepływ powietrza za urządzeniem."
            ]
        case .refrigerator:
            return [
                "Lodówka: przewidzieć dolny wlot i górny wylot powietrza oraz luzy serwisowe wg instrukcji AGD.",
                "Lodówka: sprawdzić stronę zawiasów/drzwi i kolizję z sąsiednim modułem."
            ]
        case .cargo:
            return [
                "Cargo: obciążenie, otwory i szerokość światła potwierdzić z konkretnym SKU.",
                "Cargo: sprawdzić wysuw z uchwytem/frontem i kolizję z sąsiednimi ścianami/blendami."
            ]
        }
    }

    private static func replacingSpecialCabinetBlock(
        in text: String,
        with notes: [String]
    ) -> String {
        var result =
            text

        while let start =
            result.range(
                of:
                    specialCabinetBlockStartV087
            ),
              let end =
                result.range(
                    of:
                        specialCabinetBlockEndV087,
                    range:
                        start.upperBound
                        ..< result.endIndex
                ) {
            result.removeSubrange(
                start.lowerBound
                ..< end.upperBound
            )
        }

        let trimmed =
            result
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard !notes.isEmpty else {
            return trimmed
        }

        let block =
            (
                [specialCabinetBlockStartV087]
                + notes.map {
                    "- \($0)"
                }
                + [specialCabinetBlockEndV087]
            )
            .joined(separator: "\n")

        if trimmed.isEmpty {
            return block
        }

        return [
            trimmed,
            block
        ]
        .joined(separator: "\n\n")
    }

    // MARK: - Sliding wardrobe production rules

    private static let slidingWardrobeMarkerV087 =
        "[SZAFA_PRZESUWNA_V087]"
    private static let slidingWardrobeBlockStartV087 =
        "[SZAFA_PRZESUWNA_V087_START]"
    private static let slidingWardrobeBlockEndV087 =
        "[SZAFA_PRZESUWNA_V087_END]"

    private static func buildSlidingWardrobeSystemCardV087(
        assembly:
            FurnitureAssembly,
        numer:
            Int
    ) -> KartaTechnicznaSzafki? {
        guard SlidingWardrobeSystemMarkersV087
            .isSystemAssembly(
                assembly
            )
        else {
            return nil
        }

        let elements =
            assembly
                .components
                .enumerated()
                .map {
                    index,
                    component in

                    slidingWardrobeSystemElementV087(
                        component:
                            component,
                        index:
                            index,
                        cabinetNumber:
                            String(numer)
                    )
                }
        let noteLines =
            [
                "[SYSTEM_PRZESUWNY_MODULOWY_V087]",
                "System drzwi przesuwnych jest doposażeniem ciągu modułów garderoby/szafy, nie osobną szafą.",
                "Tory i ściana/listwa domykowa są osobnymi elementami projektu; korpusy pozostają normalnymi modułami.",
                "Długość torów i domknięcia potwierdzić po finalnym ustawieniu modułów i pomiarze światła."
            ]

        return KartaTechnicznaSzafki(
            id:
                assembly.id.rawValue,
            draftID:
                assembly.id.rawValue,
            numerSzafki:
                String(numer),
            nazwa:
                assembly.name,
            szerokoscMM:
                assembly.size.width.rawValue,
            wysokoscMM:
                assembly.size.height.rawValue,
            glebokoscMM:
                assembly.size.depth.rawValue,
            rodzajKonstrukcji:
                "System drzwi przesuwnych",
            materialKorpusu:
                "System/profil drzwi przesuwnych",
            materialFrontu:
                "Nie dotyczy",
            liczbaSegmentow:
                max(elements.count, 1),
            uwagi:
                noteLines.joined(separator: "\n"),
            dataAktualizacji:
                Date(),
            kluczModulu:
                assembly.id.rawValue.uuidString,
            kodSzablonuZrodlowego:
                assembly.templateID?
                    .rawValue
                    .uuidString,
            jestGotowymModulem:
                true,
            liczbaPolek:
                0,
            zamkniecieBryly:
                ZamkniecieBrylySzafki(),
            elementy:
                elements
        )
    }

    private static func slidingWardrobeSystemElementV087(
        component:
            FurnitureComponent,
        index:
            Int,
        cabinetNumber:
            String
    ) -> ElementTechnicznySzafki {
        let isRail =
            component.role == .rail
            || component.code.hasPrefix(
                SlidingWardrobeSystemMarkersV087
                    .upperTrackCode
            )
            || component.code.hasPrefix(
                SlidingWardrobeSystemMarkersV087
                    .lowerTrackCode
            )
            || component.code.hasPrefix(
                SlidingWardrobeSystemMarkersV087
                    .partitionUpperTrackCode
            )
            || component.code.hasPrefix(
                SlidingWardrobeSystemMarkersV087
                    .partitionLowerGuideCode
            )
        let isDoorLeaf =
            component.role == .front
            || component.code.hasPrefix(
                SlidingWardrobeSystemMarkersV087
                    .doorLeafCode
            )
            || component.code.hasPrefix(
                SlidingWardrobeSystemMarkersV087
                    .partitionDoorLeafCode
            )

        return ElementTechnicznySzafki(
            etykieta:
                "\(cabinetNumber)_SYS_PRZ_\(index + 1)",
            typ:
                isRail
                ? .listwa
                : (
                    isDoorLeaf
                    ? .front
                    : .sciankaMaskujaca
                ),
            nazwa:
                isRail
                ? "Tor / prowadnica drzwi przesuwnych"
                : (
                    isDoorLeaf
                    ? "Skrzydło drzwi przesuwnych"
                    : "Profil, ściana lub listwa domykowa drzwi przesuwnych"
                ),
            dlugoscMM:
                component.size.width.rawValue,
            szerokoscMM:
                component.size.depth.rawValue,
            gruboscMM:
                component.size.height.rawValue,
            material:
                isRail
                ? "System drzwi przesuwnych"
                : (
                    isDoorLeaf
                    ? "Wypełnienie drzwi przesuwnych"
                    : "Materiał domknięcia"
                ),
            kierunek:
                isRail
                ? .poziomy
                : (
                    isDoorLeaf
                    ? .poziomy
                    : .pionowy
                ),
            uwagi:
                "SYSTEM_PRZESUWNY_MODULOWY_V087: \(component.code)"
        )
    }

    static func applySlidingWardrobeRules(
        to card:
            inout KartaTechnicznaSzafki,
        definition:
            SzafaPrzesuwnaDefinicjaV075
    ) {
        let report =
            SilnikSzafyPrzesuwanejV075
                .raport(
                    dla:
                        definition
                )

        card.efektywneElementy
            .removeAll {
                $0.uwagi.contains(
                    slidingWardrobeMarkerV087
                )
            }
        card.efektywneAkcesoria
            .removeAll {
                $0.uwagi.contains(
                    slidingWardrobeMarkerV087
                )
            }

        for (
            index,
            item
        ) in report.elementy.enumerated() {
            if let element =
                slidingWardrobeElement(
                    item:
                        item,
                    index:
                        index,
                    card:
                        card,
                    definition:
                        report.definicja
                ) {
                card.efektywneElementy
                    .append(element)
            } else if let accessory =
                slidingWardrobeAccessory(
                    item:
                        item,
                    definition:
                        report.definicja
                ) {
                card.efektywneAkcesoria
                    .append(accessory)
            }
        }

        card.uwagi =
            replacingSlidingWardrobeBlock(
                in:
                    card.uwagi,
                report:
                    report
            )
        card.dataAktualizacji =
            Date()
    }

    private static func slidingWardrobeElement(
        item:
            ElementSzafyPrzesuwanej,
        index: Int,
        card:
            KartaTechnicznaSzafki,
        definition:
            SzafaPrzesuwnaDefinicjaV075
    ) -> ElementTechnicznySzafki? {
        let material =
            card.materialFrontu
                .isEmpty
            ? card.materialKorpusu
            : card.materialFrontu
        let label =
            "\(card.numerSzafki)_PRZ_\(index + 1)"

        switch item.typ {
        case .materialDrzwi:
            return ElementTechnicznySzafki(
                etykieta:
                    label,
                typ:
                    .front,
                nazwa:
                    "Wypełnienie drzwi przesuwnych",
                dlugoscMM:
                    item.wysokoscMM
                    ?? definition.wysokoscSkrzydlaMM,
                szerokoscMM:
                    item.szerokoscMM
                    ?? definition.szerokoscSkrzydlaMM,
                gruboscMM:
                    definition.gruboscDrzwiMM,
                ilosc:
                    item.ilosc,
                material:
                    material,
                kierunek:
                    .pionowy,
                uwagi:
                    "\(slidingWardrobeMarkerV087) \(item.opis). \(item.uwagi ?? "")"
            )

        case .listwaPrzymykowa:
            return ElementTechnicznySzafki(
                etykieta:
                    label,
                typ:
                    .listwa,
                nazwa:
                    "Listwa przymykowa drzwi przesuwnych",
                dlugoscMM:
                    item.wysokoscMM
                    ?? definition.wysokoscCalkowitaMM,
                szerokoscMM:
                    item.szerokoscMM
                    ?? definition.sugerowanaListwaMM,
                gruboscMM:
                    18,
                ilosc:
                    item.ilosc,
                material:
                    card.materialKorpusu
                        .isEmpty
                    ? "Materiał korpusu"
                    : card.materialKorpusu,
                kierunek:
                    .pionowy,
                uwagi:
                    "\(slidingWardrobeMarkerV087) \(item.opis). \(item.uwagi ?? "")"
            )

        case .liscDrzwi:
            return nil
        default:
            return nil
        }
    }

    private static func slidingWardrobeAccessory(
        item:
            ElementSzafyPrzesuwanej,
        definition:
            SzafaPrzesuwnaDefinicjaV075
    ) -> InstancjaAkcesoriumSzafki? {
        switch item.typ {
        case .materialDrzwi,
             .liscDrzwi,
             .listwaPrzymykowa:
            return nil
        default:
            var accessory =
                InstancjaAkcesoriumSzafki()
            accessory.profilID =
                "sliding.\(definition.systemProfili.rawValue).\(item.typ.rawValue)"
            accessory.producent =
                definition.systemProfili.nazwa
            accessory.rodzina =
                "Drzwi przesuwne"
            accessory.model =
                item.typ.nazwa
            accessory.kategoria =
                slidingWardrobeAccessoryCategory(
                    for:
                        item.typ
                )
            accessory.ilosc =
                item.ilosc
            accessory.docelowaEtykietaElementu =
                "Szafa przesuwna"
            accessory.nominalnaDlugoscMM =
                item.szerokoscMM
            accessory.wariantWysokosciMM =
                item.wysokoscMM
            accessory.uwagi =
                "\(slidingWardrobeMarkerV087) \(item.opis). \(item.uwagi ?? "")"
            return accessory
        }
    }

    private static func slidingWardrobeAccessoryCategory(
        for type:
            TypElementuSzafyPrzesuwanej
    ) -> KategoriaAkcesoriumMeblowego {
        switch type {
        case .prowadnicaGorna,
             .prowadnicaDolna,
             .stopperGorny,
             .stopperDolny,
             .wozekJezdny,
             .zaworSoftClose,
             .profil:
            return .prowadnica
        default:
            return .inne
        }
    }

    private static func replacingSlidingWardrobeBlock(
        in text: String,
        report:
            RaportSzafyPrzesuwanejV075
    ) -> String {
        var result =
            text

        while let start =
            result.range(
                of:
                    slidingWardrobeBlockStartV087
            ),
              let end =
                result.range(
                    of:
                        slidingWardrobeBlockEndV087,
                    range:
                        start.upperBound
                        ..< result.endIndex
                ) {
            result.removeSubrange(
                start.lowerBound
                ..< end.upperBound
            )
        }

        var lines = [
            slidingWardrobeBlockStartV087,
            "Szafa przesuwna: \(report.definicja.liczbaDrzwi) skrzydła, \(report.definicja.systemProfili.nazwa), zakład \(Int(report.definicja.zachodMM)) mm.",
            "Skrzydło: \(Int(report.definicja.szerokoscSkrzydlaMM)) × \(Int(report.definicja.wysokoscSkrzydlaMM)) mm; masa ok. \(String(format: "%.1f", report.definicja.wagaDrzwiKg)) kg/szt.",
            "Dostęp po odsunięciu skrzydła: \(Int(report.definicja.swiatloDostepuPoOdsunieciuSkrzydlaMM)) mm; głębokość po torach: \(Int(report.definicja.glebokoscUzytkowaPoTorachMM)) mm.",
            "Szuflady wewnątrz szafy przesuwnej: odsuń od boku min. \(Int(report.definicja.zalecaneOdsuniecieSzufladOdBokuMM)) mm i sprawdź dostęp przy skrajnym położeniu skrzydeł."
        ]

        if !report.ostrzezenia.isEmpty {
            lines.append("Ostrzeżenia:")
            lines.append(
                contentsOf:
                    report.ostrzezenia
                    .map {
                        "- \($0)"
                    }
            )
        }

        lines.append(slidingWardrobeBlockEndV087)

        let trimmed =
            result
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
        let block =
            lines.joined(
                separator:
                    "\n"
            )

        if trimmed.isEmpty {
            return block
        }

        return [
            trimmed,
            block
        ]
        .joined(separator: "\n\n")
    }

    // MARK: - Corner cabinet production rules

    private static let cornerGeneratedMarkerV086 =
        "[NAROZNIK_V086]"
    private static let cornerBlockStartV086 =
        "[NAROZNIK_V086_START]"
    private static let cornerBlockEndV086 =
        "[NAROZNIK_V086_END]"

    static func applyCornerCabinetRules(
        to card:
            inout KartaTechnicznaSzafki,
        definition:
            CornerCabinetDefinitionV025,
        assembly:
            FurnitureAssembly
    ) {
        let footprint =
            definition.footprint(
                for: assembly
            )
        var elements =
            card.efektywneElementy

        if elements.isEmpty {
            elements =
                regenerateElements(
                    for: card
                )
        }

        elements.removeAll {
            $0.uwagi.contains(
                cornerGeneratedMarkerV086
            )
        }

        for index in elements.indices {
            elements[index]
                .efektywneLinieWiercenia
                .removeAll {
                    $0.opis.contains(
                        cornerGeneratedMarkerV086
                    )
                }
        }

        var enclosure =
            card.efektywneZamkniecieBryly

        if footprint.fillerKind != .none {
            if definition.handedness == .left {
                enclosure.blendaLewa = true
                enclosure.szerokoscBlendyLewejMM =
                    footprint.fillerWidthMM
            } else {
                enclosure.blendaPrawa = true
                enclosure.szerokoscBlendyPrawejMM =
                    footprint.fillerWidthMM
            }

            elements.append(
                cornerFillerElement(
                    card: card,
                    footprint: footprint
                )
            )
        }

        appendCornerLines(
            to: &elements,
            footprint: footprint
        )

        card.efektywneZamkniecieBryly =
            enclosure
        card.efektywneElementy =
            elements
        card.narożnikTechnicznyV086 =
            NarożnikTechnicznyKartyV086(
                footprint:
                    footprint
            )
        card.uwagi =
            replacingCornerBlock(
                in: card.uwagi,
                with:
                    cornerNotes(
                        footprint: footprint
                    )
            )

        applyCornerAccessory(
            to: &card,
            footprint: footprint
        )

        card.dataAktualizacji =
            Date()
    }

    private static func cornerFillerElement(
        card:
            KartaTechnicznaSzafki,
        footprint:
            CornerCabinetFootprintV085
    ) -> ElementTechnicznySzafki {
        ElementTechnicznySzafki(
            etykieta:
                "\(card.numerSzafki)_BL_NAR",
            typ:
                .blenda,
            nazwa:
                "Blenda narożna - \(footprint.fillerKind.title)",
            dlugoscMM:
                card.wysokoscMM,
            szerokoscMM:
                footprint.fillerWidthMM,
            gruboscMM:
                18,
            material:
                card.materialFrontu
                    .isEmpty
                ? card.materialKorpusu
                : card.materialFrontu,
            kierunek:
                .pionowy,
            uwagi:
                "\(cornerGeneratedMarkerV086) \(footprint.fillerKind.productionDescription)"
        )
    }

    private static func appendCornerLines(
        to elements:
            inout [ElementTechnicznySzafki],
        footprint:
            CornerCabinetFootprintV085
    ) {
        let rule =
            footprint.technologyRule
        let depth =
            max(footprint.depthMM, 1)
        let height =
            max(footprint.clearHeightMM, 1)
        let centerY =
            clamp(
                height * 0.5,
                minimum: 80,
                maximum:
                    max(height - 80, 80)
            )
        let upperY =
            clamp(
                height * 0.72,
                minimum: 120,
                maximum:
                    max(height - 60, 120)
            )
        let lowerY =
            clamp(
                height * 0.28,
                minimum: 60,
                maximum:
                    max(height - 120, 60)
            )

        for index in elements.indices
        where elements[index].typ == .scianaBoczna
            || elements[index].typ == .sciankaMaskujaca {
            var lines =
                elements[index]
                    .efektywneLinieWiercenia

            if footprint.accessTechnology != .shelves {
                lines.append(
                    cornerLine(
                        element:
                            elements[index].etykieta,
                        typ:
                            .osMechanizmuNaroznego,
                        xStart:
                            0,
                        xEnd:
                            depth,
                        y:
                            centerY,
                        label:
                            "OS \(footprint.accessTechnology.title)",
                        opis:
                            "Oś referencyjna mechanizmu narożnego. Punkty wierceń przenieść z szablonu producenta."
                    )
                )
            }

            if rule.requiresMotionEnvelopeCheck {
                lines.append(
                    cornerLine(
                        element:
                            elements[index].etykieta,
                        typ:
                            .kopertaRuchuMechanizmu,
                        xStart:
                            0,
                        xEnd:
                            depth,
                        y:
                            upperY,
                        label:
                            "KOPERTA",
                        opis:
                            "Koperta ruchu \(footprint.accessTechnology.title): sprawdzić kolizję z frontem, uchwytem i sąsiednim modułem."
                    )
                )
            }

            if footprint.shouldShowDeadZone {
                let deadStart =
                    max(
                        depth
                        - footprint.deadZoneMM,
                        0
                    )
                lines.append(
                    cornerLine(
                        element:
                            elements[index].etykieta,
                        typ:
                            .granicaMartwejStrefy,
                        xStart:
                            deadStart,
                        xEnd:
                            depth,
                        y:
                            lowerY,
                        label:
                            "MARTWA \(Int(footprint.deadZoneMM))",
                        opis:
                            "Martwa strefa ślepego narożnika: nie traktować jako dostępnej przestrzeni użytkowej."
                    )
                )
            }

            if footprint.fillerKind != .none {
                lines.append(
                    cornerLine(
                        element:
                            elements[index].etykieta,
                        typ:
                            .liniaPomocnicza,
                        xStart:
                            0,
                        xEnd:
                            min(
                                footprint.fillerWidthMM,
                                depth
                            ),
                        y:
                            max(40, lowerY * 0.5),
                        label:
                            "BL \(Int(footprint.fillerWidthMM))",
                        opis:
                            "Szerokość blendy/luzu technologicznego dla narożnika."
                    )
                )
            }

            elements[index]
                .efektywneLinieWiercenia =
                    lines
        }
    }

    private static func cornerLine(
        element: String,
        typ:
            TypLiniiWierceniaSzafki,
        xStart: Double,
        xEnd: Double,
        y: Double,
        label: String,
        opis: String
    ) -> LiniaWierceniaSzafki {
        LiniaWierceniaSzafki(
            element: element,
            typ: typ,
            strona:
                .wewnetrzna,
            xStartMM:
                xStart,
            xEndMM:
                xEnd,
            yMM:
                y,
            etykieta:
                label,
            opis:
                "\(cornerGeneratedMarkerV086) \(opis)"
        )
    }

    private static func cornerNotes(
        footprint:
            CornerCabinetFootprintV085
    ) -> String {
        var lines = [
            cornerBlockStartV086,
            "Narożnik: \(footprint.kind.title), \(footprint.handedness.title)",
            "Mechanizm: \(footprint.accessTechnology.title)",
            "Front: \(Int(footprint.frontOpeningMM)) mm, głębokość: \(Int(footprint.depthMM)) mm",
            "Ramiona: \(Int(footprint.primaryWallSpanMM)) / \(Int(footprint.secondaryWallSpanMM)) mm"
        ]

        if footprint.fillerKind != .none {
            lines.append(
                "Blenda/luz: \(footprint.fillerKind.title), \(Int(footprint.fillerWidthMM)) mm"
            )
        }

        if footprint.shouldShowDeadZone {
            lines.append(
                "Martwa strefa: \(Int(footprint.deadZoneMM)) mm"
            )
        }

        lines.append(
            contentsOf:
                footprint.productionNotes
                    .map { "- \($0)" }
        )
        lines.append(cornerBlockEndV086)

        return lines.joined(
            separator: "\n"
        )
    }

    private static func replacingCornerBlock(
        in text: String,
        with block: String
    ) -> String {
        var result = text

        while let start =
            result.range(
                of:
                    cornerBlockStartV086
            ),
              let end =
                result.range(
                    of:
                        cornerBlockEndV086,
                    range:
                        start.upperBound
                        ..< result.endIndex
                ) {
            result.removeSubrange(
                start.lowerBound
                ..< end.upperBound
            )
        }

        let trimmed =
            result.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )

        if trimmed.isEmpty {
            return block
        }

        return [
            trimmed,
            block
        ].joined(separator: "\n\n")
    }

    private static func applyCornerAccessory(
        to card:
            inout KartaTechnicznaSzafki,
        footprint:
            CornerCabinetFootprintV085
    ) {
        var accessories =
            card.efektywneAkcesoria
        accessories.removeAll {
            $0.uwagi.contains(
                cornerGeneratedMarkerV086
            )
        }

        guard let profileID =
            cornerAccessoryProfileID(
                for:
                    footprint.accessTechnology
            ),
              let profile =
                KatalogRegulAkcesoriow
                    .profil(id: profileID)
        else {
            card.efektywneAkcesoria =
                accessories
            return
        }

        var accessory =
            InstancjaAkcesoriumSzafki()
        accessory.profilID =
            profile.id
        accessory.producent =
            profile.producent
        accessory.rodzina =
            profile.rodzina
        accessory.model =
            profile.model
        accessory.kategoria =
            profile.kategoria
        accessory.ilosc = 1
        accessory.docelowaEtykietaElementu =
            card.numerSzafki
        accessory.nominalnaDlugoscMM =
            footprint.frontOpeningMM
        accessory.wariantWysokosciMM =
            footprint.clearHeightMM
        accessory.masaObciazeniaKG =
            footprint
                .technologyRule
                .totalLoadCapacityKG
            ?? footprint
                .technologyRule
                .loadCapacityPerLevelKG
        accessory.uwagi =
            "\(cornerGeneratedMarkerV086) \(footprint.accessTechnology.title): finalny wariant i wiercenia potwierdzić z aktualną kartą producenta."

        accessories.append(accessory)
        card.efektywneAkcesoria =
            accessories
    }

    private static func cornerAccessoryProfileID(
        for technology:
            CornerCabinetAccessTechnologyV085
    ) -> String? {
        switch technology {
        case .shelves,
             .cornerDrawers:
            return nil
        case .leMans:
            return "kessebohmer.lemans2"
        case .magicCorner:
            return "kessebohmer.magiccorner"
        case .carousel:
            return "kessebohmer.revo90"
        }
    }

    private static func clamp(
        _ value: Double,
        minimum: Double,
        maximum: Double
    ) -> Double {
        min(
            max(
                value,
                minimum
            ),
            maximum
        )
    }

    // MARK: - Slope cut angle application

    /// Applies cut angles and contours from a slope panel report to the card's
    /// elements. Call this after building the card whenever `raportPaneliSkosuV0691`
    /// is available.
    static func applySlopeCutAngles(
        to card: inout KartaTechnicznaSzafki
    ) {
        guard let report = card.raportPaneliSkosuV0691 else { return }

        let panele = report.panele

        // Slope angle of the wieniec skosny segments — used for sides and back.
        // When the profile has multiple segments take the one with the largest
        // absolute angle as the conservative (steepest) cut specification.
        let slopeKat: Double = panele
            .filter { $0.typ == .wieniecSkosny }
            .map { abs($0.katMontazuStopnie) }
            .max() ?? 0

        var elementy = card.efektywneElementy

        for index in elementy.indices {
            var el = elementy[index]

            switch el.typ {

            case .scianaBoczna:
                // Side panels are cut at the top edge at the slope angle.
                if slopeKat > 0.01 {
                    el.katCieciaGornejKrawedziStopnieV0691 = slopeKat
                }

            case .dno, .wieniecDolny, .listwa:
                // Bottom / lower elements — no slope cut.
                break

            case .wieniecGorny:
                // The upper crown rail sits under the slope:
                // use the steepest wieniec panel angle.
                if slopeKat > 0.01 {
                    el.katCieciaGornejKrawedziStopnieV0691 = slopeKat
                }

            case .front:
                // Match by index among front panels in the report.
                let frontPanels = panele
                    .filter { $0.typ == .front }
                    .sorted { $0.id < $1.id }
                let frontElements = elementy.indices
                    .filter { elementy[$0].typ == .front }
                let positionIndex = frontElements.firstIndex(of: index) ?? 0
                if positionIndex < frontPanels.count {
                    let panel = frontPanels[positionIndex]
                    if PaneleProdukcyjneSkosuV0691
                        .jestKonturemScietym(
                            panel.kontur,
                            oczekiwanaWysokoscMM: el.dlugoscMM
                        ) {
                        el.konturSkosuV0691 = panel.kontur
                    }
                }

            case .plecy:
                // Back panel: same cut angle as sides.
                if slopeKat > 0.01 {
                    el.katCieciaGornejKrawedziStopnieV0691 = slopeKat
                }

            default:
                break
            }

            elementy[index] = el
        }

        card.efektywneElementy = elementy
    }
}
