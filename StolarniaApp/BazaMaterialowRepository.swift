import Combine
import Foundation
import os

@MainActor
final class BazaMaterialowRepository:
    ObservableObject
{
    @Published private(set) var materialy:
        [MaterialStolarski] = []
    @Published private(set) var komunikatIntegralnosci:
        String?

    private let defaults:
        UserDefaults
    private let key =
        "BazaMaterialow.v1"
    private let backupKey =
        "BazaMaterialow.v1.backup"

    init(
        defaults:
            UserDefaults = .standard
    ) {
        self.defaults = defaults

        let result = BezpiecznyMagazynJSON.wczytaj(
            [MaterialStolarski].self,
            defaults: defaults,
            key: key,
            backupKey: backupKey,
            wartoscDomyslna:
                Self.przykladoweMaterialy
        )
        self.materialy = result.wartosc
        self.komunikatIntegralnosci =
            result.komunikat

        wykonajMigracjeKatalogow()
    }

    @discardableResult
    func synchronizujCennikAkcesoriow()
        -> ImportMaterialowRaport
    {
        scalSystemowe(
            BazaMaterialowAkcesoriaSeeder
                .materialy
        )
    }

    @discardableResult
    func synchronizujWzornikiPlyt()
        -> ImportMaterialowRaport
    {
        scalSystemowe(
            BazaMaterialowWzornikiSeeder
                .materialy
        )
    }

    @discardableResult
    func synchronizujCennikPlyt()
        -> ImportMaterialowRaport
    {
        scalSystemowe(
            BazaMaterialowWzornikiSeeder
                .materialy,
            uzupelnijCenyZerowe:
                true
        )
    }

    func dodaj(
        _ material:
            MaterialStolarski
    ) {
        materialy.append(material)
        sortuj()
        zapisz()
    }

    func aktualizuj(
        _ material:
            MaterialStolarski
    ) {
        guard let index =
            materialy.firstIndex(
                where: {
                    $0.id == material.id
                }
            )
        else {
            dodaj(material)
            return
        }

        materialy[index] = material
        sortuj()
        zapisz()
    }

    func usun(
        id: UUID
    ) {
        materialy.removeAll {
            $0.id == id
        }
        zapisz()
    }

    func ustawAktywnosc(
        id: UUID,
        aktywny: Bool
    ) {
        guard let index =
            materialy.firstIndex(
                where: {
                    $0.id == id
                }
            )
        else {
            return
        }

        materialy[index]
            .aktywny = aktywny
        materialy[index]
            .dataAktualizacji = Date()
        zapisz()
    }

    func zastapWszystkie(
        _ nowe:
            [MaterialStolarski]
    ) {
        materialy = nowe
        sortuj()
        zapisz()
    }

    func scal(
        _ importowane:
            [MaterialStolarski]
    ) -> ImportMaterialowRaport {
        var raport =
            ImportMaterialowRaport()

        for material in importowane {
            let kod =
                material.kod
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            guard !kod.isEmpty else {
                raport.pominiete += 1
                raport.bledy.append(
                    "Pominięto materiał bez kodu: \(material.nazwa)"
                )
                continue
            }

            if let index =
                materialy.firstIndex(
                    where: {
                        $0.kod
                            .caseInsensitiveCompare(
                                kod
                            )
                        == .orderedSame
                        && $0.dostawca
                            .caseInsensitiveCompare(
                                material.dostawca
                            )
                        == .orderedSame
                    }
                ) {
                var nowy = material
                nowy.id =
                    materialy[index].id
                nowy.dataAktualizacji =
                    Date()
                materialy[index] = nowy
                raport.zaktualizowane += 1
            } else {
                var nowy = material
                nowy.dataAktualizacji =
                    Date()
                materialy.append(nowy)
                raport.dodane += 1
            }
        }

        sortuj()
        zapisz()
        return raport
    }


    private func scalSystemowe(
        _ importowane:
            [MaterialStolarski],
        uzupelnijCenyZerowe:
            Bool = false
    ) -> ImportMaterialowRaport {
        var raport = ImportMaterialowRaport()

        for material in importowane {
            let index = materialy.firstIndex { isSameCatalogItem($0, material) }

            if let index {
                let existing = materialy[index]
                var replacement = material
                replacement.id = existing.id

                // Ceny i dostępność należą do firmy. Zwykła synchronizacja
                // nigdy nie nadpisuje wyceny. Migracja cennika może jedynie
                // uzupełnić cenę równą zero; każda wartość dodatnia pozostaje
                // nadrzędną ceną firmy.
                if uzupelnijCenyZerowe,
                   existing.cenaNetto <= 0,
                   material.cenaNetto > 0 {
                    replacement.cenaNetto =
                        material.cenaNetto
                } else {
                    replacement.cenaNetto =
                        existing.cenaNetto
                }

                replacement.vatProcent = existing.vatProcent
                replacement.rabatProcent = existing.rabatProcent
                replacement.aktywny = existing.aktywny
                replacement.dataAktualizacji = Date()

                materialy[index] = replacement
                raport.zaktualizowane += 1
            } else {
                var inserted = material
                inserted.dataAktualizacji = Date()
                materialy.append(inserted)
                raport.dodane += 1
            }
        }

        sortuj()
        zapisz()
        return raport
    }

    private func isSameCatalogItem(
        _ lhs: MaterialStolarski,
        _ rhs: MaterialStolarski
    ) -> Bool {
        if let leftProfile = lhs.profilAkcesoriumID,
           let rightProfile = rhs.profilAkcesoriumID
        {
            return leftProfile.caseInsensitiveCompare(rightProfile) == .orderedSame
        }

        if let leftCode = lhs.kodProducenta,
           let rightCode = rhs.kodProducenta,
           lhs.producent.caseInsensitiveCompare(rhs.producent) == .orderedSame
        {
            return leftCode.caseInsensitiveCompare(rightCode) == .orderedSame
                && (lhs.struktura ?? "").caseInsensitiveCompare(rhs.struktura ?? "") == .orderedSame
        }

        return lhs.kod.caseInsensitiveCompare(rhs.kod) == .orderedSame
            && lhs.dostawca.caseInsensitiveCompare(rhs.dostawca) == .orderedSame
    }

    private func wykonajMigracjeKatalogow() {
        let fittingsKey = "BazaMaterialow.CennikOkuc.version"
        if defaults.integer(forKey: fittingsKey)
            < BazaMaterialowAkcesoriaSeeder.migrationVersion
        {
            _ = synchronizujCennikAkcesoriow()
            defaults.set(
                BazaMaterialowAkcesoriaSeeder.migrationVersion,
                forKey: fittingsKey
            )
        }

        let swatchesKey =
            "BazaMaterialow.WzornikiPlyt.version"
        if defaults.integer(
            forKey: swatchesKey
        ) < BazaMaterialowWzornikiSeeder
            .migrationVersion {
            _ = synchronizujWzornikiPlyt()
            defaults.set(
                BazaMaterialowWzornikiSeeder
                    .migrationVersion,
                forKey: swatchesKey
            )
        }

        let boardPricesKey =
            "BazaMaterialow.CennikPlyt.version"
        if defaults.integer(
            forKey: boardPricesKey
        ) < CennikRynkowyPlyt
            .migrationVersion {
            _ = synchronizujCennikPlyt()
            defaults.set(
                CennikRynkowyPlyt
                    .migrationVersion,
                forKey: boardPricesKey
            )
        }
    }

    func przywrocPrzykladowe() {
        materialy =
            Self.przykladoweMaterialy
        sortuj()
        zapisz()
    }

    private func sortuj() {
        materialy.sort {
            if $0.typ != $1.typ {
                return $0.typ.nazwa
                    < $1.typ.nazwa
            }

            return $0.nazwa
                .localizedCaseInsensitiveCompare(
                    $1.nazwa
                )
                == .orderedAscending
        }
    }

    private func zapisz() {
        do {
            try BezpiecznyMagazynJSON.zapisz(
                materialy,
                defaults: defaults,
                key: key,
                backupKey: backupKey
            )
            komunikatIntegralnosci = nil
        } catch {
            komunikatIntegralnosci =
                "Nie udało się zapisać bazy materiałów: \(error.localizedDescription)"
            StolarniaLogger.zapis.error(
                "Nie udało się zapisać bazy materiałów: \(error.localizedDescription)"
            )
        }
    }

    static let przykladoweMaterialy:
        [MaterialStolarski] = [
            MaterialStolarski(
                kod: "KORPUS-18-BIALY",
                nazwa: "Płyta korpusowa biała",
                producent: "Przykład",
                dostawca: "Dostawca lokalny",
                typ: .plytaLaminowana,
                dekor: "Biały",
                gruboscMM: 18,
                szerokoscArkuszaMM: 2800,
                wysokoscArkuszaMM: 2070,
                jednostka: .sztuka,
                cenaNetto: 285,
                vatProcent: 23,
                rabatProcent: 0,
                kierunekDekoru: false,
                kolorHEX: "#F5F5F5",
                notatki: ""
            ),
            MaterialStolarski(
                kod: "HDF-3-POPIEL",
                nazwa: "HDF jasny popiel",
                producent: "Przykład",
                dostawca: "Dostawca lokalny",
                typ: .hdf,
                dekor: "Jasny popiel",
                gruboscMM: 3,
                szerokoscArkuszaMM: 2800,
                wysokoscArkuszaMM: 2070,
                jednostka: .sztuka,
                cenaNetto: 72,
                vatProcent: 23,
                rabatProcent: 0,
                kierunekDekoru: false,
                kolorHEX: "#D7D7D7",
                notatki: ""
            ),
            MaterialStolarski(
                kod: "OBRZEZE-1-BIALY",
                nazwa: "Obrzeże ABS 1 mm białe",
                producent: "Przykład",
                dostawca: "Dostawca lokalny",
                typ: .obrzeze,
                dekor: "Biały",
                gruboscMM: 1,
                szerokoscArkuszaMM: 0,
                wysokoscArkuszaMM: 0,
                jednostka: .metrBiezacy,
                cenaNetto: 2.40,
                vatProcent: 23,
                rabatProcent: 0,
                kierunekDekoru: false,
                kolorHEX: "#F5F5F5",
                notatki: ""
            )
        ]
}
