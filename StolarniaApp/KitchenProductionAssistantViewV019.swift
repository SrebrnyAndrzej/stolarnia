import DomainCore
import SwiftUI

struct KitchenProductionAssistantViewV019: View {
    @Environment(\.dismiss) private var dismiss

    let wall: WallSegment
    let room: RoomDefinition
    let assemblies: [FurnitureAssembly]

    private var analysis: KitchenProductionAnalysisV019 {
        KitchenProductionAnalyzerV019.analyze(
            wall: wall,
            room: room,
            assemblies: assemblies
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summaryHeader
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section("Uzupełnienie zabudowy") {
                    if analysis.gaps.isEmpty {
                        ContentUnavailableView(
                            "Brak luk",
                            systemImage: "checkmark.seal",
                            description: Text(
                                "Wykryte pasy zabudowy nie wymagają uzupełnienia."
                            )
                        )
                    } else {
                        ForEach(KitchenRunLaneV019.allCases, id: \.self) { lane in
                            let laneGaps =
                                analysis
                                    .gaps
                                    .filter {
                                        $0.lane == lane
                                    }

                            if !laneGaps.isEmpty {
                                laneHeader(lane)

                                ForEach(laneGaps) { gap in
                                    gapRow(gap)
                                }
                            }
                        }
                    }
                }

                Section("Blaty") {
                    if analysis.countertops.isEmpty {
                        Text("Brak dolnego ciągu do przeliczenia blatu.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(analysis.countertops) { item in
                            LabeledContent(
                                "Od \(formatted(item.start)) • \(formatted(item.width))",
                                value:
                                    "\(formatted(item.depth)) / \(formatted(item.thickness))"
                            )
                        }
                    }
                }

                Section("Fartuchy") {
                    if analysis.backsplashes.isEmpty {
                        Text("Brak dolnego ciągu do wyznaczenia fartucha.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(analysis.backsplashes) { item in
                            LabeledContent(
                                "Od \(formatted(item.start)) • \(formatted(item.width))",
                                value:
                                    "wys. \(formatted(item.height))"
                            )
                        }
                    }
                }

                Section {
                    Text(
                        "Asystent analizuje aktualne moduły na ścianie i wskazuje luki w osobnych pasach zabudowy. Zapis propozycji jako gotowych modułów zostanie dodany jako kolejny krok."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Asystent zabudowy")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(StolarniaPalette.accent)
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Asystent zabudowy")
                        .font(.title3.bold())

                    Text("\(wall.name) • \(assemblies.count) modułów na ścianie")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                summaryMetric(
                    title: "Luki",
                    value: "\(analysis.gaps.count)",
                    systemImage: "rectangle.dashed"
                )

                summaryMetric(
                    title: "Blaty",
                    value: "\(analysis.countertops.count)",
                    systemImage: "rectangle.topthird.inset.filled"
                )

                summaryMetric(
                    title: "Fartuchy",
                    value: "\(analysis.backsplashes.count)",
                    systemImage: "rectangle.split.3x1"
                )
            }
        }
        .stolarniaFrostedCard(
            cornerRadius: 18,
            padding: 16
        )
    }

    private func summaryMetric(
        title: String,
        value: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(StolarniaPalette.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.callout.monospacedDigit().weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func laneHeader(
        _ lane: KitchenRunLaneV019
    ) -> some View {
        Label(lane.title, systemImage: lane.systemImage)
            .font(.headline)
            .foregroundStyle(StolarniaPalette.accent)
            .padding(.top, 6)
    }

    private func gapRow(
        _ gap: KitchenGapSuggestionV019
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: gap.recommendation.systemImage)
                    .font(.headline)
                    .foregroundStyle(StolarniaPalette.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(gap.recommendation.title)
                        .font(.headline)

                    Text(
                        "Od \(formatted(gap.start)), wolne \(formatted(gap.width))"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Text(recommendationText(gap))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            if gap.fillerWidth > .zero {
                Text("Blenda końcowa: \(formatted(gap.fillerWidth))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
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

    private func recommendationText(
        _ gap: KitchenGapSuggestionV019
    ) -> String {
        switch gap.recommendation {
        case .fillerOnly:
            return "Zostaw jako blendę albo maskownicę docinaną do ściany."
        case .customModule:
            return "Zaprojektuj moduł na wymiar dla tego odcinka."
        case .standardModules:
            return "Moduły: "
                + gap.proposedWidths
                    .map(formatted)
                    .joined(separator: " + ")
        }
    }
}
