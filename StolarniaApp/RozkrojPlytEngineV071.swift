import Foundation

enum RozkrojPlytEngineV071 {
    static func build(
        list: ListaFormatekProjektuV070,
        settings: UstawieniaRozkrojuPlytV071
    ) -> RaportRozkrojuPlytV071 {
        guard settings.poprawne else {
            return RaportRozkrojuPlytV071(
                nazwaProjektu: list.nazwaProjektu,
                dataUtworzenia: Date(),
                ustawienia: settings,
                arkusze: [],
                nierozmieszczone: list.formatki.map {
                    NierozmieszczonaFormatkaV071(
                        formatka: $0,
                        powod: "Nieprawidłowe ustawienia arkusza."
                    )
                }
            )
        }

        let grouped = Dictionary(
            grouping: list.formatki
        ) {
            KluczGrupyRozkrojuV071(
                material: $0.material,
                gruboscMM: $0.gruboscMM
            )
        }

        var allSheets: [ArkuszRozkrojuV071] = []
        var allRejected: [NierozmieszczonaFormatkaV071] = []

        let sortedGroups = grouped.keys.sorted {
            $0.opis.localizedStandardCompare($1.opis)
                == .orderedAscending
        }

        for group in sortedGroups {
            let pieces = (grouped[group] ?? [])
                .sorted(by: partOrder)

            let result = pack(
                pieces: pieces,
                group: group,
                settings: settings
            )

            allSheets.append(contentsOf: result.sheets)
            allRejected.append(contentsOf: result.rejected)
        }

        let renumbered = allSheets.enumerated().map {
            offset,
            sheet in

            var copy = sheet
            copy.numer = offset + 1
            copy.id = "arkusz-\(offset + 1)-\(sheet.grupa.id)"
            return copy
        }

        return RaportRozkrojuPlytV071(
            nazwaProjektu: list.nazwaProjektu,
            dataUtworzenia: Date(),
            ustawienia: settings,
            arkusze: renumbered,
            nierozmieszczone: allRejected
        )
    }

    private struct PackResult {
        var sheets: [ArkuszRozkrojuV071]
        var rejected: [NierozmieszczonaFormatkaV071]
    }

    private struct Orientation {
        var width: Double
        var length: Double
        var rotated: Bool
    }

    private struct FreeRect {
        var x: Double
        var y: Double
        var width: Double
        var length: Double

        var maxX: Double {
            x + width
        }

        var maxY: Double {
            y + length
        }

        var area: Double {
            width * length
        }
    }

    private struct WorkingSheet {
        var freeRects: [FreeRect]
        var placements: [PolozenieFormatkiV071]
    }

    private struct SheetFillCandidate {
        var pieceIndex: Int
        var rectIndex: Int
        var orientation: Orientation
        var pieceArea: Double
        var wasteArea: Double
        var shortSideWaste: Double
        var longSideWaste: Double
    }

    private static func pack(
        pieces: [FormatkaProjektuV070],
        group: KluczGrupyRozkrojuV071,
        settings: UstawieniaRozkrojuPlytV071
    ) -> PackResult {
        let usableWidth =
            settings.szerokoscArkuszaMM
            - settings.marginesMM * 2
        let usableLength =
            settings.dlugoscArkuszaMM
            - settings.marginesMM * 2

        var workingSheets: [WorkingSheet] = []
        var rejected: [NierozmieszczonaFormatkaV071] = []
        var remaining: [FormatkaProjektuV070] = []

        for piece in pieces {
            let orientations = orientations(
                for: piece,
                settings: settings
            )
            .filter {
                $0.width <= usableWidth
                    && $0.length <= usableLength
            }

            guard !orientations.isEmpty else {
                rejected.append(
                    NierozmieszczonaFormatkaV071(
                        formatka: piece,
                        powod:
                            "Formatka przekracza użyteczny format arkusza \(formatMM(usableLength)) × \(formatMM(usableWidth)) mm."
                    )
                )
                continue
            }

            remaining.append(piece)
        }

        while !remaining.isEmpty {
            var newSheet =
                makeEmptySheet(
                    settings: settings,
                    usableWidth: usableWidth,
                    usableLength: usableLength
                )
            var placedOnSheet = false

            while let candidate =
                bestCandidate(
                    for: newSheet,
                    remaining: remaining,
                    settings: settings
                ) {
                let piece =
                    remaining.remove(
                        at: candidate.pieceIndex
                    )
                place(
                    piece,
                    orientation: candidate.orientation,
                    inRectAt: candidate.rectIndex,
                    sheet: &newSheet,
                    settings: settings
                )
                placedOnSheet = true
            }

            guard placedOnSheet else {
                let piece =
                    remaining.removeFirst()
                rejected.append(
                    NierozmieszczonaFormatkaV071(
                        formatka: piece,
                        powod:
                            "Nie udało się dopasować formatki mimo poprawnego wymiaru arkusza."
                    )
                )
                continue
            }

            workingSheets.append(newSheet)
        }

        let sheets = workingSheets.enumerated().map {
            offset,
            working in

            ArkuszRozkrojuV071(
                id: "roboczy-\(offset)-\(group.id)",
                numer: offset + 1,
                grupa: group,
                szerokoscMM: settings.szerokoscArkuszaMM,
                dlugoscMM: settings.dlugoscArkuszaMM,
                polozenia: working.placements
            )
        }

        return PackResult(
            sheets: sheets,
            rejected: rejected
        )
    }

