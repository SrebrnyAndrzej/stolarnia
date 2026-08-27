import DomainCore
import Foundation

struct ElewacjaScianyProstokatMM: Hashable {
    var x: Millimeters
    var y: Millimeters
    var width: Millimeters
    var height: Millimeters

    var maxX: Millimeters { x + width }
    var maxY: Millimeters { y + height }
    var centerX: Millimeters { x + width / 2 }
    var centerY: Millimeters { y + height / 2 }
}

struct PunktElewacjiScianyV069:
    Hashable
{
    let x:
        Millimeters
    let y:
        Millimeters
}

struct FrontElewacjiModuluV068:
    Identifiable,
    Hashable
{
    let id: String
    let rect:
        ElewacjaScianyProstokatMM
    let otwarcie:
        KierunekOtwarciaFrontuV068
    let opisOkucia: String?
}

struct MebelElewacjaScianyElement: Identifiable, Hashable {
    let id: FurnitureAssemblyID
    let rect: ElewacjaScianyProstokatMM
    let name: String
    let isFinishing: Bool
    let componentLinesY: [Millimeters]
    let componentLinesX: [Millimeters]
    let frontsV068:
        [FrontElewacjiModuluV068]
    let konturV069:
        [PunktElewacjiScianyV069]?
    let gornaKrawedzV069:
        [PunktElewacjiScianyV069]
    let jestScietySkosemV069:
        Bool
    let rezerwaSkosuMMV069:
        Double
}

struct OtworElewacjaScianyElement: Identifiable, Hashable {
    enum Kind: Hashable {
        case window
        case door
        case recess
        case bayOutward
        case bayInward
    }

    let id: String
    let kind: Kind
    let symbol: String
    let rect: ElewacjaScianyProstokatMM
}

enum MebelElewacjaScianyGeometry {
    static func shouldMirrorElevation(
        wall:
            WallSegment,
        room:
            RoomDefinition
    ) -> Bool {
        signedArea(
            room.geometry.boundary
        ) > 0
    }

    static func wallLength(
        wall: WallSegment,
        room: RoomDefinition
    ) -> Millimeters? {
        room.geometry.geometry(of: wall.id)?.length
    }

    static func wallMaximumHeight(
        wall: WallSegment
    ) -> Millimeters {
        max(wall.startHeight, wall.endHeight)
    }

    static func wallMaximumHeight(
        wall: WallSegment,
        room: RoomDefinition
    ) -> Millimeters {
        guard let profile =
                SilnikSkosuPomieszczeniaV069
                    .profilSkosu(
                        dla: wall.id,
                        w: room
                    ),
              let maximum =
                profile.points
                    .map(
                        \.offsetFromReference
                    )
                    .max()
        else {
            return wallMaximumHeight(
                wall: wall
            )
        }

        return max(
            maximum,
            wallMaximumHeight(
                wall: wall
            )
        )
    }

    static func furniture(
        on wall: WallSegment,
        room: RoomDefinition,
        assemblies: [FurnitureAssembly]
    ) -> [MebelElewacjaScianyElement] {
        assemblies.compactMap { assembly in
            guard let placement = assembly.placement,
                  placement.wallID == wall.id else {
                return nil
            }

            let rect = ElewacjaScianyProstokatMM(
                x: placement.offsetAlongWall,
                y: placement.bottomOffset,
                width: assembly.size.width,
                height: assembly.size.height
            )

            let slopeContourV069 =
                konturSkosuV069(
                    for: rect,
                    wallID: wall.id,
                    room: room
                )

            let horizontalLines = assembly.components.compactMap { component -> Millimeters? in
                switch component.role {
                case .shelf, .bottom, .top, .reinforcement:
                    let value = placement.bottomOffset + component.localPosition.y
                    guard value > rect.y, value < rect.maxY else { return nil }
                    return value
                default:
                    return nil
                }
            }

            let verticalLines = assembly.components.compactMap { component -> Millimeters? in
                switch component.role {
                case .divider, .side:
                    let value = placement.offsetAlongWall + component.localPosition.x
                    guard value > rect.x, value < rect.maxX else { return nil }
                    return value
                default:
                    return nil
                }
            }

            return MebelElewacjaScianyElement(
                id: assembly.id,
                rect: rect,
                name: assembly.name,
                isFinishing: assembly.components.contains {
                    $0.role == .filler
                        || $0.role == .maskingPanel
                        || $0.role == .decorativeSide
                },
                componentLinesY: uniqueSorted(horizontalLines),
                componentLinesX: uniqueSorted(verticalLines),
                frontsV068:
                    frontsV068(
                        for: assembly,
                        placement:
                            placement,
                        rect: rect
                    ),
                konturV069:
                    slopeContourV069?
                        .punkty
                        .map {
                            PunktElewacjiScianyV069(
                                x:
                                    Millimeters(
                                        $0.xMM
                                    ),
                                y:
                                    Millimeters(
                                        $0.wysokoscMM
                                    )
                            )
                        },
                gornaKrawedzV069:
                    slopeContourV069?
                        .gornaKrawedz
                        .map {
                            PunktElewacjiScianyV069(
                                x:
                                    Millimeters(
                                        $0.xMM
                                    ),
                                y:
                                    Millimeters(
                                        $0.wysokoscMM
                                    )
                            )
                        }
                    ?? [],
                jestScietySkosemV069:
                    slopeContourV069?
                        .jestSciety
                    ?? false,
                rezerwaSkosuMMV069:
                    slopeContourV069?
                        .minimalnyPrzeswitMM
                    ?? 0
            )
        }
        .sorted { lhs, rhs in
            if lhs.rect.y == rhs.rect.y {
                return lhs.rect.x < rhs.rect.x
            }
            return lhs.rect.y < rhs.rect.y
        }
    }

