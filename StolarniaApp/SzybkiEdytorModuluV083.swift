import DomainCore
import Persistence
import SwiftUI

// MARK: - Quick-edit strip wyświetlany w inspektorze elewacji

/// Poziomy pasek przycisków ±1 dla najczęstszych zmian przy kliencie:
/// szuflady, półki i fronty. Zapis przebiega przez istniejący pipeline
/// updateModule.
struct SzybkiEdytorModuluV083: View {
    let storedAssembly: StoredFurnitureAssembly
    @ObservedObject var mebleViewModel: MeblePomieszczeniaViewModel
    let wall: WallSegment
    let room: RoomDefinition

    @State private var isSaving = false
    @State private var lastError: String?

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                // Szuflady
                quickSection(
                    icon: "square.3.layers.3d.down.forward",
                    label: "Szuflady",
                    value: currentDrawerCount,
                    canDecrement: currentDrawerCount > 0,
                    canIncrement: currentDrawerCount < 12
                ) { delta in
                    await applyDelta(drawerDelta: delta)
                }

                colorSeparator

                // Półki
                quickSection(
                    icon: "books.vertical",
                    label: "Półki",
                    value: currentShelfCount,
                    canDecrement: currentShelfCount > 0,
                    canIncrement: currentShelfCount < 20
                ) { delta in
                    await applyDelta(shelfDelta: delta)
                }

                // Fronty — tylko gdy brak szuflad (szuflady mają własne fronty)
                if currentDrawerCount == 0 {
                    colorSeparator

                    quickSection(
                        icon: "rectangle.portrait",
                        label: "Fronty",
                        value: currentFrontCount,
                        canDecrement: currentFrontCount > 1,
                        canIncrement: currentFrontCount < 6
                    ) { delta in
                        applyFrontDelta(delta)
                    }
                }
            }
            .frame(height: 56)
            .background(Color(.secondarySystemBackground))

            if let error = lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.07))
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        // Komunikat błędu pojawia się rzadko i ma zwrócić uwagę — to jest
        // ten przypadek, w którym ruch niesie znaczenie, a nie tylko zdobi.
        .animation(StolarniaMotion.pojawienie, value: lastError)
    }

    // MARK: - Computed current values

    private var moduleKey: String {
        StabilnyKluczDomenowy.utworz(dla: storedAssembly.id, prefiks: "furniture")
    }

    private var currentDrawerCount: Int {
        let card = KartaTechnicznaSzafkiStore.card(forModuleKey: moduleKey)
        return card?.efektywneSzuflady.filter(\.aktywna).count ?? 0
    }

    private var currentShelfCount: Int {
        (try? storedAssembly.parameters.integer(for: .shelfCount)) ?? 0
    }

    /// Aktualna liczba frontów z karty technicznej; fallback auto-obliczenie z szerokości.
    private var currentFrontCount: Int {
        if let card = KartaTechnicznaSzafkiStore.card(forModuleKey: moduleKey),
           let config = card.konfiguracjaFunkcjonalnaV068
        {
            return config.front.bezpiecznaLiczbaFrontow
        }
        // Fallback: auto-reguła szerokości (≤600→1, ≤900→2, >900→3).
        let widthMM = storedAssembly.assembly.size.width.rawValue
        return KonfiguracjaFunkcjonalnaModuluV068.autoFrontCount(
            drawerCount: currentDrawerCount,
            widthMM: widthMM
        )
    }

    // MARK: - Actions

    private func applyDelta(shelfDelta: Int = 0, drawerDelta: Int = 0) async {
        guard let template = mebleViewModel.template(for: storedAssembly) else { return }

        let newShelf = currentShelfCount + shelfDelta
        let newDrawer = currentDrawerCount + drawerDelta

        let data = mebleViewModel.daneForQuickEdit(
            stored: storedAssembly,
            template: template,
            overrideShelfCount: shelfDelta != 0 ? newShelf : nil,
            overrideDrawerCount: drawerDelta != 0 ? newDrawer : nil
        )

        isSaving = true
        lastError = nil

        // Szuflady/półki nie zmieniają footprintu modułu →
        // kolizje nie mogą powstać → pomijamy kosztowną walidację.
        let ok = await mebleViewModel.updateModule(
            stored: storedAssembly,
            template: template,
            data: data,
            wall: wall,
            room: room,
            skipCollisionCheck: true
        )

        isSaving = false

        if !ok {
            lastError = mebleViewModel.errorMessage
                ?? "Nie udało się zapisać. Sprawdź kolizje."
        }
    }

    /// Zmienia liczbę frontów bezpośrednio w KartaTechnicznaSzafkiStore
    /// (z pominięciem pełnego pipeline updateModule, który wymaga kolizji i zapisuje corpus).
    private func applyFrontDelta(_ delta: Int) {
        let newCount = max(1, min(currentFrontCount + delta, 6))
        guard newCount != currentFrontCount else { return }

        // Pobierz istniejącą kartę lub utwórz minimalną nową z powiązaniem klucza modułu.
        var card: KartaTechnicznaSzafki
        if let existing = KartaTechnicznaSzafkiStore.card(forModuleKey: moduleKey) {
            card = existing
        } else {
            card = KartaTechnicznaSzafki(draftID: UUID())
            card.kluczModulu = moduleKey
            card.nazwa = storedAssembly.assembly.name
        }

        var config = card.efektywnaKonfiguracjaFunkcjonalnaV068
        config.front.liczbaFrontow = newCount
        card.konfiguracjaFunkcjonalnaV068 = config

        KartaTechnicznaSzafkiStore.save(card)
        mebleViewModel.forceRenderRefresh()
    }

    // MARK: - Sub-views

    private var colorSeparator: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(width: 0.5)
            .padding(.vertical, 10)
    }

    private func quickSection(
        icon: String,
        label: String,
        value: Int,
        canDecrement: Bool,
        canIncrement: Bool,
        onDelta: @escaping (Int) async -> Void
    ) -> some View {
        HStack(spacing: 0) {
            Button {
                Task { await onDelta(-1) }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 56)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canDecrement || isSaving)
            .foregroundStyle(canDecrement && !isSaving ? .primary : Color(.tertiaryLabel))

            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("\(value)")
                    .font(.system(size: 17, weight: .semibold).monospacedDigit())
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Button {
                Task { await onDelta(+1) }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 56)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canIncrement || isSaving)
            .foregroundStyle(canIncrement && !isSaving ? .primary : Color(.tertiaryLabel))
        }
        .frame(maxWidth: .infinity)
    }
}
