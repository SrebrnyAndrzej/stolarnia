import Combine
import Foundation
import os

@MainActor
final class GlobalneMaterialyProjektuRepository:
    ObservableObject
{
    @Published private(set) var ustawienia:
        GlobalneMaterialyProjektu
    @Published private(set) var komunikatIntegralnosci:
        String?

    let projectID: String

    private let defaults: UserDefaults
    private let key: String
    private let backupKey: String

    init(
        projectID: String,
        defaults: UserDefaults = .standard
    ) {
        self.projectID = projectID
        self.defaults = defaults
        self.key =
            "GlobalneMaterialyProjektu.v1.\(projectID)"
        self.backupKey =
            "GlobalneMaterialyProjektu.v1.\(projectID).backup"

        let result = BezpiecznyMagazynJSON.wczytaj(
            GlobalneMaterialyProjektu.self,
            defaults: defaults,
            key: self.key,
            backupKey: self.backupKey,
            wartoscDomyslna:
                .domyslne(projectID: projectID)
        )

        self.ustawienia = result.wartosc
        self.komunikatIntegralnosci =
            result.komunikat
    }

    // MARK: - Aktualizacje

    func zaktualizuj(
        _ nowe: GlobalneMaterialyProjektu
    ) {
        var zapis = nowe
        zapis.dataAktualizacji = Date()
        ustawienia = zapis
        persist()
    }

    func ustawKorpus(
        _ korpus: MigawkaMaterialuGlobalnego
    ) {
        var updated = ustawienia
        updated.korpus = korpus
        updated.dataAktualizacji = Date()
        ustawienia = updated
        persist()
    }

    func ustawFront(
        _ front: MigawkaMaterialuGlobalnego
    ) {
        var updated = ustawienia
        updated.front = front
        updated.dataAktualizacji = Date()
        ustawienia = updated
        persist()
    }

    func ustawSystemSzuflad(
        _ system: SystemSzufladMigawka
    ) {
        var updated = ustawienia
        updated.systemSzuflad = system
        updated.dataAktualizacji = Date()
        ustawienia = updated
        persist()
    }

    func ustawSystemSzufladZMaterialu(
        _ material: MaterialStolarski
    ) {
        ustawSystemSzuflad(
            SystemSzufladMigawka(material: material)
        )
    }

    func ustawKorpusZMaterialu(
        _ material: MaterialStolarski
    ) {
        ustawKorpus(
            MigawkaMaterialuGlobalnego(material: material)
        )
    }

    func ustawFrontZMaterialu(
        _ material: MaterialStolarski
    ) {
        ustawFront(
            MigawkaMaterialuGlobalnego(material: material)
        )
    }

    func przywrocDomyslne() {
        ustawienia = .domyslne(projectID: projectID)
        persist()
    }

    // MARK: - Persystencja

    private func persist() {
        do {
            try BezpiecznyMagazynJSON.zapisz(
                ustawienia,
                defaults: defaults,
                key: key,
                backupKey: backupKey
            )
            komunikatIntegralnosci = nil
        } catch {
            komunikatIntegralnosci =
                "Nie udało się zapisać globalnych materiałów projektu: \(error.localizedDescription)"
            StolarniaLogger.zapis.error(
                "Persystencja GlobalneMaterialyProjektu: \(error.localizedDescription)"
            )
        }
    }
}