    static func slopeProfile(
        on wall:
            WallSegment,
        room:
            RoomDefinition
    ) -> WallProfileDefinition? {
        SilnikSkosuPomieszczeniaV069
            .profilSkosu(
                dla: wall.id,
                w: room
            )
    }

    // Overall slope angle (first → last point) in degrees.
    static func katSkosuStopnie(
        profil:
            WallProfileDefinition
    ) -> Double? {
        let pts =
            SilnikSkosuPomieszczeniaV069
                .punktyProfilu(profil)
        guard let first = pts.first,
              let last = pts.last,
              first.id != last.id
        else { return nil }
        let run =
            abs(last.xMM - first.xMM)
        let rise =
            abs(
                last.wysokoscMM
                    - first.wysokoscMM
            )
        guard run > 0 else { return nil }
        return atan2(rise, run)
            * 180 / .pi
    }

    // Per-segment breakdown for multi-pitch profiles.
    struct SegmentSkosuV069 {
        let lowPunkt:
            PunktProfiluSkosuV069
        let highPunkt:
            PunktProfiluSkosuV069
        let katStopnie: Double
        let midXMM: Double
        let midWysokoscMM: Double
    }

    static func segmentySkosu(
        profil:
            WallProfileDefinition
    ) -> [SegmentSkosuV069] {
        let pts =
            SilnikSkosuPomieszczeniaV069
                .punktyProfilu(profil)
        guard pts.count >= 2 else {
            return []
        }

        return zip(
            pts,
            pts.dropFirst()
        )
        .compactMap { a, b in
            let run =
                abs(b.xMM - a.xMM)
            let rise =
                abs(
                    b.wysokoscMM
                        - a.wysokoscMM
                )
            guard run > 0 else {
                return nil
            }
            let angle =
                atan2(rise, run)
                * 180 / .pi
            let low =
                a.wysokoscMM
                    <= b.wysokoscMM
                ? a : b
            let high =
                a.wysokoscMM
                    <= b.wysokoscMM
                ? b : a
            return SegmentSkosuV069(
                lowPunkt: low,
                highPunkt: high,
                katStopnie: angle,
                midXMM:
                    (a.xMM + b.xMM) / 2,
                midWysokoscMM:
                    (
                        a.wysokoscMM
                        + b.wysokoscMM
                    ) / 2
            )
        }
    }

    static func slopeWallContour(
        on wall:
            WallSegment,
        room:
            RoomDefinition
    ) -> [PunktElewacjiScianyV069]? {
        guard let profile =
                slopeProfile(
                    on: wall,
                    room: room
                )
        else {
            return nil
        }

        let top =
            SilnikSkosuPomieszczeniaV069
                .punktyProfilu(
                    profile
                )

        guard top.count >= 2
        else {
            return nil
        }

        var result:
            [PunktElewacjiScianyV069] = [
                PunktElewacjiScianyV069(
                    x: .zero,
                    y: .zero
                )
            ]

        if let last = top.last {
            result.append(
                PunktElewacjiScianyV069(
                    x:
                        Millimeters(
                            last.xMM
                        ),
                    y: .zero
                )
            )
        }

        result.append(
            contentsOf:
                top
                    .reversed()
                    .map {
                        PunktElewacjiScianyV069(
                            x:
                                Millimeters(
                                    $0.xMM
                                ),
                            y:
                                Millimeters(
                                    $0.wysokoscMM
                                )
                        )
                    }
        )

        return result
    }

