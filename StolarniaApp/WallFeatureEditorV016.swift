import DomainCore
import SwiftUI

nonisolated enum WallFeatureKindV016: String, CaseIterable, Identifiable, Sendable {
    case window
    case door
    case recess
    case bayProjection

    var id: String { rawValue }

    var title: String {
        switch self {
        case .window: return "Okno"
        case .door: return "Drzwi"
        case .recess: return "Wnęka"
        case .bayProjection: return "Wykusz / uskok"
        }
    }

    var systemImage: String {
        switch self {
        case .window: return "window.vertical.closed"
        case .door: return "door.left.hand.closed"
        case .recess: return "rectangle.inset.filled"
        case .bayProjection: return "rectangle.portrait.and.arrow.forward"
        }
    }
}

nonisolated enum WallFeatureReferenceEdgeV016: String, CaseIterable, Identifiable, Sendable {
    case right
    case left

    var id: String { rawValue }

    var title: String {
        switch self {
        case .right: return "Od prawej"
        case .left: return "Od lewej"
        }
    }
}

nonisolated struct WallFeatureLocalRectV016: Hashable, Sendable {
    let x: Millimeters
    let y: Millimeters
    let width: Millimeters
    let height: Millimeters
    let depth: Millimeters
}

nonisolated enum WallFeaturePayloadV016: Hashable, Sendable {
    case window(WindowDefinition)
    case door(DoorDefinition)
    case recess(RecessDefinition)
    case bayProjection(BayProjectionDefinitionV016)

    var kind: WallFeatureKindV016 {
        switch self {
        case .window: return .window
        case .door: return .door
        case .recess: return .recess
        case .bayProjection: return .bayProjection
        }
    }

    var wallID: WallID {
        switch self {
        case .window(let value):
            return value.placement.wallID
        case .door(let value):
            return value.placement.wallID
        case .recess(let value):
            return value.wallID
        case .bayProjection(let value):
            return value.wallID
        }
    }

    var displayName: String {
        switch self {
        case .window: return "Okno"
        case .door: return "Drzwi"
        case .recess(let value): return value.name
        case .bayProjection(let value): return value.name
        }
    }

    var localRect: WallFeatureLocalRectV016 {
        switch self {
        case .window(let value):
            return WallFeatureLocalRectV016(
                x: value.placement.offsetFromWallStart,
                y: value.placement.bottomOffset,
                width: value.placement.width,
                height: value.placement.height,
                depth: value.placement.revealDepth
            )

        case .door(let value):
            return WallFeatureLocalRectV016(
                x: value.placement.offsetFromWallStart,
                y: value.placement.bottomOffset,
                width: value.placement.width,
                height: value.placement.height,
                depth: value.placement.revealDepth
            )

        case .recess(let value):
            let points = value.openingContour.segments.flatMap {
                [$0.start, $0.end]
            }
            let minX = points.map(\.x).min() ?? .zero
            let maxX = points.map(\.x).max() ?? minX
            let minY = points.map(\.y).min() ?? .zero
            let maxY = points.map(\.y).max() ?? minY
            return WallFeatureLocalRectV016(
                x: minX,
                y: minY,
                width: maxX - minX,
                height: maxY - minY,
                depth: value.depth
            )

        case .bayProjection(let value):
            return WallFeatureLocalRectV016(
                x: value.offsetFromWallStart,
                y: value.bottomOffset,
                width: value.width,
                height: value.height,
                depth: value.depth
            )
        }
    }
}

nonisolated struct WallFeatureEditorContextV016: Hashable, Sendable {
    let wallID: WallID
    let wallName: String
    let wallLength: Millimeters
    let wallHeight: Millimeters
    let defaultKind: WallFeatureKindV016

    init(
        wallID: WallID,
        wallName: String,
        wallLength: Millimeters,
        wallHeight: Millimeters,
        defaultKind: WallFeatureKindV016 = .window
    ) {
        self.wallID = wallID
        self.wallName = wallName
        self.wallLength = wallLength
        self.wallHeight = wallHeight
        self.defaultKind = defaultKind
    }
}

nonisolated func applyWallFeatureV016(
    _ payload: WallFeaturePayloadV016,
    to room: inout RoomDefinition
) throws {
    switch payload {
    case .window(let value):
        try room.addWindow(value)
    case .door(let value):
        try room.addDoor(value)
    case .recess(let value):
        try room.addRecess(value)
    case .bayProjection(let value):
        try room.addBayProjection(value)
    }
}