    private static func bestCandidate(
        for sheet: WorkingSheet,
        remaining: [FormatkaProjektuV070],
        settings: UstawieniaRozkrojuPlytV071
    ) -> SheetFillCandidate? {
        var best: SheetFillCandidate?

        for pieceIndex in remaining.indices {
            let piece =
                remaining[pieceIndex]
            let pieceArea =
                piece.dlugoscMM
                * piece.szerokoscMM
            let pieceOrientations =
                orientations(
                    for: piece,
                    settings: settings
                )

            for rectIndex in sheet.freeRects.indices {
                let freeRect =
                    sheet.freeRects[rectIndex]

                for orientation in pieceOrientations {
                    guard fits(
                        orientation,
                        in: freeRect
                    ) else {
                        continue
                    }

                    let widthWaste =
                        freeRect.width
                        - orientation.width
                    let lengthWaste =
                        freeRect.length
                        - orientation.length
                    let candidate =
                        SheetFillCandidate(
                            pieceIndex: pieceIndex,
                            rectIndex: rectIndex,
                            orientation: orientation,
                            pieceArea: pieceArea,
                            wasteArea:
                                freeRect.area
                                - orientation.width
                                * orientation.length,
                            shortSideWaste:
                                min(widthWaste, lengthWaste),
                            longSideWaste:
                                max(widthWaste, lengthWaste)
                        )

                    best =
                        better(candidate, than: best)
                        ? candidate
                        : best
                }
            }
        }

        return best
    }

    private static func makeEmptySheet(
        settings: UstawieniaRozkrojuPlytV071,
        usableWidth: Double,
        usableLength: Double
    ) -> WorkingSheet {
        WorkingSheet(
            freeRects: [
                FreeRect(
                    x: settings.marginesMM,
                    y: settings.marginesMM,
                    width: usableWidth,
                    length: usableLength
                )
            ],
            placements: []
        )
    }

    private static func better(
        _ candidate: SheetFillCandidate,
        than best: SheetFillCandidate?
    ) -> Bool {
        guard let best else {
            return true
        }

        if candidate.wasteArea != best.wasteArea {
            return candidate.wasteArea < best.wasteArea
        }

        if candidate.shortSideWaste != best.shortSideWaste {
            return candidate.shortSideWaste < best.shortSideWaste
        }

        if candidate.longSideWaste != best.longSideWaste {
            return candidate.longSideWaste < best.longSideWaste
        }

        if candidate.pieceArea != best.pieceArea {
            return candidate.pieceArea > best.pieceArea
        }

        return candidate.pieceIndex < best.pieceIndex
    }

    private static func place(
        _ piece: FormatkaProjektuV070,
        orientation: Orientation,
        inRectAt rectIndex: Int,
        sheet: inout WorkingSheet,
        settings: UstawieniaRozkrojuPlytV071
    ) {
        let freeRect =
            sheet.freeRects[rectIndex]
        let placement = PolozenieFormatkiV071(
            formatka: piece,
            xMM: freeRect.x,
            yMM: freeRect.y,
            szerokoscNaArkuszuMM:
                orientation.width,
            dlugoscNaArkuszuMM:
                orientation.length,
            obrocona:
                orientation.rotated
        )

        sheet.placements.append(placement)

        let occupied = FreeRect(
            x: freeRect.x,
            y: freeRect.y,
            width:
                min(
                    orientation.width
                        + settings.rzazMM,
                    freeRect.width
                ),
            length:
                min(
                    orientation.length
                        + settings.rzazMM,
                    freeRect.length
                )
        )

        splitFreeRects(
            in: &sheet,
            around: occupied
        )
    }

