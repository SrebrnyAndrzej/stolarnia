import DomainCore
import SwiftUI

struct WyborTrybuNowegoPomieszczeniaView: View {
    @Environment(\.dismiss) private var dismiss

    let projectID: ProjectID
    let onCreateRectangle: (
        String, Double, Double, Double, Double, ConstructionType
    ) async -> Bool
    let onSaveSurveyedRoom: (RoomDefinition) async -> Bool

    @State private var route: Route?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        route = .guided
                    } label: {
                        modeRow(
                            title: "Pomiar prowadzony po obrysie",
                            subtitle: "Zalecane. Budujesz realne pomieszczenie ściana po ścianie, razem z wnękami, uskokami i wykuszami.",
                            icon: "point.topleft.down.to.point.bottomright.curvepath",
                            emphasized: true
                        )
                    }

                    Button {
                        route = .rectangle
                    } label: {
                        modeRow(
                            title: "Szybki prostokąt",
                            subtitle: "Do wstępnej wyceny albo idealnie prostego pomieszczenia.",
                            icon: "rectangle",
                            emphasized: false
                        )
                    }
                } header: {
                    Text("Wybierz sposób tworzenia pomieszczenia")
                }
            }
            .navigationTitle("Nowe pomieszczenie")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                }
            }
            .sheet(item: $route) { route in
                switch route {
                case .guided:
                    ProwadzonyPomiarPomieszczeniaView(
                        projectID: projectID,
                        onSave: { room in
                            let result = await onSaveSurveyedRoom(room)
                            if result { dismiss() }
                            return result
                        }
                    )
                case .rectangle:
                    NowePomieszczenieView { name, width, depth, height, thickness, construction in
                        let result = await onCreateRectangle(
                            name, width, depth, height, thickness, construction
                        )
                        if result { dismiss() }
                        return result
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func modeRow(
        title: String,
        subtitle: String,
        icon: String,
        emphasized: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(emphasized ? Color.accentColor : .secondary)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 8)
    }

    private enum Route: String, Identifiable {
        case guided
        case rectangle
        var id: String { rawValue }
    }
}
