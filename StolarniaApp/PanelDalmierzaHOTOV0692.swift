import SwiftUI

private enum CelPomiaruDalmierzaV0692:
    Hashable
{
    case szerokoscSciany
    case wysokoscMaksymalna
    case wysokoscSciankiKolankowej
    case glebokoscDocelowa
    case punktOdLewej(UUID)
    case punktWysokosc(UUID)
}

private struct OpcjaCeluDalmierzaV0692:
    Identifiable,
    Hashable
{
    let id: String
    let title: String
    let target: CelPomiaruDalmierzaV0692
}

struct PanelDalmierzaHOTOV0692:
    View
{
    @Binding var draft:
        PomiarGarderobySkosy

    @Environment(\.dismiss)
    private var dismiss

    @StateObject private var adapter =
        UniwersalnyAdapterDalmierzaBLEV0692()

    @State private var selectedTarget:
        CelPomiaruDalmierzaV0692 =
            .wysokoscMaksymalna

    @State private var showingDiagnostics =
        false

    @State private var confirmationMessage:
        String?

    private var targetOptions:
        [OpcjaCeluDalmierzaV0692]
    {
        var result: [OpcjaCeluDalmierzaV0692] = [
            OpcjaCeluDalmierzaV0692(
                id: "wall.width",
                title: "Szerokość ściany",
                target: .szerokoscSciany
            ),
            OpcjaCeluDalmierzaV0692(
                id: "wall.maxHeight",
                title: "Wysokość maksymalna",
                target: .wysokoscMaksymalna
            ),
            OpcjaCeluDalmierzaV0692(
                id: "wall.kneeHeight",
                title: "Wysokość ścianki kolankowej",
                target: .wysokoscSciankiKolankowej
            ),
            OpcjaCeluDalmierzaV0692(
                id: "wall.depth",
                title: "Głębokość docelowa",
                target: .glebokoscDocelowa
            )
        ]

        let sortedPoints =
            draft
                .punktySkosu
                .sorted {
                    $0.odlegloscOdLewejMM
                    < $1.odlegloscOdLewejMM
                }

        for (index, point) in
            sortedPoints.enumerated() {
            result.append(
                OpcjaCeluDalmierzaV0692(
                    id:
                        "point.\(point.id.uuidString).x",
                    title:
                        "Punkt \(index + 1) — odległość od lewej",
                    target:
                        .punktOdLewej(point.id)
                )
            )

            result.append(
                OpcjaCeluDalmierzaV0692(
                    id:
                        "point.\(point.id.uuidString).height",
                    title:
                        "Punkt \(index + 1) — wysokość",
                    target:
                        .punktWysokosc(point.id)
                )
            )
        }

        return result
    }

    var body: some View {
        NavigationStack {
            Form {
                statusSection
                devicesSection
                decoderSection
                measurementSection
                diagnosticsSection
            }
            .navigationTitle(
                "Dalmierz HOTO"
            )
            .navigationBarTitleDisplayMode(
                .inline
            )
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Zamknij") {
                        adapter.rozlacz()
                        dismiss()
                    }
                }
            }
            .alert(
                "Pomiar zapisany",
                isPresented:
                    Binding(
                        get: {
                            confirmationMessage
                                != nil
                        },
                        set: { visible in
                            if !visible {
                                confirmationMessage =
                                    nil
                            }
                        }
                    )
            ) {
                Button(
                    "OK",
                    role: .cancel
                ) {
                    confirmationMessage = nil
                }
            } message: {
                Text(
                    confirmationMessage
                    ?? ""
                )
            }
            .onDisappear {
                adapter.zatrzymajSkanowanie()
            }
        }
        .stolarniaReadableInterface()
    }

    @ViewBuilder
    private var statusSection:
        some View
    {
        Section("Połączenie") {
            Label(
                adapter.stan.opis,
                systemImage:
                    adapter.stan.systemImage
            )
            .foregroundStyle(
                statusColor
            )

            HStack {
                Button {
                    adapter
                        .rozpocznijSkanowanie()
                } label: {
                    Label(
                        "Szukaj HOTO",
                        systemImage:
                            "dot.radiowaves.left.and.right"
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )

                Button {
                    adapter
                        .zatrzymajSkanowanie()
                } label: {
                    Text("Zatrzymaj")
                }
                .buttonStyle(.bordered)
            }

            if adapter.connectedPeripheralID
                != nil {
                Button(
                    "Rozłącz",
                    role: .destructive
                ) {
                    adapter.rozlacz()
                }
            }

            Text(
                "Tryb testowy wyszukuje urządzenia o nazwach HOTO, QWCJY, H-D50 i HTE. Nie zapisuje wyniku automatycznie — każdy pomiar wymaga potwierdzenia."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var devicesSection:
        some View
    {
        Section("Wykryte urządzenia") {
            if adapter.urzadzenia.isEmpty {
                ContentUnavailableView {
                    Label(
                        "Brak urządzeń",
                        systemImage:
                            "antenna.radiowaves.left.and.right.slash"
                    )
                } description: {
                    Text(
                        "Włącz dalmierz HOTO, upewnij się, że nie jest połączony z Mi Home lub HOTO App, a następnie rozpocznij wyszukiwanie."
                    )
                }
            } else {
                ForEach(
                    adapter.urzadzenia
                ) { device in
                    Button {
                        adapter.polacz(
                            z: device.id
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Image(
                                systemName:
                                    device
                                        .isLikelyHOTO
                                    ? "ruler.fill"
                                    : "dot.radiowaves.left.and.right"
                            )
                            .foregroundStyle(
                                device.isLikelyHOTO
                                    ? Color.accentColor
                                    : Color.secondary
                            )

                            VStack(
                                alignment: .leading,
                                spacing: 3
                            ) {
                                Text(device.name)
                                    .font(.headline)

                                Text(
                                    "\(device.strengthDescription) • RSSI \(device.rssi)"
                                )
                                .font(.caption)
                                .foregroundStyle(
                                    .secondary
                                )
                            }

                            Spacer()

                            if adapter
                                .connectedPeripheralID
                                == device.id {
                                Image(
                                    systemName:
                                        "checkmark.circle.fill"
                                )
                                .foregroundStyle(
                                    .green
                                )
                            } else {
                                Image(
                                    systemName:
                                        "chevron.right"
                                )
                                .foregroundStyle(
                                    .tertiary
                                )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var decoderSection:
        some View
    {
        Section("Profil odbioru") {
            Picker(
                "Dekoder",
                selection:
                    $adapter.profilDekodera
            ) {
                ForEach(
                    ProfilDekoderaDalmierzaV0692
                        .allCases
                ) { profile in
                    Text(profile.nazwa)
                        .tag(profile)
                }
            }

            Picker(
                "Zapisz następny pomiar do",
                selection:
                    $selectedTarget
            ) {
                ForEach(
                    targetOptions
                ) { option in
                    Text(option.title)
                        .tag(option.target)
                }
            }

            Text(
                "Na początku pozostaw profil „Automatyczny”. Jeżeli dane HOTO nie zostaną rozpoznane albo wynik będzie nieprawidłowy, udostępnij diagnostykę z tej sesji."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var measurementSection:
        some View
    {
        Section("Ostatni odebrany wynik") {
            if let measurement =
                    adapter.ostatniPomiar {
                LabeledContent(
                    "Wartość",
                    value:
                        measurement
                            .wartoscZaokraglonaMM
                            .formatted()
                        + " mm"
                )

                LabeledContent(
                    "Dekoder",
                    value:
                        measurement
                            .profil
                            .nazwa
                )

                LabeledContent(
                    "Pewność parsera",
                    value:
                        Int(
                            measurement
                                .confidence
                                * 100
                        )
                        .formatted()
                        + "%"
                )

                LabeledContent(
                    "Charakterystyka",
                    value:
                        measurement
                            .characteristicUUID
                )
                .font(.caption)

                Button {
                    zastosuj(
                        measurement
                    )
                } label: {
                    Label(
                        "Zastosuj pomiar",
                        systemImage:
                            "checkmark.circle.fill"
                    )
                }
                .buttonStyle(
                    .borderedProminent
                )

                if measurement.confidence
                    < 0.8 {
                    Label(
                        "Wynik ma obniżoną pewność. Porównaj go z wyświetlaczem dalmierza przed zapisaniem.",
                        systemImage:
                            "exclamationmark.triangle"
                    )
                    .font(.footnote)
                    .foregroundStyle(
                        .orange
                    )
                }
            } else {
                ContentUnavailableView {
                    Label(
                        "Brak pomiaru",
                        systemImage:
                            "ruler"
                    )
                } description: {
                    Text(
                        "Połącz dalmierz i wykonaj pomiar fizycznym przyciskiem urządzenia."
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var diagnosticsSection:
        some View
    {
        Section {
            Toggle(
                "Pokaż także inne urządzenia BLE",
                isOn:
                    Binding(
                        get: {
                            adapter
                                .trybWykrywania
                                == .wszystkieBLE
                        },
                        set: { enabled in
                            adapter
                                .trybWykrywania =
                                    enabled
                                    ? .wszystkieBLE
                                    : .tylkoHOTO
                        }
                    )
            )

            Button {
                withAnimation {
                    showingDiagnostics
                        .toggle()
                }
            } label: {
                HStack {
                    Text("Surowe pakiety BLE")

                    Spacer()

                    Image(
                        systemName:
                            showingDiagnostics
                            ? "chevron.up"
                            : "chevron.down"
                    )
                    .foregroundStyle(
                        Color.secondary
                    )
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showingDiagnostics {
                if adapter
                    .pakietyDiagnostyczne
                    .isEmpty {
                    Text(
                        "Brak odebranych pakietów."
                    )
                    .foregroundStyle(
                        Color.secondary
                    )
                } else {
                    ForEach(
                        Array(
                            adapter
                                .pakietyDiagnostyczne
                                .suffix(20)
                        )
                    ) { packet in
                        VStack(
                            alignment: .leading,
                            spacing: 3
                        ) {
                            Text(
                                packet
                                    .characteristicUUID
                            )
                            .font(
                                .caption.monospaced()
                            )

                            Text(packet.rawHex)
                                .font(
                                    .caption2.monospaced()
                                )
                                .textSelection(
                                    .enabled
                                )

                            if let text =
                                    packet.textPreview {
                                Text(text)
                                    .font(.caption2)
                                    .foregroundStyle(
                                        Color.secondary
                                    )
                            }
                        }
                    }
                }
            }

            ShareLink(
                item:
                    adapter
                        .diagnostykaTekstowa
            ) {
                Label(
                    "Udostępnij diagnostykę",
                    systemImage:
                        "square.and.arrow.up"
                )
            }

            Button(
                "Wyczyść diagnostykę",
                role: .destructive
            ) {
                adapter
                    .wyczyscDiagnostyke()
            }
        } header: {
            Text("Diagnostyka testowa")
        } footer: {
            Text(
                "Tryb uniwersalny służy wyłącznie do diagnostyki i przyszłej rozbudowy. W tej wersji jako dalmierz roboczy traktowane jest tylko urządzenie HOTO."
            )
        }
    }

    private var statusColor:
        Color
    {
        switch adapter.stan {
        case .polaczony:
            return .green
        case .blad, .wylaczony:
            return .orange
        default:
            return .secondary
        }
    }

    private func zastosuj(
        _ measurement:
            KandydatPomiaruDalmierzaV0692
    ) {
        let value =
            measurement
                .wartoscZaokraglonaMM

        switch selectedTarget {
        case .szerokoscSciany:
            draft
                .szerokoscScianyMM =
                    value

        case .wysokoscMaksymalna:
            draft
                .wysokoscMaksymalnaMM =
                    value

        case .wysokoscSciankiKolankowej:
            draft
                .wysokoscSciankiKolankowejMM =
                    value

        case .glebokoscDocelowa:
            draft
                .glebokoscDocelowaMM =
                    value

        case .punktOdLewej(let id):
            guard let index =
                    draft
                        .punktySkosu
                        .firstIndex(
                            where: {
                                $0.id == id
                            }
                        )
            else {
                return
            }

            draft
                .punktySkosu[index]
                .odlegloscOdLewejMM =
                    value

            oznaczPunktJakoBluetooth(
                index: index,
                measurement:
                    measurement
            )

        case .punktWysokosc(let id):
            guard let index =
                    draft
                        .punktySkosu
                        .firstIndex(
                            where: {
                                $0.id == id
                            }
                        )
            else {
                return
            }

            draft
                .punktySkosu[index]
                .wysokoscMM =
                    value

            oznaczPunktJakoBluetooth(
                index: index,
                measurement:
                    measurement
            )
        }

        draft.zrodloPomiaruV069 =
            .bluetooth

        draft.producentUrzadzeniaV069 =
            "HOTO"

        draft.modelUrzadzeniaV069 =
            adapter
                .connectedPeripheralName
            ?? "HOTO"

        draft.blePeripheralIdentifierV0692 =
            adapter
                .connectedPeripheralID?
                .uuidString

        draft.bleDecoderProfileRawValueV0692 =
            measurement
                .profil
                .rawValue

        draft.bleLastCharacteristicUUIDV0692 =
            measurement
                .characteristicUUID

        draft.bleLastRawPacketHexV0692 =
            measurement
                .rawHex

        draft.bleLastMeasurementAtV0692 =
            measurement
                .timestamp

        confirmationMessage =
            "\(value.formatted()) mm zapisano w polu „\(nazwaCelu(selectedTarget))”."
    }

    private func oznaczPunktJakoBluetooth(
        index: Int,
        measurement:
            KandydatPomiaruDalmierzaV0692
    ) {
        guard draft
                .punktySkosu
                .indices
                .contains(index)
        else {
            return
        }

        draft
            .punktySkosu[index]
            .zrodloV069 =
                .bluetooth

        draft
            .punktySkosu[index]
            .nazwaUrzadzeniaV069 =
                adapter
                    .connectedPeripheralName
                ?? "HOTO"

        draft
            .punktySkosu[index]
            .zmierzonoAtV069 =
                measurement
                    .timestamp

        draft
            .punktySkosu[index]
            .tolerancjaMMV069 =
                draft
                    .tolerancjaDomyslnaV069

        // Pomiar BLE nie jest automatycznie uznawany za zweryfikowany.
        draft
            .punktySkosu[index]
            .potwierdzonyV069 =
                false
    }

    private func nazwaCelu(
        _ target:
            CelPomiaruDalmierzaV0692
    ) -> String {
        targetOptions
            .first(
                where: {
                    $0.target
                        == target
                }
            )?
            .title
        ?? "wybrane pole"
    }
}
