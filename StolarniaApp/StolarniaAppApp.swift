import Combine
import Persistence
import SwiftData
import SwiftUI

@MainActor
private struct StolarniaAppContext {
    let modelContainer: ModelContainer
    let projectRepository: SwiftDataProjectRepository
    let roomRepository: SwiftDataRoomRepository
    let mebleRepositories: MebleRepositoryContainer
}

@MainActor
private final class StolarniaAppBootstrapController:
    ObservableObject
{
    @Published private(set) var context:
        StolarniaAppContext?
    @Published private(set) var errorMessage:
        String?
    @Published private(set) var isStarting =
        false

    init() {
        StolarniaAppearance.configure()
        uruchom()
    }

    func uruchom() {
        guard !isStarting else {
            return
        }

        isStarting = true
        errorMessage = nil

        do {
            let container =
                try PersistenceController
                    .makeModelContainer()

            context = StolarniaAppContext(
                modelContainer:
                    container,
                projectRepository:
                    SwiftDataProjectRepository(
                        modelContainer:
                            container
                    ),
                roomRepository:
                    SwiftDataRoomRepository(
                        modelContainer:
                            container
                    ),
                mebleRepositories:
                    MebleRepositoryContainer(
                        templateRepository:
                            SwiftDataFurnitureTemplateRepository(
                                modelContainer:
                                    container
                            ),
                        assemblyRepository:
                            SwiftDataFurnitureAssemblyRepository(
                                modelContainer:
                                    container
                            ),
                        runRepository:
                            SwiftDataFurnitureRunRepository(
                                modelContainer:
                                    container
                            )
                    )
            )
        } catch {
            context = nil
            errorMessage =
                error.localizedDescription
        }

        isStarting = false
    }
}

@main
struct StolarniaAppApp: App {
    @StateObject private var bootstrap =
        StolarniaAppBootstrapController()

    var body: some Scene {
        WindowGroup {
            StolarniaAppRoot(
                bootstrap: bootstrap
            )
        }
    }
}

@MainActor
private struct StolarniaAppRoot: View {
    @ObservedObject var bootstrap:
        StolarniaAppBootstrapController

    /// true gdy firma nie ma jeszcze nazwy → pokaż onboarding
    @State private var pokazOnboarding = false

    var body: some View {
        Group {
            if let context =
                bootstrap.context
            {
                StolarniaAppThemeRoot {
                    PanelGlownyView(
                        projectRepository:
                            context
                                .projectRepository,
                        roomRepository:
                            context
                                .roomRepository,
                        mebleRepositories:
                            context
                                .mebleRepositories
                    )
                }
                .modelContainer(
                    context.modelContainer
                )
                .fullScreenCover(
                    isPresented:
                        $pokazOnboarding
                ) {
                    StolarniaOnboardingView {
                        pokazOnboarding = false
                    }
                }
                .onAppear {
                    let ustawienia =
                        UstawieniaStolarniRepository
                            .aktualne()
                    if ustawienia
                        .daneFirmy
                        .nazwaFirmy
                        .trimmingCharacters(
                            in: .whitespaces
                        )
                        .isEmpty
                    {
                        pokazOnboarding = true
                    }
                }
            } else {
                StolarniaStartupRecoveryView(
                    message:
                        bootstrap
                            .errorMessage
                        ?? "Nieznany błąd inicjalizacji bazy.",
                    isStarting:
                        bootstrap
                            .isStarting,
                    onRetry: {
                        bootstrap.uruchom()
                    }
                )
            }
        }
    }
}

private struct StolarniaStartupRecoveryView:
    View
{
    let message: String
    let isStarting: Bool
    let onRetry: () -> Void

    private var diagnostics: String {
        """
        StolarniaApp — diagnostyka uruchomienia
        Data: \(Date().formatted(date: .numeric, time: .standard))
        System: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Błąd: \(message)
        """
    }

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label(
                    "Nie udało się otworzyć bazy",
                    systemImage:
                        "externaldrive.badge.exclamationmark"
                )
            } description: {
                Text(
                    "Aplikacja nie została zamknięta awaryjnie, a zapisane dane nie są automatycznie usuwane. Spróbuj ponownie albo udostępnij diagnostykę."
                )
            } actions: {
                VStack(spacing: 12) {
                    Button {
                        onRetry()
                    } label: {
                        if isStarting {
                            ProgressView()
                        } else {
                            Label(
                                "Spróbuj ponownie",
                                systemImage:
                                    "arrow.clockwise"
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isStarting)

                    ShareLink(
                        item: diagnostics
                    ) {
                        Label(
                            "Udostępnij diagnostykę",
                            systemImage:
                                "square.and.arrow.up"
                        )
                    }
                    .buttonStyle(.bordered)
                }
            }
            .navigationTitle(
                "Tryb odzyskiwania"
            )
            .safeAreaInset(
                edge: .bottom
            ) {
                Text(message)
                    .font(
                        .footnote.monospaced()
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .textSelection(.enabled)
                    .padding()
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .stolarniaMaterial(
                        .thinMaterial
                    )
            }
        }
        .stolarniaReadableInterface()
    }
}
