import SwiftUI

struct PanelDalmierzaGlownyView: View {
    @StateObject private var adapter =
        UniwersalnyAdapterDalmierzaBLEV0692()

    @State private var showingDiagnostics = false

    var body: some View {
        List {
            statusSection
            actionSection
            devicesSection
            if let pomiar = adapter.ostatniPomiar {
                lastMeasurementSection(pomiar)
            }
            settingsSection
            if showingDiagnostics {
                diagnosticsSection
            }
        }
        .navigationTitle("Dalmierz HOTO")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingDiagnostics.toggle()
                } label: {
                    Label(
                        "Diagnostyka",
                        systemImage: "waveform.path.ecg"
                    )
                }
            }
        }
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section("Stan połączenia") {
            Label(adapter.stan.opis, systemImage: adapter.stan.systemImage)
                .foregroundStyle(statusColor)

            if case .polaczony(let name) = adapter.stan {
                LabeledContent("Urządzenie", value: name)
                Button(role: .destructive) {
                    adapter.rozlacz()
                } label: {
                    Label("Rozłącz", systemImage: "xmark.circle")
                }
            }
        }
    }

    private var actionSection: some View {
        Section {
            switch adapter.stan {
            case .skanowanie:
                Button(role: .destructive) {
                    adapter.zatrzymajSkanowanie()
                } label: {
                    Label("Zatrzymaj wyszukiwanie", systemImage: "stop.circle")
                }
                HStack {
                    ProgressView().padding(.trailing, 4)
                    Text("Szukam urządzeń HOTO…")
                        .foregroundStyle(.secondary)
                }

            case .polaczony:
                EmptyView()

            default:
                Button {
                    adapter.rozpocznijSkanowanie()
                } label: {
                    Label(
                        "Szukaj urządzeń BLE",
                        systemImage: "dot.radiowaves.left.and.right"
                    )
                }
                .buttonStyle(.borderedProminent)
            }
        } header: {
            Text("Akcje")
        } footer: {
            Text("Włącz dalmierz HOTO H-D50 i naciśnij przycisk BT aż dioda zacznie migać niebiesko. Na liście pojawią się wszystkie urządzenia BLE w pobliżu — wybierz swój dalmierz.")
        }
    }

    @ViewBuilder
    private var devicesSection: some View {
        if !adapter.urzadzenia.isEmpty {
            Section("Znalezione urządzenia") {
                ForEach(adapter.urzadzenia) { device in
                    Button {
                        adapter.polacz(z: device.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    if device.isLikelyHOTO {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundStyle(.green)
                                            .font(.caption)
                                    }
                                    Text(device.name)
                                        .fontWeight(device.isLikelyHOTO ? .semibold : .regular)
                                }
                                Text(device.id.uuidString)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 8) {
                                    Text(device.strengthDescription)
                                    Text("RSSI: \(device.rssi) dBm")
                                }
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                if let mfr = device.manufacturerDataHex {
                                    Text("MFR: \(mfr)")
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    private func lastMeasurementSection(
        _ pomiar: KandydatPomiaruDalmierzaV0692
    ) -> some View {
        Section("Ostatni odebrany pomiar") {
            LabeledContent(
                "Odległość",
                value: pomiar.wartoscZaokraglonaMM
                    .formatted(.number.precision(.fractionLength(1))) + " mm"
            )
            .font(.title3.weight(.semibold))

            LabeledContent(
                "Pewność",
                value: (pomiar.confidence * 100)
                    .formatted(.number.precision(.fractionLength(0))) + "%"
            )
            LabeledContent("Profil", value: pomiar.profil.nazwa)
            LabeledContent(
                "Czas",
                value: pomiar.timestamp.formatted(date: .omitted, time: .standard)
            )

            Label(
                "Pomiary odebrane tutaj służą do weryfikacji połączenia. Żeby zapisać pomiar do profilu skosu, wejdź do konkretnego pomieszczenia.",
                systemImage: "info.circle"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private var settingsSection: some View {
        Section("Ustawienia dekodera") {
            Picker("Profil dekodowania", selection: $adapter.profilDekodera) {
                ForEach(ProfilDekoderaDalmierzaV0692.allCases) { profil in
                    Text(profil.nazwa).tag(profil)
                }
            }
            Picker("Tryb wykrywania", selection: $adapter.trybWykrywania) {
                ForEach(TrybWykrywaniaDalmierzaV0692.allCases) { tryb in
                    Text(tryb.nazwa).tag(tryb)
                }
            }
        }
    }

    @ViewBuilder
    private var diagnosticsSection: some View {
        Section("Pakiety BLE (\(adapter.pakietyDiagnostyczne.count))") {
            if adapter.pakietyDiagnostyczne.isEmpty {
                Text("Brak danych — połącz dalmierz i wykonaj pomiar.")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            } else {
                ForEach(adapter.pakietyDiagnostyczne.reversed()) { packet in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(packet.characteristicUUID)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(packet.timestamp.formatted(date: .omitted, time: .standard))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Text(packet.rawHex)
                            .font(.caption.monospaced())
                        if let text = packet.textPreview {
                            Text(text)
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Button(role: .destructive) {
                    adapter.wyczyscDiagnostyke()
                } label: {
                    Label("Wyczyść diagnostykę", systemImage: "trash")
                }

                ShareLink(
                    item: adapter.diagnostykaTekstowa,
                    subject: Text("Diagnostyka HOTO BLE"),
                    message: Text("Pakiety BLE z dalmierza HOTO")
                ) {
                    Label("Udostępnij diagnostykę", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch adapter.stan {
        case .polaczony: return .green
        case .blad, .wylaczony, .oczekiwanieNaBluetooth: return .red
        case .skanowanie, .laczenie: return .orange
        default: return .secondary
        }
    }
}
