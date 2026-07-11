import Combine
import Foundation
import os

// MARK: - Kierunek ścianki podziałowej w pomieszczeniu

/// Oś, wzdłuż której ścianka dzieląca przebiega w rzucie 2D.
enum KierunekScianki:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    /// Ścianka równoległa do szerokości pomieszczenia (przecina głębokość)
    case rownoleglaDoSzerokosci
    /// Ścianka równoległa do głębokości pomieszczenia (przecina szerokość)
    case rownoleglaDoGlebokosci
    /// Zakotwiona do konkretnej ściany (offset od niej)
    case zakotwionaDoSciany

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .rownoleglaDoSzerokosci: return "Równoległa do szerokości"
        case .rownoleglaDoGlebokosci: return "Równoległa do głębokości"
        case .zakotwionaDoSciany:     return "Zakotwiona do ściany"
        }
    }
}

// MARK: - Model ścianki podziałowej

/// Ścianka dzieląca z drzwiami przesuwnymi montowana wewnątrz pomieszczenia.
///
/// Pozycja jest definiowana przez:
/// - `wallAnchorRawID` — ściana referencyjna (opcjonalna, dla `.zakotwionaDoSciany`)
/// - `offsetOdScianyMM` — odległość od ściany referencyjnej
/// - `szerokoscCalkowitaMM` — całkowita szerokość ścianki (= rozpiętość prowadnicy)
/// - `wysokoscCalkowitaMM` — wysokość do sufitu w miejscu montażu
///
/// Przy wyborze ściany referencyjnej prowadnica jest montowana równolegle do niej.
struct SciankaPodzialowaDefinicjaV075:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var nazwa: String = "Ścianka dzieląca"

    // Pozycja w pomieszczeniu
    var wallAnchorRawID: String?            // WallID.description, opcjonalne
    var kierunek: KierunekScianki = .zakotwionaDoSciany
    var offsetOdScianyMM: Double = 1500     // odległość od ściany referencyjnej

    // Gabaryty
    var szerokoscCalkowitaMM: Double = 2400 // rozpiętość = szerokość szafy przesuwnej
    var wysokoscCalkowitaMM: Double  = 2500 // od podłogi do sufitu w miejscu montażu

    // System drzwi przesuwnych
    var systemPrzesuwny: SzafaPrzesuwnaDefinicjaV075

    // Wypełnienie drzwi (Bonari catalog ID)
    var wypelnienieDrzwiID: String = "SZKLO-CLEAR"

    // Wykończenie profilu (Bonari catalog ID)
    var materialProfiluID: String = "ALU-SILVER"

    // Opcje montażu
    var montazDoSufitu: Bool = true         // prowadnica górna do sufitu (vs. do futryny)
    var montazPrzybijany: Bool = false      // czy pod prowadnicę idzie deska nośna

    // Uwagi
    var uwagi: String = ""
    var dataUtworzenia: Date = Date()

    init() {
        var sys = SzafaPrzesuwnaDefinicjaV075()
        sys.szerokoscCalkowitaMM = 2400
        sys.wysokoscCalkowitaMM  = 2500
        sys.systemProfili = .bonariPartition80
        sys.konstrukjaDrzwi = .szklo
        sys.systemToru = .gorny
        sys.miekkieZamykanie = true
        sys.systemSoftClose = true
        sys.uchwytTyp = .bezUchwytu
        sys.gruboscDrzwiMM = 8  // szkło 8mm
        sys.normalize()
        self.systemPrzesuwny = sys
    }

    mutating func synchronizujZSystemem() {
        systemPrzesuwny.szerokoscCalkowitaMM = szerokoscCalkowitaMM
        systemPrzesuwny.wysokoscCalkowitaMM  = wysokoscCalkowitaMM
        systemPrzesuwny.wypelnienieDrzwiID   = wypelnienieDrzwiID
        systemPrzesuwny.normalize()
    }

    /// Raport Bonari z auto-doborem serii dla bieżącej konfiguracji
    var raportBonari: (raport: RaportSzafyPrzesuwanejV075, autoWybor: BonariKatalog.WynikAutoDoboruDrzwi) {
        SilnikSzafyPrzesuwanejV075.raportBonari(dla: systemPrzesuwny)
    }

    /// Wypełnienie drzwi z katalogu Bonari
    var wypelnienie: WypelnienieDrzwiBonari? {
        BonariKatalog.wypelnienia.first { $0.id == wypelnienieDrzwiID }
    }

    /// Materiał profilu z katalogu Bonari
    var materialProfilu: MaterialProfilu? {
        let seriaProfil = systemPrzesuwny.systemProfili.seriaBonari?.profil
        return seriaProfil?.materialyProfilu.first { $0.id == materialProfiluID }
    }
}

// MARK: - Repository

@MainActor
final class SciankaPodzialowaRepository:
    ObservableObject
{
    @Published private(set) var sciankiDzielace:
        [SciankaPodzialowaDefinicjaV075] = []

    let roomID: String
    private let defaults: UserDefaults
    private let key: String
    private let backupKey: String

    init(
        roomID: String,
        defaults: UserDefaults = .standard
    ) {
        self.roomID = roomID
        self.defaults = defaults
        self.key = "SciankaPodziałowa.v1.\(roomID)"
        self.backupKey = "SciankaPodziałowa.v1.\(roomID).backup"
        wczytaj()
    }

    // MARK: - CRUD

    func dodaj(_ nowa: SciankaPodzialowaDefinicjaV075) {
        sciankiDzielace.append(nowa)
        zapisz()
    }

    func zaktualizuj(_ zaktualizowana: SciankaPodzialowaDefinicjaV075) {
        if let idx = sciankiDzielace.firstIndex(where: { $0.id == zaktualizowana.id }) {
            sciankiDzielace[idx] = zaktualizowana
            zapisz()
        }
    }

    func usun(id: UUID) {
        sciankiDzielace.removeAll { $0.id == id }
        zapisz()
    }

    func usunWszystkie() {
        sciankiDzielace.removeAll()
        zapisz()
    }

    // MARK: - Persystencja

    private func wczytaj() {
        let result = BezpiecznyMagazynJSON.wczytaj(
            [SciankaPodzialowaDefinicjaV075].self,
            defaults: defaults,
            key: key,
            backupKey: backupKey,
            wartoscDomyslna: []
        )
        sciankiDzielace = result.wartosc
    }

    private func zapisz() {
        do {
            try BezpiecznyMagazynJSON.zapisz(
                sciankiDzielace,
                defaults: defaults,
                key: key,
                backupKey: backupKey
            )
        } catch {
            StolarniaLogger.zapis.error("Błąd zapisu ścianek podziałowych: \(error.localizedDescription)")
        }
    }
}
