import DomainCore
import SwiftUI

struct ProwadzonyPomiarPomieszczeniaView: View {
    @Environment(\.dismiss) private var dismiss

    let projectID: ProjectID
    let roomID: RoomID?
    let onSave: (RoomDefinition) async -> Bool

    init(
        projectID: ProjectID,
        roomID: RoomID? = nil,
        onSave: @escaping (RoomDefinition) async -> Bool
    ) {
        self.projectID = projectID
        self.roomID = roomID
        self.onSave = onSave
    }

    @State private var roomName = ""
    @State private var wallHeightText = "2600"
    @State private var wallThicknessText = "120"
    @State private var constructionType: ConstructionType = .unknown
    @State private var session: RoomSurveySession?
    @State private var lengthText = ""
    @State private var selectedTurn: SurveyTurnChoice = .right90
    @State private var customAngleText = "0"
    @State private var validationMessage: String?
    @State private var isSaving = false
    @State private var wallFeatureDrafts:
        [WallFeaturePayloadV016] = []
    @State private var isPresentingWallFeatureEditor = false

    var body: some View {
        NavigationStack {
            Group {
                if let session {
                    surveyWorkspace(session: session)
                } else {
                    startForm
                }
            }
            .navigationTitle("Pomiar po obrysie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                        .disabled(isSaving)
                }
            }
        }
        .sheet(isPresented: $isPresentingWallFeatureEditor) {
            if let wallFeatureEditorContext {
                WallFeatureEditorV016(
                    context: wallFeatureEditorContext,
                    onSave: addWallFeatureDraft
                )
            }
        }
    }

    private var startForm: some View {
        Form {
            Section("Punkt rozpoczęcia") {
                Label(
                    "Stań w wejściu, patrząc do pomieszczenia. Zacznij od ściany po prawej stronie i prowadź obrys zgodnie z ruchem wskazówek zegara.",
                    systemImage: "arrow.turn.down.right"
                )
                .font(.callout)
            }

            Section("Pomieszczenie") {
                TextField("Nazwa, np. Kuchnia", text: $roomName)
                PolePomiaroweMM("Wysokość ścian", text: $wallHeightText)
                PolePomiaroweMM("Grubość ścian", text: $wallThicknessText)
                Picker("Konstrukcja", selection: $constructionType) {
                    ForEach(ConstructionType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
            }

            if let validationMessage {
                Section {
                    Label(validationMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Rozpocznij pomiar") { beginSurvey() }
                    .buttonStyle(
                        StolarniaPrimaryButtonStyle(
                            minHeight: 44,
                            horizontalPadding: 14,
                            cornerRadius: 12
                        )
                    )
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func surveyWorkspace(session current: RoomSurveySession) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                surveyPreview(session: current)
                    .frame(minWidth: 430, maxWidth: .infinity)

                Divider()

                measurementPanel(session: current)
                    .frame(width: 440)
            }

            VStack(spacing: 0) {
                surveyPreview(session: current)
                    .frame(maxHeight: .infinity)

                Divider()

                measurementPanel(session: current)
                    .frame(height: 430)
            }
        }
        .background(StolarniaPalette.canvas)
    }

    private func surveyPreview(session current: RoomSurveySession) -> some View {
        VStack(spacing: 14) {
            surveyStatusBar(session: current)

            RoomSurveyCanvasView(
                session: current,
                wallFeatures: wallFeatureDrafts
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private func surveyStatusBar(session current: RoomSurveySession) -> some View {
        HStack(spacing: 12) {
            metricTile(
                title: "Ściana",
                value: "\(current.measuredSegments.count + 1)",
                systemImage: "ruler"
            )

            metricTile(
                title: "Kierunek",
                value: formattedHeading(current.currentHeadingDegrees),
                systemImage: "location.north.line"
            )

            metricTile(
                title: "Do P0",
                value: formatted(current.closureDistance),
                systemImage: current.closureDistance.rawValue <= 2
                    ? "checkmark.seal"
                    : "point.topleft.down.to.point.bottomright.curvepath"
            )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private func measurementPanel(session current: RoomSurveySession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                activeWallCard(session: current)
                turnSelectorCard

                if let lastWall = current.measuredSegments.last {
                    wallFeaturesCard(lastWall: lastWall)
                }

                measuredSegmentsCard(session: current)
                closureCard(session: current)

                if let validationMessage {
                    Label(validationMessage, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .stolarniaFrostedCard(cornerRadius: 16, padding: 14)
                }
            }
            .padding(16)
        }
        .background(.ultraThinMaterial)
    }

    private func activeWallCard(session current: RoomSurveySession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    "Aktywna ściana \(current.measuredSegments.count + 1)",
                    systemImage: "ruler"
                )
                .font(.headline)

                Spacer()

                Text(formattedHeading(current.currentHeadingDegrees))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(StolarniaPalette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(StolarniaPalette.accent.opacity(0.16))
                    )
            }

            PolePomiaroweMM(
                "Długość ściany",
                text: $lengthText,
                helpText: "Wpisz długość z dalmierza lub miarki. Zapis tworzy kolejny odcinek obrysu."
            )

            Button {
                appendSegment()
            } label: {
                Label("Zapisz odcinek", systemImage: "plus.line.diagonal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(
                StolarniaPrimaryButtonStyle(
                    minHeight: 46,
                    horizontalPadding: 14,
                    cornerRadius: 12
                )
            )
        }
        .stolarniaFrostedCard(cornerRadius: 18, padding: 14)
    }

    private var turnSelectorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Skręt po zapisaniu ściany")
                .font(.headline)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(SurveyTurnChoice.allCases) { turn in
                    Button {
                        selectedTurn = turn
                    } label: {
                        Label(turn.title, systemImage: turn.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(
                        selectedTurn == turn
                            ? StolarniaPalette.drawingInk
                            : StolarniaPalette.sidebarPrimary
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                selectedTurn == turn
                                    ? StolarniaPalette.accent
                                    : Color.white.opacity(0.08)
                            )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                selectedTurn == turn
                                    ? StolarniaPalette.accentStrong
                                    : StolarniaPalette.frostStroke,
                                lineWidth: 1
                            )
                    }
                }
            }

            if selectedTurn == .custom {
                TextField("Kąt skrętu w stopniach, np. -37 albo 22.5", text: $customAngleText)
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .stolarniaFrostedCard(cornerRadius: 18, padding: 14)
    }

    private func wallFeaturesCard(lastWall: MeasuredWallSegment) -> some View {
        let drafts = wallFeatureDrafts.filter {
            $0.wallID == lastWall.wallID
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Elementy \(lastWall.name)")
                    .font(.headline)

                Spacer()

                Button {
                    isPresentingWallFeatureEditor = true
                } label: {
                    Label("Dodaj", systemImage: "plus.rectangle.on.rectangle")
                }
                .buttonStyle(.bordered)
            }

            if drafts.isEmpty {
                Text("Brak okien, drzwi, wnęk i wykuszy na ostatnim odcinku.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(drafts.enumerated()), id: \.offset) { _, draft in
                    HStack(spacing: 10) {
                        Label(draft.displayName, systemImage: draft.kind.systemImage)
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Text(wallFeatureDescription(draft))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Button(role: .destructive) {
                            removeWallFeatureDraft(draft)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .stolarniaFrostedCard(cornerRadius: 18, padding: 14)
    }

    private func measuredSegmentsCard(session current: RoomSurveySession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Zmierzone odcinki")
                    .font(.headline)

                Spacer()

                Text("\(current.measuredSegments.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if current.measuredSegments.isEmpty {
                Text("Po zapisaniu pierwszej ściany pojawi się tu historia obrysu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(
                        Array(current.measuredSegments.enumerated()),
                        id: \.element.id
                    ) { index, segment in
                        measuredSegmentRow(
                            segment,
                            index: index
                        )
                    }
                }
            }
        }
        .stolarniaFrostedCard(cornerRadius: 18, padding: 14)
    }

    private func measuredSegmentRow(
        _ segment: MeasuredWallSegment,
        index: Int
    ) -> some View {
        let featureCount = wallFeatureDrafts.filter {
            $0.wallID == segment.wallID
        }.count

        return HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(StolarniaPalette.drawingInk)
                .frame(width: 28, height: 28)
                .background(Circle().fill(StolarniaPalette.accent))

            VStack(alignment: .leading, spacing: 2) {
                Text(segment.name)
                    .font(.subheadline.weight(.semibold))

                Text(formattedHeading(segment.headingDegrees))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatted(segment.measuredLength))
                    .font(.subheadline.monospacedDigit().weight(.semibold))

                Text(featureCount == 1 ? "1 element" : "\(featureCount) elementów")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
    }

    private func closureCard(session current: RoomSurveySession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kontrola obrysu")
                .font(.headline)

            HStack(spacing: 10) {
                metricTile(
                    title: "Ściany",
                    value: "\(current.measuredSegments.count)",
                    systemImage: "line.3.horizontal"
                )

                metricTile(
                    title: "Do P0",
                    value: formatted(current.closureDistance),
                    systemImage: "scope"
                )
            }

            Text(closureStatusText(current))
                .font(.caption)
                .foregroundStyle(
                    current.closureDistance.rawValue <= 2
                        ? Color.secondary
                        : Color.orange
                )
                .fixedSize(horizontal: false, vertical: true)

            if current.measuredSegments.count >= 2,
               current.closureDistance.rawValue > 2 {
                Button {
                    appendClosingSegment()
                } label: {
                    Label(
                        "Dodaj ostatnią ścianę do P0",
                        systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if !current.measuredSegments.isEmpty {
                Button(role: .destructive) {
                    undoLastSegment(current)
                } label: {
                    Label("Cofnij ostatni odcinek", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
            }

            Button {
                completeAndSave()
            } label: {
                if isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Zamknij obrys i zapisz", systemImage: "checkmark.seal")
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(current.measuredSegments.count < 2 || isSaving)
            .buttonStyle(
                StolarniaPrimaryButtonStyle(
                    minHeight: 48,
                    horizontalPadding: 14,
                    cornerRadius: 12
                )
            )
        }
        .stolarniaFrostedCard(cornerRadius: 18, padding: 14)
    }

    private func metricTile(
        title: String,
        value: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(StolarniaPalette.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(StolarniaPalette.sidebarPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(StolarniaPalette.frostStroke, lineWidth: 1)
        }
    }

    private func beginSurvey() {
        validationMessage = nil
        guard let height = parsedPositive(wallHeightText),
              let thickness = parsedPositive(wallThicknessText) else {
            validationMessage = "Podaj prawidłową wysokość i grubość ścian."
            return
        }

        do {
            session = try RoomSurveySession(
                projectID: projectID,
                roomName: roomName,
                winding: .clockwiseFromEntranceRight,
                wallHeight: Millimeters(height),
                wallThickness: Millimeters(thickness),
                constructionType: constructionType
            )
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    private func appendSegment() {
        validationMessage = nil
        guard var current = session,
              let length = parsedPositive(lengthText) else {
            validationMessage = "Podaj prawidłową długość ściany."
            return
        }

        do {
            try current.appendSegment(
                length: Millimeters(length),
                turnAfterSegment: selectedTurn.domainTurn(customText: customAngleText)
            )
            session = current
            lengthText = ""
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    private func appendClosingSegment() {
        validationMessage = nil
        guard var current = session else {
            return
        }

        do {
            try current.appendClosingSegment()
            session = current
            lengthText = ""
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    private func undoLastSegment(_ current: RoomSurveySession) {
        var updated = current
        if let removedWallID = updated.measuredSegments.last?.wallID {
            wallFeatureDrafts.removeAll {
                $0.wallID == removedWallID
            }
        }
        updated.removeLastSegment()
        session = updated
    }

    private func completeAndSave() {
        guard var current = session else { return }
        isSaving = true
        validationMessage = nil

        Task {
            do {
                var room = try current.completeRoom(
                    id: roomID ?? RoomID()
                )
                for feature in wallFeatureDrafts {
                    try applyWallFeatureV016(
                        feature,
                        to: &room
                    )
                }
                let saved = await onSave(room)
                await MainActor.run {
                    isSaving = false
                    if saved { dismiss() }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    validationMessage = error.localizedDescription
                }
            }
        }
    }

    private var wallFeatureEditorContext:
        WallFeatureEditorContextV016? {
        guard let current = session,
              let lastWall = current.measuredSegments.last else {
            return nil
        }

        return WallFeatureEditorContextV016(
            wallID: lastWall.wallID,
            wallName: lastWall.name,
            wallLength: lastWall.measuredLength,
            wallHeight: current.wallHeight
        )
    }

    private func addWallFeatureDraft(
        _ payload: WallFeaturePayloadV016
    ) async -> Bool {
        guard let current = session,
              let wall = current.measuredSegments.last,
              payload.wallID == wall.wallID else {
            validationMessage =
                "Najpierw zapisz ścianę, do której chcesz dodać element."
            return false
        }

        do {
            try WallFeatureValidatorV016.validateDraft(
                payload,
                wallLength: wall.measuredLength,
                wallHeight: current.wallHeight,
                existing: wallFeatureDrafts
            )
            wallFeatureDrafts.append(payload)
            return true
        } catch {
            validationMessage = error.localizedDescription
            return false
        }
    }

    private func removeWallFeatureDraft(
        _ payload: WallFeaturePayloadV016
    ) {
        wallFeatureDrafts.removeAll {
            $0 == payload
        }
    }

    private func wallFeatureDescription(
        _ payload: WallFeaturePayloadV016
    ) -> String {
        let rect = payload.localRect
        return "x \(formatted(rect.x)), "
            + "\(formatted(rect.width)) × "
            + formatted(rect.height)
    }

    private func parsedPositive(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite, value > 0 else { return nil }
        return value
    }

    private func formatted(_ value: Millimeters) -> String {
        "\(value.rawValue.formatted(.number.precision(.fractionLength(0...1)))) mm"
    }

    private func formattedHeading(_ degrees: Double) -> String {
        "\(degrees.formatted(.number.precision(.fractionLength(0...1))))°"
    }

    private func closureStatusText(
        _ current: RoomSurveySession
    ) -> String {
        if current.measuredSegments.count < 2 {
            return "Dodaj minimum dwa odcinki, aby móc kontrolować domknięcie obrysu."
        }
        if current.closureDistance.rawValue <= 2 {
            return "Obrys domyka się w tolerancji. Przy zapisie ostatni punkt zostanie dociągnięty do P0."
        }
        return "Możesz dopisać ostatni odcinek do P0 jako normalną ścianę albo pozwolić aplikacji dodać go automatycznie przy zapisie."
    }
}

private enum SurveyTurnChoice: String, CaseIterable, Identifiable {
    case right90
    case left90
    case straight
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .right90: "90° w prawo"
        case .left90: "90° w lewo"
        case .straight: "prosto"
        case .custom: "kąt własny"
        }
    }

    var systemImage: String {
        switch self {
        case .right90:
            return "arrow.turn.down.right"
        case .left90:
            return "arrow.turn.down.left"
        case .straight:
            return "arrow.up"
        case .custom:
            return "angle"
        }
    }

    func domainTurn(customText: String) -> SurveyTurn {
        switch self {
        case .right90:
            return SurveyTurn.right90

        case .left90:
            return SurveyTurn.left90

        case .straight:
            return SurveyTurn.straight

        case .custom:
            let normalized = customText.replacingOccurrences(of: ",", with: ".")
            return SurveyTurn.custom(degrees: Double(normalized) ?? 0)
        }
    }
}
