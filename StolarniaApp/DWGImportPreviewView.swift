import DomainCore
import SwiftUI

/// Podgląd importu DWG z sekcjami dopasowanych / do sprawdzenia / niedopasowanych.
/// Wzorowany na `PodgladImportuCennikuView` — użytkownik widzi wszystkie proponowane
/// moduły, może zaznaczyć/odznaczyć i zaakceptować import.
struct DWGImportPreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let document: DWGImportDocumentV001
    let matches: [DWGModuleMatchV001]
    let onImport: ([DWGModuleMatchV001]) async -> Void

    @State private var zaznaczone: Set<String> = []
    @State private var importujeSie: Bool = false

    private var pogrupowane: (
        gotowe: [DWGModuleMatchV001],
        doSprawdzenia: [DWGModuleMatchV001],
        niedopasowane: [DWGModuleMatchV001]
    ) {
        var gotowe: [DWGModuleMatchV001] = []
        var doSprawdzenia: [DWGModuleMatchV001] = []
        var niedopasowane: [DWGModuleMatchV001] = []
        for m in matches {
            switch DWGImportMatchQualityV001.status(for: m.score) {
            case .autoAccept: gotowe.append(m)
            case .review: doSprawdzenia.append(m)
            case .noMatch: niedopasowane.append(m)
            }
        }
        return (gotowe, doSprawdzenia, niedopasowane)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    podsumowanie
                }

                if !pogrupowane.gotowe.isEmpty {
                    Section("Gotowe do importu (\(pogrupowane.gotowe.count))") {
                        ForEach(pogrupowane.gotowe) { m in
                            wierszDopasowania(m)
                        }
                    }
                }

                if !pogrupowane.doSprawdzenia.isEmpty {
                    Section("Do sprawdzenia (\(pogrupowane.doSprawdzenia.count))") {
                        ForEach(pogrupowane.doSprawdzenia) { m in
                            wierszDopasowania(m)
                        }
                    }
                }

                if !pogrupowane.niedopasowane.isEmpty {
                    Section("Bez dopasowania (\(pogrupowane.niedopasowane.count))") {
                        ForEach(pogrupowane.niedopasowane) { m in
                            wierszNiedopasowany(m)
                        }
                    }
                }
            }
            .navigationTitle("Import DWG — podgląd")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                        .disabled(importujeSie)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await wykonajImport() }
                    } label: {
                        if importujeSie {
                            ProgressView()
                        } else {
                            Text("Importuj (\(zaznaczone.count))")
                        }
                    }
                    .disabled(zaznaczone.isEmpty || importujeSie)
                }
            }
            .onAppear {
                // Domyślnie zaznaczone: wszystkie gotowe do importu.
                zaznaczone = Set(pogrupowane.gotowe.map(\.id))
            }
        }
    }

    // MARK: - Sekcje

    private var podsumowanie: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                statLabel("Plik", document.sourceFileName)
                Spacer()
                statLabel("Jednostka", document.unit.rawValue)
            }

            HStack(spacing: 12) {
                statBadge(
                    liczba: pogrupowane.gotowe.count,
                    etykieta: "Gotowe",
                    kolor: .green
                )
                statBadge(
                    liczba: pogrupowane.doSprawdzenia.count,
                    etykieta: "Do sprawdzenia",
                    kolor: .orange
                )
                statBadge(
                    liczba: pogrupowane.niedopasowane.count,
                    etykieta: "Bez dopas.",
                    kolor: .red
                )
            }
        }
    }

    private func wierszDopasowania(_ match: DWGModuleMatchV001) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle(
                "",
                isOn: Binding(
                    get: { zaznaczone.contains(match.id) },
                    set: { on in
                        if on { zaznaczone.insert(match.id) }
                        else { zaznaczone.remove(match.id) }
                    }
                )
            )
            .labelsHidden()

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: match.detected.kind.systemImage)
                        .foregroundStyle(.secondary)
                    Text(match.detected.rawName ?? match.detected.kind.czytelnaNazwa)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("score \(String(format: "%.2f", match.score))")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }

                if let tmpl = match.suggestedTemplate {
                    Text("→ \(tmpl.name) (\(tmpl.code))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Wymiar: \(intMM(match.targetWidth)) × \(intMM(match.targetHeight)) × \(intMM(match.targetDepth)) mm")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(match.reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private func wierszNiedopasowany(_ match: DWGModuleMatchV001) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.red)
                Text(match.detected.rawName ?? match.detected.kind.czytelnaNazwa)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            Text("Warstwa: \(match.detected.layer) • Blok: \(match.detected.sourceBlock)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(match.reason)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func statLabel(_ etykieta: String, _ wartosc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(etykieta)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(wartosc)
                .font(.caption.monospaced())
        }
    }

    private func statBadge(liczba: Int, etykieta: String, kolor: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(liczba)")
                .font(.title3.bold())
                .foregroundStyle(kolor)
            Text(etykieta)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(kolor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func intMM(_ value: Millimeters) -> String {
        String(Int(value.rawValue.rounded()))
    }

    private func wykonajImport() async {
        importujeSie = true
        defer { importujeSie = false }

        let doImportu = matches.filter { zaznaczone.contains($0.id) }
        await onImport(doImportu)
        dismiss()
    }
}
