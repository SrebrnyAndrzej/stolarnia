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

        return card
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
                            "Front",
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

        return KartaTechnicznaSzafki(
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
                $0.element
                    .localizedCaseInsensitiveContains(
                        elementName
                    )
            }
        }

        elements.append(
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
                    points(
                        for:
                            "Bok lewy"
                    )
            )
        )

        elements.append(
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
                    points(
                        for:
                            "Bok prawy"
                    )
            )
        )

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
