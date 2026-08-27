import DomainCore
import SwiftUI
import UniformTypeIdentifiers

/// Kontener importu DWG — samodzielne okno prezentowane jako sheet.
/// Odpowiedzialność:
/// - wybór pliku JSON przez `fileImporter`
/// - wczytanie dokumentu i uruchomienie matchera
/// - prezentacja `DWGImportPreviewView` z wynikami
/// - zapisanie zaakceptowanych modułów przez `MeblePomieszczeniaViewModel`
///
/// Dzięki temu integracja z `WorkspaceProjektowyViewV063` sprowadza się do
/// jednego `sheet(isPresented:)` i przycisku w toolbarze.
struct DWGImportKontenerV001: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var mebleViewModel: MeblePomieszczeniaViewModel
    let room: RoomDefinition
    let walls: [WallSegment]

    @State private var pokazFileImporter: Bool = false
    @State private var document: DWGImportDocumentV001?
    @State private var matches: [DWGModuleMatchV001] = []
    @State private var bladWczytywania: String?
    @State private var wynikImportu: MeblePomieszczeniaViewModel.WynikImportuDWGV001?
    @State private var trwaImport: Bool = false
    /// Opis aktualnego etapu importu — pokazywany w overlay z ProgressView.
    /// Wartości wg fazy: "Wczytuję plik...", "Dopasowuję do biblioteki...",
    /// "Zapisuję moduł N/M...", "Zapisywanie zakończone".
    @State private var etapImportu: String = ""

    var body: some View {
        NavigationStack {
            Group {
                if let wynik = wynikImportu {
                    podsumowaniePoImporcie(wynik)
                } else if let document {
                    DWGImportPreviewView(
                        document: document,
                        matches: matches,
                        onImport: { zaakceptowane in
                            await wykonajImport(
                                document: document,
                                zaakceptowane: zaakceptowane
                            )
                        }
                    )
                } else {
                    ekranStartowy
                }
            }
            .navigationTitle("Import DWG architekta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") { dismiss() }
                        .disabled(trwaImport)
                }
            }
            .fileImporter(
                isPresented: $pokazFileImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                obsluzWybor(result: result)
            }
            .overlay {
                if trwaImport {
                    postepImportuOverlay
                }
            }
            .alert(
                "Błąd wczytywania",
                isPresented: bindingBleduWczytywania,
                presenting: bladWczytywania
            ) { _ in
                Button("OK", role: .cancel) {
                    bladWczytywania = nil
                }
            } message: { text in
                Text(text)
            }
        }
    }

    // MARK: - Ekrany

    private var ekranStartowy: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            Text("Import projektu architekta")
                .font(.title2.bold())

            Text("Wybierz plik JSON wyeksportowany z projektu DWG. Aplikacja rozpozna meble, AGD i zabudowy, a następnie dopasuje je do biblioteki modułów.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                pokazFileImporter = true
            } label: {
                Label("Wybierz plik JSON", systemImage: "doc.badge.plus")
                    .frame(minWidth: 220)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("Format: neutralny JSON DWG → tworzony poza aplikacją (LibreDWG/ODA/inny konwerter).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func podsumowaniePoImporcie(
        _ wynik: MeblePomieszczeniaViewModel.WynikImportuDWGV001
    ) -> some View {
        VStack(spacing: 16) {
            Image(systemName: wynik.blad == nil ? "checkmark.seal.fill" : "exclamationmark.triangle")
                .font(.system(size: 56))
                .foregroundStyle(wynik.blad == nil ? .green : .orange)

            Text(wynik.blad == nil ? "Import zakończony" : "Import zakończony z ostrzeżeniami")
                .font(.title2.bold())

            VStack(spacing: 6) {
                Text("Dodane moduły: \(wynik.dodane)")
                Text("Pominięte: \(wynik.pominiete)")
                    .foregroundStyle(.secondary)
                if let blad = wynik.blad {
                    Text(blad)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            .font(.subheadline)

            Button("Zamknij") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Logika

    private func obsluzWybor(result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            bladWczytywania = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            wczytajPlik(url: url)
        }
    }

    private func wczytajPlik(url: URL) {
        do {
            etapImportu = "Wczytuję plik JSON…"
            let doc = try DWGImportParserV001.wczytaj(z: url)
            document = doc
            etapImportu = "Dopasowuję \(doc.detectedItems.count) obiektów do biblioteki modułów…"
            matches = DWGImportMatcherV001.dopasuj(
                document: doc,
                dostepneTemplates: mebleViewModel.templates
            )
            etapImportu = ""
        } catch {
            bladWczytywania = error.localizedDescription
            etapImportu = ""
        }
    }

    @MainActor
    private func wykonajImport(
        document: DWGImportDocumentV001,
        zaakceptowane: [DWGModuleMatchV001]
    ) async {
        trwaImport = true
        etapImportu = "Przygotowuję plany importu…"
        defer {
            trwaImport = false
            etapImportu = ""
        }

        let plany = DWGImportAssemblyMapperV001.planyImportu(
            document: document,
            zaakceptowaneMatche: zaakceptowane
        )

        etapImportu = "Zapisuję \(plany.count) \(plany.count == 1 ? "moduł" : "modułów") do pomieszczenia…"

        let wynik = await mebleViewModel.importujZDWG(
            plany: plany,
            room: room,
            walls: walls
        )
        wynikImportu = wynik
    }

    /// Overlay pełnoekranowy pokazywany podczas trwającego importu.
    /// Zawiera opis aktualnego etapu, żeby użytkownik miał feedback co się dzieje.
    private var postepImportuOverlay: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(.white)

            Text(etapImportu.isEmpty ? "Trwa import…" : etapImportu)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.black.opacity(0.75))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.25).ignoresSafeArea())
        .transition(.opacity)
    }

    private var bindingBleduWczytywania: Binding<Bool> {
        Binding(
            get: { bladWczytywania != nil },
            set: { on in
                if !on { bladWczytywania = nil }
            }
        )
    }
}