    private static func konturSkosuV069(
        for rect:
            ElewacjaScianyProstokatMM,
        wallID:
            WallID,
        room:
            RoomDefinition
    ) -> KonturMeblaPodSkosemV069? {
        guard let profile =
                SilnikSkosuPomieszczeniaV069
                    .profilSkosu(
                        dla: wallID,
                        w: room
                    )
        else {
            return nil
        }

        return try? SilnikSkosuPomieszczeniaV069
            .konturMebla(
                xMM:
                    rect.x.rawValue,
                yMM:
                    rect.y.rawValue,
                szerokoscMM:
                    rect.width.rawValue,
                wysokoscMM:
                    rect.height.rawValue,
                profil:
                    profile
            )
    }

    static func openings(
        on wall: WallSegment,
        room: RoomDefinition
    ) -> [OtworElewacjaScianyElement] {
        let windows = room.windows.enumerated().compactMap {
            index,
            window -> OtworElewacjaScianyElement? in
            guard window.placement.wallID == wall.id else {
                return nil
            }

            return OtworElewacjaScianyElement(
                id: "window-\(window.id.description)",
                kind: .window,
                symbol: "O\(index + 1)",
                rect: rect(from: window.placement)
            )
        }

        let doors = room.doors.enumerated().compactMap {
            index,
            door -> OtworElewacjaScianyElement? in
            guard door.placement.wallID == wall.id else {
                return nil
            }

            return OtworElewacjaScianyElement(
                id: "door-\(door.id.description)",
                kind: .door,
                symbol: "D\(index + 1)",
                rect: rect(from: door.placement)
            )
        }

        let recesses = room.recesses.enumerated().compactMap {
            index,
            recess -> OtworElewacjaScianyElement? in
            guard recess.wallID == wall.id else {
                return nil
            }

            let bounds = localBounds(
                contour: recess.openingContour
            )
            return OtworElewacjaScianyElement(
                id: "recess-\(recess.id.description)",
                kind: .recess,
                symbol: "WN\(index + 1)",
                rect: bounds
            )
        }

        let bays = room.bayProjections.enumerated().compactMap {
            index,
            bay -> OtworElewacjaScianyElement? in
            guard bay.wallID == wall.id else {
                return nil
            }

            return OtworElewacjaScianyElement(
                id: "bay-\(bay.id.description)",
                kind: bay.direction == .outward
                    ? .bayOutward
                    : .bayInward,
                symbol: "WY\(index + 1)",
                rect: ElewacjaScianyProstokatMM(
                    x: bay.offsetFromWallStart,
                    y: bay.bottomOffset,
                    width: bay.width,
                    height: bay.height
                )
            )
        }

        return windows + doors + recesses + bays
    }

    /// Domyślny front wypełniający cały korpus z marginesem 2 mm.
    /// Używany gdy moduł nie ma jeszcze karty technicznej lub konfiguracji frontu.
    private static func defaultSingleFront(
        assembly: FurnitureAssembly,
        rect: ElewacjaScianyProstokatMM
    ) -> FrontElewacjiModuluV068 {
        let gap = 2.0
        return FrontElewacjiModuluV068(
            id: "\(assembly.id.description)-front-default",
            rect: ElewacjaScianyProstokatMM(
                x: rect.x + Millimeters(gap),
                y: rect.y + Millimeters(gap),
                width: Millimeters(
                    max(rect.width.rawValue - gap * 2, 1)
                ),
                height: Millimeters(
                    max(rect.height.rawValue - gap * 2, 1)
                )
            ),
            otwarcie: .lewy,
            opisOkucia: nil
        )
    }

