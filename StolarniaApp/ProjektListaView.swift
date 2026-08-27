import Combine
import DomainCore
import SwiftUI

struct ProjektListaView: View {
    @ObservedObject var viewModel: ProjektListaViewModel
    /// Żądanie otwarcia formularza nowego projektu **spoza tego widoku**.
    ///
    /// Pulpit ma własny przycisk „Nowy projekt" i musi móc otworzyć ten sam
    /// formularz, zamiast dublować go u siebie. Wiązanie, a nie zdarzenie,
    /// bo formularz zamyka się sam po zapisaniu i stan musi wrócić do rodzica.
    var zadanieNowegoProjektuV0105: Binding<Bool>?
    @State private var isPresentingNewProject = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.projects.isEmpty {
                ProgressView("Wczytywanie projektów…")
            } else if viewModel.projects.isEmpty {
                ContentUnavailableView {
                    Label("Brak projektów", systemImage: "folder.badge.plus")
                } description: {
                    Text("Dodaj pierwszy projekt dla klienta.")
                } actions: {
                    Button("Dodaj projekt") {
                        isPresentingNewProject = true
                    }
                    .buttonStyle(
                        StolarniaPrimaryButtonStyle(
                            minHeight: 44,
                            horizontalPadding: 14,
                            cornerRadius: 12
                        )
                    )
                }
            } else {
                List(
                    selection: $viewModel.selectedProjectID
                ) {
                    ForEach(viewModel.projects) { project in
                        ProjektListaWiersz(
                            project: project,
                            isSelected:
                                viewModel.selectedProjectID
                                == project.id
                        )
                            .tag(project.id)
                            .listRowBackground(
                                viewModel.selectedProjectID
                                == project.id
                                ? StolarniaPalette
                                    .accent
                                    .opacity(0.46)
                                : StolarniaPalette
                                    .canvasRaised
                                    .opacity(0.48)
                            )
                            .swipeActions(edge: .trailing) {
                                Button("Usuń", role: .destructive) {
                                    Task {
                                        await viewModel.deleteProject(id: project.id)
                                    }
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Klienci i projekty")
        .environment(\.colorScheme, .dark)
        .stolarniaScreenSurface(
            .content
        )
        .stolarniaReadableInterface()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingNewProject = true
                } label: {
                    Label("Nowy projekt", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: [.command])
                .help("Nowy projekt (⌘N)")
            }
        }
        .onChange(of: zadanieNowegoProjektuV0105?.wrappedValue ?? false) { _, chce in
            if chce {
                isPresentingNewProject = true
                zadanieNowegoProjektuV0105?.wrappedValue = false
            }
        }
        .sheet(isPresented: $isPresentingNewProject) {
            NowyProjektView { code, name, customerName in
                let didCreate = await viewModel.createProject(
                    code: code,
                    name: name,
                    customerName: customerName
                )

                if didCreate {
                    isPresentingNewProject = false
                }
            }
        }
        .refreshable {
            await viewModel.loadProjects()
        }
    }
}

private struct ProjektListaWiersz: View {
    let project: WorkshopProject
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(project.name)
                    .font(.headline)
                    .foregroundStyle(primaryText)

                Spacer()

                Text(project.currentRevision.number.code)
                    .font(.caption.monospaced())
                    .foregroundStyle(secondaryText)
            }

            Text(project.code.rawValue)
                .font(.caption.monospaced())
                .foregroundStyle(secondaryText)

            HStack {
                Label(
                    project.customer.displayName,
                    systemImage: "person"
                )

                Spacer()

                Text(project.status.displayName)
            }
            .font(.caption)
            .foregroundStyle(secondaryText)
        }
        .padding(.vertical, 4)
    }

    private var primaryText: Color {
        isSelected
        ? StolarniaPalette.drawingInk
        : StolarniaPalette.sidebarPrimary
    }

    private var secondaryText: Color {
        isSelected
        ? StolarniaPalette.drawingInk.opacity(0.72)
        : StolarniaPalette.sidebarSecondary
    }
}
