import DomainCore
import SwiftUI

/// Wielo-arkuszowa dokumentacja techniczna ściany.
/// Każdy moduł to jeden arkusz A4/A3 leżący pod poprzednim (scroll pionowy).
/// W eksporcie PDF wszystkie arkusze łączone są w jeden dokument.
///
/// To jedyny widok dokumentacji technicznej w aplikacji — zastąpił poprzednie
/// `TechnicalDocumentationViewV023` (elewacja techniczna + aksonometria + 3D).
/// Widoki aksonometrii i 3D dostępne osobno przez podgląd 3D.
struct KartyTechniczneModulowV028: View {
    let assemblies: [FurnitureAssembly]
    var cornerDefinitions:
        [CornerCabinetDefinitionV025] = []
    /// Opcjonalne wywołanie zamknięcia — jeżeli widok jest prezentowany jako sheet/fullscreen.
    var onClose: (() -> Void)? = nil

    @State private var format: FormatArkuszaTechnicznego = .a4Pionowy

    private var karty: [(assembly: FurnitureAssembly, card: KartaTechnicznaSzafki, numer: Int)] {
        assemblies.enumerated().map { pair in
            (
                assembly: pair.element,
                card: kartaDlaAssembly(pair.element, numer: pair.offset + 1),
                numer: pair.offset + 1
            )
        }
    }

    var body: some View {
        NavigationStack {
            zawartosc
                .navigationTitle("Dokumentacja techniczna")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if let onClose {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Zamknij") { onClose() }
                        }
                    }

                    ToolbarItem(placement: .principal) {
                        Picker("Format", selection: $format) {
                            ForEach(FormatArkuszaTechnicznego.allCases) { f in
                                Text(f.tytul).tag(f)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 180)
                    }
                }
        }
    }

    @ViewBuilder
    private var zawartosc: some View {
        if assemblies.isEmpty {
            ContentUnavailableView(
                "Brak modułów na ścianie",
                systemImage: "shippingbox",
                description: Text(
                    "Dodaj moduły w Planie 2D lub Elewacji, żeby wygenerować arkusze techniczne."
                )
            )
        } else {
            VStack(spacing: 0) {
                pasekInfo

                ScrollView(.vertical) {
                    LazyVStack(spacing: 24) {
                        ForEach(Array(karty.enumerated()), id: \.offset) { pair in
                            ArkuszTechnicznyA4V028(
                                card: pair.element.card,
                                numerStrony: pair.element.numer,
                                liczbaStron: karty.count,
                                format: format
                            )
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 16)
                }
                .background(Color(uiColor: .systemGray6))
            }
        }
    }

    private var pasekInfo: some View {
        HStack(spacing: 12) {
            Label(
                "\(assemblies.count) modułów • \(assemblies.count) arkuszy",
                systemImage: "doc.on.doc"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .stolarniaMaterial(.regularMaterial)
    }

    // MARK: - Dane karty per moduł

    private func kartaDlaAssembly(
        _ assembly: FurnitureAssembly,
        numer: Int
    ) -> KartaTechnicznaSzafki {
        let key = assembly.id.rawValue.uuidString

        if let saved = KartaTechnicznaSzafkiStore.card(forModuleKey: key) {
            var card =
                saved
            KartaTechnicznaSzafkiBuilder
                .applyProductionDrillings(
                    to:
                        &card,
                    assembly:
                        assembly,
                    numer:
                        numer
                )

            return cardWithCornerRules(
                card,
                assembly: assembly
            )
        }

        let card =
            KartaTechnicznaSzafkiBuilder
            .build(
                assembly:
                    assembly,
                numer:
                    numer
            )

        return cardWithCornerRules(
            card,
            assembly: assembly
        )
    }

    private func cardWithCornerRules(
        _ source:
            KartaTechnicznaSzafki,
        assembly:
            FurnitureAssembly
    ) -> KartaTechnicznaSzafki {
        guard let definition =
            cornerDefinitions.first(
                where: {
                    $0.assemblyID
                        == assembly.id
                }
            )
        else {
            return source
        }

        var card = source
        KartaTechnicznaSzafkiBuilder
            .applyCornerCabinetRules(
                to: &card,
                definition:
                    definition,
                assembly:
                    assembly
            )
        return card
    }
}