nonisolated enum WallFeatureValidatorV016 {
    static func validate(
        _ payload: WallFeaturePayloadV016,
        in room: RoomDefinition,
        assemblies: [FurnitureAssembly]
    ) throws {
        guard let wall = room.geometry.wall(id: payload.wallID),
              let segment = room.geometry.geometry(of: payload.wallID),
              case .line = segment else {
            throw DomainError.invariantViolation(
                "Elementy można dodawać do prostej, istniejącej ściany."
            )
        }

        let rect = payload.localRect
        guard rect.x >= .zero,
              rect.y >= .zero,
              rect.width > .zero,
              rect.height > .zero,
              rect.x + rect.width <= segment.length + 0.1 else {
            throw DomainError.invariantViolation(
                "Element nie mieści się w długości ściany \(wall.name)."
            )
        }

        guard rect.y + rect.height
                <= max(wall.startHeight, wall.endHeight) + 0.1 else {
            throw DomainError.invariantViolation(
                "Element nie mieści się w wysokości ściany \(wall.name)."
            )
        }

        for existing in existingPayloads(
            on: payload.wallID,
            in: room
        ) where overlaps(payload, existing) {
            throw DomainError.invariantViolation(
                "\(payload.displayName) koliduje z elementem \(existing.displayName)."
            )
        }

        for assembly in assemblies {
            guard let placement = assembly.placement,
                  placement.wallID == payload.wallID else {
                continue
            }

            let horizontal = overlaps(
                rect.x,
                rect.width,
                placement.offsetAlongWall,
                assembly.size.width
            )
            let vertical = overlaps(
                rect.y,
                rect.height,
                placement.bottomOffset,
                assembly.size.height
            )

            if horizontal, vertical {
                if case .bayProjection(let bay) = payload,
                   bay.direction == .outward {
                    continue
                }

                throw DomainError.invariantViolation(
                    "\(payload.displayName) koliduje z meblem \(assembly.name)."
                )
            }
        }
    }

    static func validateDraft(
        _ payload: WallFeaturePayloadV016,
        wallLength: Millimeters,
        wallHeight: Millimeters,
        existing: [WallFeaturePayloadV016]
    ) throws {
        let rect = payload.localRect
        guard rect.x >= .zero,
              rect.y >= .zero,
              rect.x + rect.width <= wallLength + 0.1,
              rect.y + rect.height <= wallHeight + 0.1 else {
            throw DomainError.invariantViolation(
                "Element nie mieści się na mierzonej ścianie."
            )
        }

        if let conflict = existing.first(where: {
            $0.wallID == payload.wallID
                && overlaps(payload, $0)
        }) {
            throw DomainError.invariantViolation(
                "\(payload.displayName) koliduje z elementem \(conflict.displayName)."
            )
        }
    }

    private static func existingPayloads(
        on wallID: WallID,
        in room: RoomDefinition
    ) -> [WallFeaturePayloadV016] {
        room.windows.compactMap {
            $0.placement.wallID == wallID ? .window($0) : nil
        }
        + room.doors.compactMap {
            $0.placement.wallID == wallID ? .door($0) : nil
        }
        + room.recesses.compactMap {
            $0.wallID == wallID ? .recess($0) : nil
        }
        + room.bayProjections.compactMap {
            $0.wallID == wallID ? .bayProjection($0) : nil
        }
    }

    private static func overlaps(
        _ lhs: WallFeaturePayloadV016,
        _ rhs: WallFeaturePayloadV016
    ) -> Bool {
        let a = lhs.localRect
        let b = rhs.localRect
        return overlaps(a.x, a.width, b.x, b.width)
            && overlaps(a.y, a.height, b.y, b.height)
    }

    private static func overlaps(
        _ aStart: Millimeters,
        _ aLength: Millimeters,
        _ bStart: Millimeters,
        _ bLength: Millimeters
    ) -> Bool {
        let start = max(aStart.rawValue, bStart.rawValue)
        let end = min(
            (aStart + aLength).rawValue,
            (bStart + bLength).rawValue
        )
        return end - start > 0.1
    }
}

struct WallFeatureEditorV016: View {
    @Environment(\.dismiss) private var dismiss

    let context: WallFeatureEditorContextV016
    let onSave: (WallFeaturePayloadV016) async -> Bool

    @State private var kind: WallFeatureKindV016
    @State private var referenceEdge: WallFeatureReferenceEdgeV016 = .right
    @State private var name: String
    @State private var distanceText = "0"
    @State private var widthText: String
    @State private var heightText: String
    @State private var bottomText: String
    @State private var depthText: String
    @State private var hingeSide: HingeSide = .right
    @State private var openingDirection: OpeningDirection = .inward
    @State private var windowType: WindowOpeningType = .tiltAndTurn
    @State private var bayDirection: BayProjectionDirectionV016 = .outward
    @State private var notes = ""
    @State private var validationMessage: String?
    @State private var isSaving = false

