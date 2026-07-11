import DomainCore
import Foundation

enum CornerCabinetProductionBuilderV026 {
    static func build(
        definition:
            CornerCabinetDefinitionV025,
        assembly:
            FurnitureAssembly
    ) -> CornerProductionPackageV026 {
        build(
            definition: definition,
            assembly: assembly,
            ustawienia:
                UstawieniaStolarniRepository
                    .aktualne()
        )
    }

    static func build(
        definition:
            CornerCabinetDefinitionV025,
        assembly:
            FurnitureAssembly,
        ustawienia:
            UstawieniaStolarni
    ) -> CornerProductionPackageV026 {
        let height =
            assembly.size.height.rawValue
        let depth =
            definition.depthMM
        let thickness =
            ustawienia
                .konstrukcja
                .gruboscPlytyKorpusuMM
        let backThickness =
            ustawienia
                .konstrukcja
                .gruboscPlecHDFMM
        let shelfDepth =
            max(depth - 20, 100)

        var parts:
            [CornerProductionPartV026] = []
        var hardware:
            [CornerHardwareItemV026] = []
        var notes: [String] = []

        switch definition.kind {
        case .lShaped:
            parts.append(
                part(
                    name: "Bok lewy",
                    quantity: 1,
                    length: height,
                    width: depth,
                    thickness: thickness,
                    material: .carcassBoard,
                    edges: [.top, .bottom, .right]
                )
            )

            parts.append(
                part(
                    name: "Bok prawy",
                    quantity: 1,
                    length: height,
                    width: depth,
                    thickness: thickness,
                    material: .carcassBoard,
                    edges: [.top, .bottom, .left]
                )
            )

            parts.append(
                part(
                    name: "Wieniec lewego ramienia",
                    quantity: 2,
                    length:
                        max(
                            definition.leftArmMM
                            - thickness,
                            100
                        ),
                    width: depth,
                    thickness: thickness,
                    material: .carcassBoard,
                    edges: [.top]
                )
            )

            parts.append(
                part(
                    name: "Wieniec prawego ramienia",
                    quantity: 2,
                    length:
                        max(
                            definition.rightArmMM
                            - thickness,
                            100
                        ),
                    width: depth,
                    thickness: thickness,
                    material: .carcassBoard,
                    edges: [.top]
                )
            )

            if definition.shelfCount > 0 {
                parts.append(
                    part(
                        name: "Półka narożna L — ramię lewe",
                        quantity:
                            definition.shelfCount,
                        length:
                            max(
                                definition.leftArmMM
                                - thickness * 2,
                                100
                            ),
                        width:
                            shelfDepth,
                        thickness: thickness,
                        material: .carcassBoard,
                        edges: [.top]
                    )
                )

                parts.append(
                    part(
                        name: "Półka narożna L — ramię prawe",
                        quantity:
                            definition.shelfCount,
                        length:
                            max(
                                definition.rightArmMM
                                - thickness * 2,
                                100
                            ),
                        width:
                            shelfDepth,
                        thickness: thickness,
                        material: .carcassBoard,
                        edges: [.top]
                    )
                )
            }

            notes.append(
                "Połączyć oba ramiona pod kątem 90°."
            )
            notes.append(
                "Przed produkcją zweryfikować kierunek otwierania i luz frontu w narożniku."
            )

        case .diagonalFront:
            let bodyWidth =
                max(
                    definition.leftArmMM,
                    definition.rightArmMM
                )

            parts.append(
                part(
                    name: "Bok korpusu",
                    quantity: 2,
                    length: height,
                    width: depth,
                    thickness: thickness,
                    material: .carcassBoard,
                    edges: [.top, .bottom]
                )
            )

            parts.append(
                part(
                    name: "Wieniec narożny",
                    quantity: 2,
                    length:
                        max(
                            bodyWidth
                            - thickness * 2,
                            100
                        ),
                    width: depth,
                    thickness: thickness,
                    material: .carcassBoard,
                    edges: [.top]
                )
            )

            parts.append(
                part(
                    name: "Front skośny",
                    quantity: 1,
                    length:
                        max(
                            height - 4,
                            100
                        ),
                    width:
                        definition.frontWidthMM,
                    thickness: thickness,
                    material: .frontBoard,
                    edges:
                        Set(
                            EdgeBandingSideV026
                                .allCases
                        ),
                    note:
                        "Kąt montażu: \(Int(definition.frontAngleDegrees.rounded()))°"
                )
            )

            if definition.shelfCount > 0 {
                parts.append(
                    part(
                        name: "Półka narożna",
                        quantity:
                            definition.shelfCount,
                        length:
                            max(
                                bodyWidth
                                - thickness * 2,
                                100
                            ),
                        width:
                            shelfDepth,
                        thickness: thickness,
                        material: .carcassBoard,
                        edges: [.top]
                    )
                )
            }

            notes.append(
                "Wieniec i półki wymagają docięcia pod kąt frontu."
            )

        case .blindCorner:
            let bodyWidth =
                definition.leftArmMM
                + definition.deadSpaceMM

            parts.append(
                part(
                    name: "Bok korpusu",
                    quantity: 2,
                    length: height,
                    width: depth,
                    thickness: thickness,
                    material: .carcassBoard,
                    edges: [.top, .bottom]
                )
            )

            parts.append(
                part(
                    name: "Wieniec korpusu",
                    quantity: 2,
                    length:
                        max(
                            bodyWidth
                            - thickness * 2,
                            100
                        ),
                    width: depth,
                    thickness: thickness,
                    material: .carcassBoard,
                    edges: [.top]
                )
            )

            parts.append(
                part(
                    name: "Panel martwej strefy",
                    quantity: 1,
                    length:
                        max(
                            height - thickness * 2,
                            100
                        ),
                    width:
                        definition.deadSpaceMM,
                    thickness: thickness,
                    material: .carcassBoard,
                    edges: [.left, .right]
                )
            )

            parts.append(
                part(
                    name: "Front",
                    quantity: 1,
                    length:
                        max(
                            height - 4,
                            100
                        ),
                    width:
                        definition.frontWidthMM,
                    thickness: thickness,
                    material: .frontBoard,
                    edges:
                        Set(
                            EdgeBandingSideV026
                                .allCases
                        )
                )
            )

            if definition.shelfCount > 0 {
                parts.append(
                    part(
                        name: "Półka ślepego narożnika",
                        quantity:
                            definition.shelfCount,
                        length:
                            max(
                                bodyWidth
                                - thickness * 2,
                                100
                            ),
                        width:
                            shelfDepth,
                        thickness: thickness,
                        material: .carcassBoard,
                        edges: [.top]
                    )
                )
            }

            notes.append(
                "Martwa strefa: \(Int(definition.deadSpaceMM.rounded())) mm."
            )

        case .halfBlind:
            // Półnarożnik: boczny korpus stojący wzdłuż ściany + front tylko
            // po widocznej stronie. Wysuniecie = deadSpaceMM.
            let visibleWidth = definition.leftArmMM

            parts.append(
                part(
                    name: "Bok korpusu",
                    quantity: 2,
                    length: height,
                    width: depth,
                    thickness: thickness,
                    material: .carcassBoard,
                    edges: [.top, .bottom]
                )
            )

            parts.append(
                part(
                    name: "Wieniec",
                    quantity: 2,
                    length: max(visibleWidth - thickness * 2, 100),
                    width: depth,
                    thickness: thickness,
                    material: .carcassBoard,
                    edges: [.top]
                )
            )

            parts.append(
                part(
                    name: "Front",
                    quantity: 1,
                    length: max(height - 4, 100),
                    width: definition.frontWidthMM,
                    thickness: thickness,
                    material: .frontBoard,
                    edges: Set(EdgeBandingSideV026.allCases)
                )
            )

            if definition.shelfCount > 0 {
                parts.append(
                    part(
                        name: "Półka",
                        quantity: definition.shelfCount,
                        length: max(visibleWidth - thickness * 2, 100),
                        width: shelfDepth,
                        thickness: thickness,
                        material: .carcassBoard,
                        edges: [.top]
                    )
                )
            }

            notes.append(
                "Półnarożnik. Wysuniecie w głąb narożnika: \(Int(definition.deadSpaceMM.rounded())) mm."
            )
        }

        parts.append(
            part(
                name: "Plecy",
                quantity: 1,
                length:
                    max(
                        height - 6,
                        100
                    ),
                width:
                    max(
                        definition.leftArmMM
                        - 6,
                        100
                    ),
                thickness:
                    backThickness,
                material: .backPanel,
                edges: []
            )
        )

        hardware.append(
            CornerHardwareItemV026(
                name: "Konfirmaty / złącza korpusowe",
                quantity:
                    max(
                        parts.count * 4,
                        16
                    ),
                note:
                    "Ilość orientacyjna."
            )
        )

        hardware.append(
            CornerHardwareItemV026(
                name: "Podpórki półek",
                quantity:
                    definition.shelfCount * 4,
                note: ""
            )
        )

        hardware.append(
            CornerHardwareItemV026(
                name: "Zawiasy",
                quantity:
                    max(
                        Int(
                            ceil(
                                height / 700
                            )
                        ),
                        2
                    ),
                note:
                    "Dobrać typ zawiasu do konstrukcji narożnika."
            )
        )

        return CornerProductionPackageV026(
            assemblyID:
                definition.assemblyID,
            cornerDefinitionID:
                definition.id,
            parts: parts,
            hardware: hardware,
            notes:
                notes
                + definition
                    .validationMessages
        )
    }

    private static func part(
        name: String,
        quantity: Int,
        length: Double,
        width: Double,
        thickness: Double,
        material:
            CornerProductionMaterialV026,
        edges:
            Set<EdgeBandingSideV026>,
        note: String = ""
    ) -> CornerProductionPartV026 {
        CornerProductionPartV026(
            name: name,
            quantity:
                max(quantity, 1),
            lengthMM:
                max(length, 1),
            widthMM:
                max(width, 1),
            thicknessMM:
                max(thickness, 1),
            material: material,
            edgeBanding: edges,
            note: note
        )
    }
}
