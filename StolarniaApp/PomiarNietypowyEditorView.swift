import SwiftUI

struct PomiarNietypowyEditorView:
    View
{
    let type:
        TypPomiaruNietypowego

    @StateObject private var repository =
        PomiaryNietypoweRepository()

    @State private var draft:
        PomiarNietypowy

    @State private var didSave = false

    init(
        type:
            TypPomiaruNietypowego,
        context:
            KontekstPomiaruPomieszczenia?
            = nil,
        existingMeasurement:
            PomiarNietypowy?
            = nil
    ) {
        self.type = type

        var measurement =
            existingMeasurement
            ?? PomiarNietypowy()

        measurement.typ = type

        if existingMeasurement == nil {
            measurement.nazwa =
                type.nazwa
        }

        if let context {
            measurement.projectID =
                context.projectID
            measurement.roomID =
                context.roomID
            measurement.projectName =
                context.projectName
            measurement.roomName =
                context.roomName
            measurement.klient =
                context.customerName
            measurement.pomieszczenie =
                context.roomName
        }

        _draft = State(
            initialValue:
                measurement
        )
    }

    var body: some View {
        Form {
            Section {
                StolarniaSectionIntro(
                    title: type.nazwa,
                    description:
                        type.shortEditorDescription,
                    systemImage:
                        type.systemImage
                )
                .listRowInsets(
                    EdgeInsets()
                )
                .listRowBackground(
                    Color.clear
                )
            }

            basicSection
            dimensionsSection
            pointsSection
            requirementsSection
            checklistSection
            notesSection
        }
        .navigationTitle(type.nazwa)
        .stolarniaScreenSurface(
            .detail
        )
        .stolarniaReadableInterface()
        .toolbar {
            ToolbarItem(
                placement:
                    .primaryAction
            ) {
                Button {
                    save()
                } label: {
                    Label(
                        didSave
                        ? "Zapisano"
                        : "Zapisz pomiar",
                        systemImage:
                            didSave
                            ? "checkmark.circle.fill"
                            : "square.and.arrow.down"
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )
                .accessibilityHint(
                    "Zapisuje formularz na tym urządzeniu."
                )
            }
        }
    }

    private var basicSection:
        some View
    {
        Section("Dane pomiaru") {
            TextField(
                "Nazwa pomiaru",
                text: $draft.nazwa
            )

            TextField(
                "Klient",
                text: $draft.klient
            )

            TextField(
                "Pomieszczenie",
                text:
                    $draft.pomieszczenie
            )

            DatePicker(
                "Data pomiaru",
                selection:
                    $draft.dataPomiaru,
                displayedComponents:
                    .date
            )
        }
    }

    private var dimensionsSection:
        some View
    {
        Section("Wymiary bazowe") {
            dimension(
                "Szerokość",
                value:
                    $draft.szerokoscMM
            )

            dimension(
                "Wysokość",
                value:
                    $draft.wysokoscMM
            )

            dimension(
                "Głębokość",
                value:
                    $draft.glebokoscMM
            )

            number(
                "Kąt",
                value:
                    $draft.katStopnie,
                suffix: "°"
            )

            if type == .scianaLukowa {
                dimension(
                    "Promień",
                    value:
                        $draft.promienMM
                )

                dimension(
                    "Strzałka łuku",
                    value:
                        $draft.strzalkaLukuMM
                )
            }
        }
    }

    private var pointsSection:
        some View
    {
        Section("Punkty pomiarowe") {
            if draft.punkty.isEmpty {
                Text(
                    "Dodaj punkty w kolejności pomiaru. Dla skosów i łuków zapisuj je co 200–500 mm."
                )
                .foregroundStyle(
                    .secondary
                )
            }

            ForEach(
                $draft.punkty
            ) { $point in
                VStack(
                    alignment: .leading,
                    spacing: 10
                ) {
                    Text(point.opis)
                        .font(.headline)

                    dimension(
                        "X — od lewej",
                        value:
                            $point.xMM
                    )

                    dimension(
                        "Y — wysokość",
                        value:
                            $point.yMM
                    )

                    dimension(
                        "Z — głębokość",
                        value:
                            $point.zMM
                    )

                    TextField(
                        "Opis punktu",
                        text:
                            $point.opis
                    )
                }
                .padding(.vertical, 4)
            }
            .onDelete {
                draft.punkty.remove(
                    atOffsets: $0
                )
            }

            Button {
                addPoint()
            } label: {
                Label(
                    "Dodaj punkt pomiarowy",
                    systemImage:
                        "plus.circle.fill"
                )
            }
            .buttonStyle(
                StolarniaPrimaryButtonStyle()
            )
        }
    }

    private var requirementsSection:
        some View
    {
        Section("Bezpieczeństwo i montaż") {
            Toggle(
                "Strefa bez wiercenia",
                isOn:
                    $draft
                        .strefaBezWiercenia
            )

            Toggle(
                "Wymagany dostęp serwisowy",
                isOn:
                    $draft
                        .wymaganyDostepSerwisowy
            )

            Toggle(
                "Wymagana wentylacja",
                isOn:
                    $draft
                        .wymaganaWentylacja
            )

            dimension(
                "Rezerwa montażowa",
                value:
                    $draft
                        .wymaganaRezerwaMontazowaMM
            )
        }
    }

    private var checklistSection:
        some View
    {
        Section("Sprawdź przed wyjściem") {
            ForEach(
                type.wskazowki,
                id: \.self
            ) { item in
                Label(
                    item,
                    systemImage:
                        "checkmark.circle"
                )
                .font(.body)
            }
        }
    }

    private var notesSection:
        some View
    {
        Section("Notatki i ustalenia") {
            TextEditor(
                text:
                    $draft.notatki
            )
            .frame(minHeight: 150)
        }
    }

    private func save() {
        repository.upsert(draft)
        didSave = true
    }

    private func addPoint() {
        draft.punkty.append(
            PunktPomiaruNietypowego(
                xMM: 0,
                yMM: 0,
                zMM: 0,
                opis:
                    "Punkt \(draft.punkty.count + 1)"
            )
        )
    }

    private func dimension(
        _ title: String,
        value:
            Binding<Double>
    ) -> some View {
        number(
            title,
            value: value,
            suffix: "mm"
        )
    }

    private func number(
        _ title: String,
        value:
            Binding<Double>,
        suffix: String
    ) -> some View {
        HStack {
            Text(title)
            Spacer()

            TextField(
                title,
                value: value,
                format:
                    .number
                    .grouping(.never)
                    .precision(
                        .fractionLength(
                            0...1
                        )
                    )
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(
                .trailing
            )
            .frame(minWidth: 110)

            Text(suffix)
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    width: 34,
                    alignment: .leading
                )
        }
        .frame(minHeight: 44)
    }
}

struct ListaPomiarowNietypowychView:
    View
{
    @StateObject private var repository =
        PomiaryNietypoweRepository()

    var body: some View {
        Group {
            if repository.pomiary.isEmpty {
                ContentUnavailableView(
                    "Brak zapisanych pomiarów",
                    systemImage:
                        "tray",
                    description: Text(
                        "Wybierz typ pomiaru w środkowym panelu i zapisz pierwszy formularz."
                    )
                )
            } else {
                List {
                    Section(
                        "Zapisane pomiary"
                    ) {
                        ForEach(
                            repository.pomiary
                        ) { measurement in
                            VStack(
                                alignment:
                                    .leading,
                                spacing: 6
                            ) {
                                Label(
                                    measurement.nazwa,
                                    systemImage:
                                        measurement.typ
                                            .systemImage
                                )
                                .font(.headline)

                                Text(
                                    savedSubtitle(
                                        measurement
                                    )
                                )
                                .font(.subheadline)
                                .foregroundStyle(
                                    .secondary
                                )
                            }
                            .padding(.vertical, 6)
                        }
                        .onDelete {
                            delete(
                                at: $0
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle(
            "Zapisane pomiary"
        )
        .stolarniaScreenSurface(
            .detail
        )
        .stolarniaReadableInterface()
    }

    private func savedSubtitle(
        _ measurement:
            PomiarNietypowy
    ) -> String {
        let room =
            measurement.pomieszczenie
                .isEmpty
            ? "Bez pomieszczenia"
            : measurement.pomieszczenie

        return "\(measurement.typ.nazwa) • \(room)"
    }

    private func delete(
        at offsets:
            IndexSet
    ) {
        for index in offsets {
            repository.delete(
                id:
                    repository
                        .pomiary[index]
                        .id
            )
        }
    }
}

private extension TypPomiaruNietypowego {
    var shortEditorDescription:
        String
    {
        switch self {
        case .wneka:
            return "Zmierz szerokość, wysokość i głębokość w kilku miejscach."
        case .podSchodami:
            return "Zapisz profil schodów punkt po punkcie i zaznacz konstrukcję."
        case .scianaLukowa:
            return "Zapisz promień, strzałkę łuku oraz serię punktów kontrolnych."
        case .scianyNieprostopadle:
            return "Sprawdź kąty, przekątne i różnice szerokości przy froncie i ścianie."
        case .kominSlup:
            return "Zapisz pełny obrys oraz odległość od dwóch stałych ścian."
        case .wykusz:
            return "Zmierz każdy odcinek i kąt osobno."
        case .belkiSufitowe:
            return "Zapisz rozstaw, szerokość, wysokość i ewentualne odchylenia."
        case .pionInstalacyjny:
            return "Zaznacz obrys, rewizję i strefę bez wiercenia."
        case .nierownaPodloga:
            return "Zbuduj siatkę wysokości i znajdź najwyższy punkt."
        case .zabudowaWokolOkna:
            return "Uwzględnij parapet, klamkę, grzejnik i zakres otwierania."
        case .zabudowaWokolDrzwi:
            return "Uwzględnij ościeżnicę, opaski, klamkę i ruch skrzydła."
        case .skosWieloplaszczyznowy:
            return "Zapisz osobne płaszczyzny oraz linie ich załamania."
        }
    }
}