    init(
        context: WallFeatureEditorContextV016,
        onSave: @escaping (WallFeaturePayloadV016) async -> Bool
    ) {
        self.context = context
        self.onSave = onSave
        _kind = State(initialValue: context.defaultKind)
        _name = State(initialValue: context.defaultKind.title)

        let defaults = Self.defaults(
            kind: context.defaultKind,
            wallHeight: context.wallHeight
        )
        _widthText = State(initialValue: defaults.width)
        _heightText = State(initialValue: defaults.height)
        _bottomText = State(initialValue: defaults.bottom)
        _depthText = State(initialValue: defaults.depth)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Rodzaj") {
                    Picker("Element", selection: $kind) {
                        ForEach(WallFeatureKindV016.allCases) {
                            Label($0.title, systemImage: $0.systemImage)
                                .tag($0)
                        }
                    }

                    TextField("Nazwa", text: $name)
                }

                Section("Położenie na \(context.wallName)") {
                    Picker("Pomiar", selection: $referenceEdge) {
                        ForEach(WallFeatureReferenceEdgeV016.allCases) {
                            Text($0.title).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)

                    PolePomiaroweMM(
                        referenceEdge == .right
                            ? "Od prawej krawędzi"
                            : "Od lewej krawędzi",
                        text: $distanceText
                    )
                    PolePomiaroweMM("Szerokość", text: $widthText)
                    PolePomiaroweMM("Wysokość", text: $heightText)
                    PolePomiaroweMM("Od podłogi", text: $bottomText)
                    PolePomiaroweMM(
                        kind == .window || kind == .door
                            ? "Głębokość ościeża"
                            : "Głębokość",
                        text: $depthText
                    )

                    LabeledContent(
                        "Długość ściany",
                        value: formatted(context.wallLength)
                    )
                }

                if kind == .window {
                    Section("Okno") {
                        Picker("Typ", selection: $windowType) {
                            ForEach(WindowOpeningType.allCases, id: \.self) {
                                Text(windowTypeTitle($0)).tag($0)
                            }
                        }
                    }
                }

                if kind == .window || kind == .door {
                    Section("Otwieranie") {
                        Picker("Zawiasy", selection: $hingeSide) {
                            ForEach(HingeSide.allCases, id: \.self) {
                                Text(hingeTitle($0)).tag($0)
                            }
                        }
                        Picker("Kierunek", selection: $openingDirection) {
                            ForEach(OpeningDirection.allCases, id: \.self) {
                                Text(directionTitle($0)).tag($0)
                            }
                        }
                    }
                }

                if kind == .bayProjection {
                    Section("Wykusz / uskok") {
                        Picker("Kierunek", selection: $bayDirection) {
                            Text("Na zewnątrz")
                                .tag(BayProjectionDirectionV016.outward)
                            Text("Do wnętrza")
                                .tag(BayProjectionDirectionV016.inward)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("Uwagi") {
                    TextField(
                        "Notatki",
                        text: $notes,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                }

                if let validationMessage {
                    Section {
                        Label(
                            validationMessage,
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Dodaj element ściany")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Dodaj")
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .onChange(of: kind) {
                applyDefaults()
            }
        }
    }

    private func save() {
        validationMessage = nil

        do {
            let payload = try makePayload()
            isSaving = true

            Task {
                let saved = await onSave(payload)
                await MainActor.run {
                    isSaving = false
                    if saved {
                        dismiss()
                    }
                }
            }
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    private func makePayload() throws -> WallFeaturePayloadV016 {
        guard let distance = nonNegative(distanceText),
              let width = positive(widthText),
              let height = positive(heightText),
              let bottom = nonNegative(bottomText),
              let depth = nonNegative(depthText) else {
            throw DomainError.invariantViolation(
                "Podaj prawidłowe wymiary elementu."
            )
        }

        let x: Millimeters
        switch referenceEdge {
        case .left:
            x = distance
        case .right:
            x = context.wallLength - distance - width
        }

        guard x >= .zero,
              x + width <= context.wallLength else {
            throw DomainError.invariantViolation(
                "Element nie mieści się w długości ściany."
            )
        }

        guard bottom + height <= context.wallHeight else {
            throw DomainError.invariantViolation(
                "Element nie mieści się w wysokości ściany."
            )
        }

        switch kind {
        case .window:
            let placement = try WallOpeningPlacement(
                wallID: context.wallID,
                offsetFromWallStart: x,
                bottomOffset: bottom,
                width: width,
                height: height,
                revealDepth: depth
            )
            return .window(
                try WindowDefinition(
                    placement: placement,
                    openingType: windowType,
                    hingeSide: hingeSide,
                    openingDirection: openingDirection,
                    notes: notes
                )
            )

        case .door:
            let placement = try WallOpeningPlacement(
                wallID: context.wallID,
                offsetFromWallStart: x,
                bottomOffset: bottom,
                width: width,
                height: height,
                revealDepth: depth
            )
            return .door(
                try DoorDefinition(
                    placement: placement,
                    hingeSide: hingeSide,
                    openingDirection: openingDirection,
                    notes: notes
                )
            )

        case .recess:
            return .recess(
                try RecessDefinition(
                    wallID: context.wallID,
                    name: resolvedName,
                    openingContour: try Self.rectangleContour(
                        x: x,
                        y: bottom,
                        width: width,
                        height: height
                    ),
                    depth: max(depth, 1),
                    notes: notes
                )
            )

        case .bayProjection:
            return .bayProjection(
                try BayProjectionDefinitionV016(
                    wallID: context.wallID,
                    name: resolvedName,
                    offsetFromWallStart: x,
                    bottomOffset: bottom,
                    width: width,
                    height: height,
                    depth: max(depth, 1),
                    direction: bayDirection,
                    notes: notes
                )
            )
        }
    }

    private var resolvedName: String {
        let trimmed = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return trimmed.isEmpty ? kind.title : trimmed
    }

    private func applyDefaults() {
        name = kind.title
        let values = Self.defaults(
            kind: kind,
            wallHeight: context.wallHeight
        )
        widthText = values.width
        heightText = values.height
        bottomText = values.bottom
        depthText = values.depth
    }

    private static func defaults(
        kind: WallFeatureKindV016,
        wallHeight: Millimeters
    ) -> (
        width: String,
        height: String,
        bottom: String,
        depth: String
    ) {
        switch kind {
        case .window:
            return ("1200", "1200", "850", "120")
        case .door:
            return ("900", "2100", "0", "120")
        case .recess:
            return ("600", "2000", "0", "300")
        case .bayProjection:
            return (
                "1200",
                wallHeight.rawValue.formatted(
                    .number.grouping(.never)
                ),
                "0",
                "300"
            )
        }
    }

    private static func rectangleContour(
        x: Millimeters,
        y: Millimeters,
        width: Millimeters,
        height: Millimeters
    ) throws -> ClosedContour2D {
        let p0 = Point2MM(x: x, y: y)
        let p1 = Point2MM(x: x + width, y: y)
        let p2 = Point2MM(x: x + width, y: y + height)
        let p3 = Point2MM(x: x, y: y + height)

        return try ClosedContour2D(
            segments: [
                .line(try LineSegment2D(start: p0, end: p1)),
                .line(try LineSegment2D(start: p1, end: p2)),
                .line(try LineSegment2D(start: p2, end: p3)),
                .line(try LineSegment2D(start: p3, end: p0))
            ]
        )
    }

    private func positive(
        _ text: String
    ) -> Millimeters? {
        guard let value = number(text), value > 0 else {
            return nil
        }
        return Millimeters(value)
    }

    private func nonNegative(
        _ text: String
    ) -> Millimeters? {
        guard let value = number(text), value >= 0 else {
            return nil
        }
        return Millimeters(value)
    }

    private func number(
        _ text: String
    ) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: ",", with: ".")

        guard let value = Double(normalized),
              value.isFinite else {
            return nil
        }
        return value
    }

    private func formatted(
        _ value: Millimeters
    ) -> String {
        let number = value.rawValue.formatted(
            .number
                .grouping(.never)
                .precision(.fractionLength(0...1))
        )
        return "\(number) mm"
    }

    private func hingeTitle(_ value: HingeSide) -> String {
        switch value {
        case .left: return "Lewe"
        case .right: return "Prawe"
        case .none: return "Brak"
        }
    }

    private func directionTitle(_ value: OpeningDirection) -> String {
        switch value {
        case .inward: return "Do wnętrza"
        case .outward: return "Na zewnątrz"
        case .sliding: return "Przesuwne"
        case .none: return "Brak"
        }
    }

    private func windowTypeTitle(_ value: WindowOpeningType) -> String {
        switch value {
        case .fixed: return "Stałe"
        case .tilt: return "Uchylne"
        case .turn: return "Rozwierne"
        case .tiltAndTurn: return "Uchylno-rozwierne"
        case .sliding: return "Przesuwne"
        case .custom: return "Inne"
        }
    }
}