    private static func frontsV068(
        for assembly:
            FurnitureAssembly,
        placement:
            FurniturePlacement,
        rect:
            ElewacjaScianyProstokatMM
    ) -> [FrontElewacjiModuluV068] {
        guard
            let card =
                KonfiguracjaFunkcjonalnaModuluV068Resolver
                    .karta(
                        dla: assembly
                    )
        else {
            // Brak karty technicznej — rysuj domyślny jeden front.
            return [
                defaultSingleFront(
                    assembly: assembly,
                    rect: rect
                )
            ]
        }

        let drawers =
            card
                .efektywneSzuflady
                .filter(\.aktywna)
                .sorted {
                    $0.pozycjaDolnaYMM
                    < $1.pozycjaDolnaYMM
                }

        if !drawers.isEmpty {
            return drawers
                .enumerated()
                .compactMap {
                    index,
                    drawer in

                    let localY =
                        max(
                            drawer
                                .pozycjaDolnaYMM,
                            0
                        )
                    let availableHeight =
                        max(
                            rect.height
                                .rawValue
                            - localY,
                            0
                        )
                    let frontHeight =
                        min(
                            max(
                                drawer
                                    .wysokoscFrontuMM,
                                1
                            ),
                            availableHeight
                        )

                    guard frontHeight > 0 else {
                        return nil
                    }

                    return FrontElewacjiModuluV068(
                        id:
                            "\(assembly.id.description)-drawer-\(drawer.id.uuidString)",
                        rect:
                            ElewacjaScianyProstokatMM(
                                x:
                                    rect.x,
                                y:
                                    placement
                                        .bottomOffset
                                    + Millimeters(
                                        localY
                                    ),
                                width:
                                    rect.width,
                                height:
                                    Millimeters(
                                        frontHeight
                                    )
                            ),
                        otwarcie:
                            .szuflada,
                        opisOkucia:
                            ProfilOkuciaResolverV068
                                .opis(
                                    id:
                                        drawer
                                            .profilID
                                )
                    )
                }
        }

        guard let configuration =
            card
                .konfiguracjaFunkcjonalnaV068
        else {
            // Karta istnieje, ale bez konfiguracji frontu — rysuj domyślny jeden front.
            return [
                defaultSingleFront(
                    assembly: assembly,
                    rect: rect
                )
            ]
        }

        let count =
            configuration
                .front
                .bezpiecznaLiczbaFrontow
        let opening =
            ProfilOkuciaResolverV068
                .efektywneOtwarcie(
                    konfiguracja:
                        configuration
                )
        let gap = 2.0
        let totalGap =
            gap
            * Double(
                count + 1
            )
        let width =
            max(
                (
                    rect.width
                        .rawValue
                    - totalGap
                ) / Double(count),
                1
            )
        let height =
            max(
                rect.height
                    .rawValue
                - gap * 2,
                1
            )
        let hardwareDescription =
            configuration
                .front
                .profilOkuciaID
                .isEmpty
            ? nil
            : ProfilOkuciaResolverV068
                .opis(
                    id:
                        configuration
                            .front
                            .profilOkuciaID
                )

        return (0..<count)
            .map { index in
                let segmentOpening:
                    KierunekOtwarciaFrontuV068

                if count > 1,
                   opening == .lewy
                    || opening == .prawy {
                    segmentOpening =
                        index.isMultiple(
                            of: 2
                        )
                        ? .lewy
                        : .prawy
                } else {
                    segmentOpening =
                        opening
                }

                return FrontElewacjiModuluV068(
                    id:
                        "\(assembly.id.description)-front-\(index)",
                    rect:
                        ElewacjaScianyProstokatMM(
                            x:
                                rect.x
                                + Millimeters(
                                    gap
                                    + Double(index)
                                        * (
                                            width
                                            + gap
                                        )
                                ),
                            y:
                                rect.y
                                + Millimeters(
                                    gap
                                ),
                            width:
                                Millimeters(
                                    width
                                ),
                            height:
                                Millimeters(
                                    height
                                )
                        ),
                    otwarcie:
                        segmentOpening,
                    opisOkucia:
                        hardwareDescription
                )
            }
    }

    private static func rect(
        from placement: WallOpeningPlacement
    ) -> ElewacjaScianyProstokatMM {
        ElewacjaScianyProstokatMM(
            x: placement.offsetFromWallStart,
            y: placement.bottomOffset,
            width: placement.width,
            height: placement.height
        )
    }

    private static func localBounds(
        contour: ClosedContour2D
    ) -> ElewacjaScianyProstokatMM {
        let points = contour.segments.flatMap {
            [$0.start, $0.end]
        }
        let minX = points.map(\.x).min() ?? .zero
        let maxX = points.map(\.x).max() ?? minX
        let minY = points.map(\.y).min() ?? .zero
        let maxY = points.map(\.y).max() ?? minY

        return ElewacjaScianyProstokatMM(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    private static func uniqueSorted(
        _ values: [Millimeters]
    ) -> [Millimeters] {
        let rounded = Dictionary(grouping: values) {
            Int(($0.rawValue * 10).rounded())
        }
        return rounded.values.compactMap(\.first).sorted()
    }

    private static func signedArea(
        _ contour:
            ClosedContour2D
    ) -> Double {
        let points =
            contour.segments.map(\.start)
        guard points.count >= 3 else {
            return 0
        }

        let shifted =
            Array(points.dropFirst())
            + Array(points.prefix(1))

        return zip(
            points,
            shifted
        )
        .reduce(0.0) {
            partial,
            pair in

            partial
            + pair.0.x.rawValue * pair.1.y.rawValue
            - pair.1.x.rawValue * pair.0.y.rawValue
        }
        / 2
    }
}