    private static func splitFreeRects(
        in sheet: inout WorkingSheet,
        around occupied: FreeRect
    ) {
        var updated: [FreeRect] = []

        for freeRect in sheet.freeRects {
            guard intersects(
                freeRect,
                occupied
            ) else {
                updated.append(freeRect)
                continue
            }

            if occupied.x > freeRect.x {
                updated.append(
                    FreeRect(
                        x: freeRect.x,
                        y: freeRect.y,
                        width:
                            occupied.x
                            - freeRect.x,
                        length: freeRect.length
                    )
                )
            }

            if occupied.maxX < freeRect.maxX {
                updated.append(
                    FreeRect(
                        x: occupied.maxX,
                        y: freeRect.y,
                        width:
                            freeRect.maxX
                            - occupied.maxX,
                        length: freeRect.length
                    )
                )
            }

            if occupied.y > freeRect.y {
                updated.append(
                    FreeRect(
                        x: freeRect.x,
                        y: freeRect.y,
                        width: freeRect.width,
                        length:
                            occupied.y
                            - freeRect.y
                    )
                )
            }

            if occupied.maxY < freeRect.maxY {
                updated.append(
                    FreeRect(
                        x: freeRect.x,
                        y: occupied.maxY,
                        width: freeRect.width,
                        length:
                            freeRect.maxY
                            - occupied.maxY
                    )
                )
            }
        }

        sheet.freeRects =
            pruneContained(
                updated.filter {
                    $0.width > 0.5
                        && $0.length > 0.5
                }
            )
    }

    private static func pruneContained(
        _ rects: [FreeRect]
    ) -> [FreeRect] {
        var result = rects
        var index = 0

        while index < result.count {
            var removed = false

            for otherIndex in result.indices
            where otherIndex != index {
                if contains(
                    result[otherIndex],
                    result[index]
                ) {
                    result.remove(at: index)
                    removed = true
                    break
                }
            }

            if !removed {
                index += 1
            }
        }

        return result
    }

    private static func fits(
        _ orientation: Orientation,
        in rect: FreeRect
    ) -> Bool {
        orientation.width <= rect.width
            && orientation.length <= rect.length
    }

    private static func intersects(
        _ lhs: FreeRect,
        _ rhs: FreeRect
    ) -> Bool {
        lhs.x < rhs.maxX
            && rhs.x < lhs.maxX
            && lhs.y < rhs.maxY
            && rhs.y < lhs.maxY
    }

    private static func contains(
        _ outer: FreeRect,
        _ inner: FreeRect
    ) -> Bool {
        outer.x <= inner.x
            && outer.y <= inner.y
            && outer.maxX >= inner.maxX
            && outer.maxY >= inner.maxY
    }

    private static func orientations(
        for piece: FormatkaProjektuV070,
        settings: UstawieniaRozkrojuPlytV071
    ) -> [Orientation] {
        let base = Orientation(
            width: piece.szerokoscMM,
            length: piece.dlugoscMM,
            rotated: false
        )

        let canRotate =
            !settings.uwzgledniajKierunekDekoru
            || piece.kierunekDekoru == .dowolny

        guard canRotate,
              abs(
                  piece.dlugoscMM
                  - piece.szerokoscMM
              ) > 0.001 else {
            return [base]
        }

        return [
            base,
            Orientation(
                width: piece.dlugoscMM,
                length: piece.szerokoscMM,
                rotated: true
            )
        ]
    }

    private static func partOrder(
        _ lhs: FormatkaProjektuV070,
        _ rhs: FormatkaProjektuV070
    ) -> Bool {
        let lhsLongest =
            max(
                lhs.dlugoscMM,
                lhs.szerokoscMM
            )
        let rhsLongest =
            max(
                rhs.dlugoscMM,
                rhs.szerokoscMM
            )

        if lhsLongest != rhsLongest {
            return lhsLongest > rhsLongest
        }

        if lhs.powierzchniaM2
            != rhs.powierzchniaM2 {
            return lhs.powierzchniaM2
                > rhs.powierzchniaM2
        }

        return lhs.etykieta < rhs.etykieta
    }

    private static func formatMM(
        _ value: Double
    ) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: "pl_PL"))
                .grouping(.never)
                .precision(.fractionLength(0...1))
        )
    }
}
