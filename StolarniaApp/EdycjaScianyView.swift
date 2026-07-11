import DomainCore
import SwiftUI

struct EdycjaScianyView: View {
    @Environment(\.dismiss) private var dismiss

    let room: RoomDefinition
    let wall: WallSegment
    let isSaving: Bool
    let onSave: (WallMeasurementUpdate) async -> Bool

    @State private var name: String
    @State private var lengthText: String
    @State private var thicknessText: String
    @State private var startHeightText: String
    @State private var endHeightText: String
    @State private var constructionType: ConstructionType
    @State private var notes: String
    @State private var validationMessage: String?

    init(
        room: RoomDefinition,
        wall: WallSegment,
        isSaving: Bool,
        onSave: @escaping (WallMeasurementUpdate) async -> Bool
    ) {
        self.room = room
        self.wall = wall
        self.isSaving = isSaving
        self.onSave = onSave

        let length = room.geometry.geometry(of: wall.id)?.length ?? .zero
        _name = State(initialValue: wall.name)
        _lengthText = State(initialValue: Self.editableText(length.rawValue))
        _thicknessText = State(initialValue: Self.editableText(wall.thickness.rawValue))
        _startHeightText = State(initialValue: Self.editableText(wall.startHeight.rawValue))
        _endHeightText = State(initialValue: Self.editableText(wall.endHeight.rawValue))
        _constructionType = State(initialValue: wall.constructionType)
        _notes = State(initialValue: wall.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ściana") {
                    TextField("Nazwa ściany", text: $name)

                    PolePomiaroweMM(
                        "Długość",
                        text: $lengthText,
                        helpText: lengthHelpText
                    )

                    PolePomiaroweMM(
                        "Grubość",
                        text: $thicknessText
                    )

                    Picker("Konstrukcja", selection: $constructionType) {
                        ForEach(ConstructionType.allCases, id: \.self) { type in
                            Text(type.displayName)
                                .tag(type)
                        }
                    }
                }

                Section("Wysokości") {
                    PolePomiaroweMM(
                        "Wysokość na początku",
                        text: $startHeightText
                    )

                    PolePomiaroweMM(
                        "Wysokość na końcu",
                        text: $endHeightText,
                        helpText: "Różne wartości pozwalają zapisać spadek lub skos."
                    )
                }

                Section("Uwagi") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                Section("Stabilne identyfikatory") {
                    LabeledContent("WallID") {
                        Text(wall.id.description)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }

                    LabeledContent("ContourSegmentID") {
                        Text(wall.contourSegmentID.description)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Edytuj ścianę")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSaving)
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
                            Text("Zapisz")
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private var lengthHelpText: String {
        switch room.geometry.geometry(of: wall.id) {
        case .line:
            return "Zmiana przesuwa końcowy narożnik i może zmienić długość następnej ściany."
        case .arc:
            return "Dla łuku długość jest obecnie tylko do odczytu; edytor promienia i kąta dodamy osobno."
        case nil:
            return "Brak segmentu geometrycznego."
        }
    }

    private func save() {
        validationMessage = nil

        guard let length = parsedPositiveValue(lengthText) else {
            validationMessage = "Podaj prawidłową dodatnią długość ściany."
            return
        }

        guard let thickness = parsedPositiveValue(thicknessText) else {
            validationMessage = "Podaj prawidłową dodatnią grubość ściany."
            return
        }

        guard let startHeight = parsedPositiveValue(startHeightText),
              let endHeight = parsedPositiveValue(endHeightText) else {
            validationMessage = "Podaj prawidłowe dodatnie wysokości ściany."
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            validationMessage = "Nazwa ściany nie może być pusta."
            return
        }

        let update = WallMeasurementUpdate(
            wallID: wall.id,
            name: trimmedName,
            length: Millimeters(length),
            thickness: Millimeters(thickness),
            startHeight: Millimeters(startHeight),
            endHeight: Millimeters(endHeight),
            constructionType: constructionType,
            notes: notes
        )

        Task {
            let didSave = await onSave(update)
            if didSave {
                dismiss()
            }
        }
    }

    private func parsedPositiveValue(_ text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard let value = Double(normalized), value.isFinite, value > 0 else {
            return nil
        }

        return value
    }

    private static func editableText(_ value: Double) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: "pl_PL"))
                .grouping(.never)
                .precision(.fractionLength(0...2))
        )
    }
}
