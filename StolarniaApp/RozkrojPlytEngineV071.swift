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

    private struct Shelf {
        var y: Double
        var height: Double
        var usedWidth: Double
        var placements: [PolozenieFormatkiV071]
    }

    private struct WorkingSheet {
        var shelves: [Shelf]
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

            if placeInExistingShelf(
                piece,
                orientations: orientations,
                sheets: &workingSheets,
                settings: settings,
                usableWidth: usableWidth
            ) {
                continue
            }

            if placeOnNewShelf(
                piece,
                orientations: orientations,
                sheets: &workingSheets,
                settings: settings,
                usableWidth: usableWidth,
                usableLength: usableLength
            ) {
                continue
            }

            var newSheet = WorkingSheet(
                shelves: []
            )

            guard appendNewShelf(
                piece,
                orientations: orientations,
                sheet: &newSheet,
                settings: settings,
                usableWidth: usableWidth,
                usableLength: usableLength
            ) else {
                rejected.append(
                    NierozmieszczonaFormatkaV071(
                        formatka: piece,
                        powod:
                            "Nie udało się rozpocząć nowego arkusza dla formatki."
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
                polozenia:
                    working.shelves.flatMap(
                        \.placements
                    )
            )
        }

        return PackResult(
            sheets: sheets,
            rejected: rejected
        )
    }

    private static func placeInExistingShelf(
        _ piece: FormatkaProjektuV070,
        orientations: [Orientation],
        sheets: inout [WorkingSheet],
        settings: UstawieniaRozkrojuPlytV071,
        usableWidth: Double
    ) -> Bool {
        struct Candidate {
            var sheetIndex: Int
            var shelfIndex: Int
            var orientation: Orientation
            var score: Double
        }

        var best: Candidate?

        for sheetIndex in sheets.indices {
            for shelfIndex in sheets[sheetIndex].shelves.indices {
                let shelf = sheets[sheetIndex].shelves[shelfIndex]

                for orientation in orientations {
                    let fits =
                        orientation.length <= shelf.height
                        && shelf.usedWidth
                            + orientation.width
                            <= usableWidth

                    guard fits else {
                        continue
                    }

                    let horizontalWaste =
                        usableWidth
                        - shelf.usedWidth
                        - orientation.width
                    let verticalWaste =
                        shelf.height
                        - orientation.length
                    let score =
                        horizontalWaste
                        + verticalWaste * 0.25

                    if best == nil
                        || score < best!.score {
                        best = Candidate(
                            sheetIndex: sheetIndex,
                            shelfIndex: shelfIndex,
                            orientation: orientation,
                            score: score
                        )
                    }
                }
            }
        }

        guard let best else {
            return false
        }

        var shelf =
            sheets[best.sheetIndex]
                .shelves[best.shelfIndex]
        let x =
            settings.marginesMM
            + shelf.usedWidth
        let placement = PolozenieFormatkiV071(
            formatka: piece,
            xMM: x,
            yMM: shelf.y,
            szerokoscNaArkuszuMM:
                best.orientation.width,
            dlugoscNaArkuszuMM:
                best.orientation.length,
            obrocona:
                best.orientation.rotated
        )

        shelf.placements.append(placement)
        shelf.usedWidth +=
            best.orientation.width
            + settings.rzazMM

        sheets[best.sheetIndex]
            .shelves[best.shelfIndex] = shelf
        return true
    }

    private static func placeOnNewShelf(
        _ piece: FormatkaProjektuV070,
        orientations: [Orientation],
        sheets: inout [WorkingSheet],
        settings: UstawieniaRozkrojuPlytV071,
        usableWidth: Double,
        usableLength: Double
    ) -> Bool {
        struct Candidate {
            var sheetIndex: Int
            var orientation: Orientation
            var score: Double
        }

        var best: Candidate?

        for sheetIndex in sheets.indices {
            let nextY = nextShelfY(
                for: sheets[sheetIndex],
                settings: settings
            )
            let availableLength =
                settings.marginesMM
                + usableLength
                - nextY

            for orientation in orientations {
                guard orientation.width <= usableWidth,
                      orientation.length <= availableLength else {
                    continue
                }

                let score =
                    availableLength
                    - orientation.length

                if best == nil
                    || score < best!.score {
                    best = Candidate(
                        sheetIndex: sheetIndex,
                        orientation: orientation,
                        score: score
                    )
                }
            }
        }

        guard let best else {
            return false
        }

        let y = nextShelfY(
            for: sheets[best.sheetIndex],
            settings: settings
        )
        let placement = PolozenieFormatkiV071(
            formatka: piece,
            xMM: settings.marginesMM,
            yMM: y,
            szerokoscNaArkuszuMM:
                best.orientation.width,
            dlugoscNaArkuszuMM:
                best.orientation.length,
            obrocona:
                best.orientation.rotated
        )

        sheets[best.sheetIndex]
            .shelves.append(
                Shelf(
                    y: y,
                    height:
                        best.orientation.length,
                    usedWidth:
                        best.orientation.width
                        + settings.rzazMM,
                    placements: [placement]
                )
            )

        return true
    }

    private static func appendNewShelf(
        _ piece: FormatkaProjektuV070,
        orientations: [Orientation],
        sheet: inout WorkingSheet,
        settings: UstawieniaRozkrojuPlytV071,
        usableWidth: Double,
        usableLength: Double
    ) -> Bool {
        let fitting = orientations
            .filter {
                $0.width <= usableWidth
                    && $0.length <= usableLength
            }
            .sorted {
                let lhsWaste =
                    usableWidth
                    - $0.width
                let rhsWaste =
                    usableWidth
                    - $1.width

                if lhsWaste == rhsWaste {
                    return $0.length > $1.length
                }
                return lhsWaste < rhsWaste
            }

        guard let orientation = fitting.first else {
            return false
        }

        let placement = PolozenieFormatkiV071(
            formatka: piece,
            xMM: settings.marginesMM,
            yMM: settings.marginesMM,
            szerokoscNaArkuszuMM:
                orientation.width,
            dlugoscNaArkuszuMM:
                orientation.length,
            obrocona:
                orientation.rotated
        )

        sheet.shelves.append(
            Shelf(
                y: settings.marginesMM,
                height: orientation.length,
                usedWidth:
                    orientation.width
                    + settings.rzazMM,
                placements: [placement]
            )
        )

        return true
    }

    private static func nextShelfY(
        for sheet: WorkingSheet,
        settings: UstawieniaRozkrojuPlytV071
    ) -> Double {
        guard let last = sheet.shelves.last else {
            return settings.marginesMM
        }

        return last.y
            + last.height
            + settings.rzazMM
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
