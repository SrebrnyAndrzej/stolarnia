import SwiftUI

struct PodgladImportuCennikuView: View {
    let raport: RaportImportuCennika
    @ObservedObject var repository: BazaMaterialowRepository
    @Environment(\.dismiss) private var dismiss

    @State private var zastosowano = false

    private let walutaFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "PLN"
        f.currencySymbol = "zł"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.locale = Locale(identifier: "pl_PL")
        return f
    }()

    var body: some View {
        NavigationStack {
            Group {
                if raport.dopasowane.isEmpty {
                    ContentUnavailableView(
                        "Brak dopasowań",
                        systemImage: "magnifyingglass",
                        description: Text(
                            "Żaden materiał z pliku nie pasuje do bazy.\n\nSprawdź czy nagłówki kolumn zawierają: Kod, Nazwa, Cena netto lub Cena brutto."
                        )
                    )
                } else {
                    lista
                }
            }
            .navigationTitle("Aktualizacja cen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        zastosujCeny()
                    } label: {
                        Text("Zastosuj \(raport.dopasowane.count) cen")
                            .fontWeight(.semibold)
                    }
                    .disabled(raport.dopasowane.isEmpty)
                }
            }
        }
    }

    // MARK: - Lista

    private var lista: some View {
        List {
            // Sekcja z dopasowanymi
            Section {
                ForEach(raport.dopasowane) { a in
                    wiersz(a)
                }
            } header: {
                HStack {
                    Text("\(raport.dopasowane.count) materiałów")
                    Spacer()
                    Text("Stara → Nowa cena")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }

            // Sekcja z niedopasowanymi (jeśli są)
            if !raport.niedopasowane.isEmpty {
                Section {
                    ForEach(raport.niedopasowane, id: \.self) { label in
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.secondary)
                            Text(label)
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                } header: {
                    Text("\(raport.niedopasowane.count) pozycji bez dopasowania w bazie")
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Wiersz

    @ViewBuilder
    private func wiersz(_ a: AktualizacjaCeny) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(a.material.nazwa)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()
                zmianaBadge(a)
            }

            HStack(spacing: 8) {
                Text(formatCena(a.staraCenaNetto))
                    .strikethrough(color: .secondary)
                    .foregroundStyle(.secondary)
                    .font(.caption)

                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(formatCena(a.nowaCenaNetto))
                    .foregroundStyle(kolorDelta(a))
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            HStack {
                Text("Dopasowano po \(a.zrodloMappingu) · \(a.material.producent)")
                    .foregroundStyle(.tertiary)
                    .font(.caption2)
                Spacer()
                Text(a.material.kod)
                    .foregroundStyle(.tertiary)
                    .font(.caption2.monospaced())
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func zmianaBadge(_ a: AktualizacjaCeny) -> some View {
        let procent = a.zmianaProcent
        if abs(procent) < 0.1 {
            EmptyView()
        } else {
            Text(String(format: "%+.1f%%", procent))
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(kolorDelta(a), in: Capsule())
        }
    }

    private func kolorDelta(_ a: AktualizacjaCeny) -> Color {
        let procent = a.zmianaProcent
        if abs(procent) < 0.1 { return .primary }
        // Wzrost ceny = zły (czerwony), spadek = dobry (zielony)
        return procent > 0
            ? .red
            : Color(red: 0.32, green: 0.56, blue: 0.12)
    }

    private func formatCena(_ cena: Double) -> String {
        walutaFormatter.string(from: NSNumber(value: cena))
            ?? String(format: "%.2f zł", cena)
    }

    // MARK: - Akcja

    private func zastosujCeny() {
        for a in raport.dopasowane {
            var updated = a.material
            updated.cenaNetto = a.nowaCenaNetto
            updated.dataAktualizacji = Date()
            if let rabat = a.nowyRabatProcent {
                updated.rabatProcent = rabat
            }
            if let vat = a.nowyVatProcent {
                updated.vatProcent = vat
            }
            repository.aktualizuj(updated)
        }
        dismiss()
    }
}
