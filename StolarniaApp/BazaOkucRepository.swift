import Combine
import Foundation
import os

@MainActor
final class BazaOkucRepository:
    ObservableObject
{
    @Published private(set) var okucia:
        [OkucieMeblowe] = []
    @Published private(set) var komunikatIntegralnosci:
        String?

    private let defaults:
        UserDefaults
    private let key =
        "stolarnia.baza.okuc.v1"
    private let backupKey =
        "stolarnia.baza.okuc.v1.backup"

    init(
        defaults:
            UserDefaults = .standard
    ) {
        self.defaults = defaults
        load()

        if okucia.isEmpty {
            seedExamples()
        }

        wykonajMigracjeKatalogu()
    }

    func addNew(
        type:
            TypOkuciaMeblowego = .zawias
    ) -> OkucieMeblowe {
        var item = OkucieMeblowe()
        item.typ = type
        item.nazwa =
            type.nazwa
        item.dataAktualizacji =
            Date()

        okucia.insert(
            item,
            at: 0
        )

        save()
        return item
    }

    func upsert(
        _ item:
            OkucieMeblowe
    ) {
        var updated = item
        updated.dataAktualizacji =
            Date()

        if let index =
            okucia.firstIndex(
                where: {
                    $0.id == item.id
                }
            ) {
            okucia[index] = updated
        } else {
            okucia.insert(
                updated,
                at: 0
            )
        }

        save()
    }

    func delete(
        id: UUID
    ) {
        okucia.removeAll {
            $0.id == id
        }

        save()
    }

    func merge(
        _ imported:
            [OkucieMeblowe]
    ) -> ImportOkucResult {
        var added = 0
        var updated = 0

        for item in imported {
            if let index =
                okucia.firstIndex(
                    where: {
                        $0.unikalnyKlucz
                        == item.unikalnyKlucz
                    }
                ) {
                var replacement = item
                replacement.id =
                    okucia[index].id
                okucia[index] =
                    replacement
                updated += 1
            } else {
                okucia.append(item)
                added += 1
            }
        }

        okucia.sort {
            $0.nazwa.localizedCaseInsensitiveCompare(
                $1.nazwa
            )
            == .orderedAscending
        }

        save()

        return ImportOkucResult(
            added: added,
            updated: updated
        )
    }


    @discardableResult
    func synchronizujKatalogSystemow() -> ImportOkucResult {
        var added = 0
        var updated = 0

        for imported in BazaOkucAkcesoriaSeeder.okucia {
            let index = okucia.firstIndex { existing in
                if let left = existing.profilAkcesoriumID,
                   let right = imported.profilAkcesoriumID
                {
                    return left.caseInsensitiveCompare(right) == .orderedSame
                }
                return existing.unikalnyKlucz == imported.unikalnyKlucz
            }

            if let index {
                let existing = okucia[index]
                var replacement = imported
                replacement.id = existing.id

                // Wycena firmy jest nadrzędna względem ceny startowej katalogu.
                replacement.cenaNetto = existing.cenaNetto
                replacement.vatProcent = existing.vatProcent
                replacement.rabatProcent = existing.rabatProcent
                replacement.aktywne = existing.aktywne
                replacement.poziomWyceny = existing.poziomWyceny
                replacement.dataAktualizacji = Date()

                okucia[index] = replacement
                updated += 1
            } else {
                okucia.append(imported)
                added += 1
            }
        }

        sortujIZapisz()
        return ImportOkucResult(added: added, updated: updated)
    }

    func reload() {
        load()
    }


    private func wykonajMigracjeKatalogu() {
        let migrationKey = "BazaOkuc.KatalogSystemow.version"
        guard defaults.integer(forKey: migrationKey)
                < BazaOkucAkcesoriaSeeder.migrationVersion
        else {
            return
        }

        _ = synchronizujKatalogSystemow()
        defaults.set(
            BazaOkucAkcesoriaSeeder.migrationVersion,
            forKey: migrationKey
        )
    }

    private func sortujIZapisz() {
        okucia.sort {
            if $0.typ != $1.typ {
                return $0.typ.nazwa < $1.typ.nazwa
            }
            return $0.nazwa.localizedCaseInsensitiveCompare($1.nazwa)
                == .orderedAscending
        }
        save()
    }

    private func load() {
        let result = BezpiecznyMagazynJSON.wczytaj(
            [OkucieMeblowe].self,
            defaults: defaults,
            key: key,
            backupKey: backupKey,
            wartoscDomyslna: []
        )

        okucia = result.wartosc
        komunikatIntegralnosci =
            result.komunikat
    }

    private func save() {
        do {
            try BezpiecznyMagazynJSON.zapisz(
                okucia,
                defaults: defaults,
                key: key,
                backupKey: backupKey
            )
            komunikatIntegralnosci = nil
        } catch {
            komunikatIntegralnosci =
                "Nie udało się zapisać bazy okuć: \(error.localizedDescription)"
            StolarniaLogger.zapis.error(
                "Nie udało się zapisać bazy okuć: \(error.localizedDescription)"
            )
        }
    }

    private func seedExamples() {
        okucia = [
            OkucieMeblowe(
                kod: "HINGE-110",
                nazwa: "Zawias puszkowy 110°",
                producent: "Przykład",
                dostawca: "Dostawca",
                typ: .zawias,
                jednostka: .sztuka,
                cenaNetto: 8.90,
                vatProcent: 23,
                rabatProcent: 0,
                iloscWOakowaniu: 1,
                system: "Clip-on",
                katOtwarciaStopnie: 110,
                dlugoscMM: 0,
                szerokoscMM: 0,
                wysokoscMM: 0,
                nosnoscKG: 0,
                gruboscPlytyOdMM: 16,
                gruboscPlytyDoMM: 22,
                poziomWyceny: .standard,
                aktywne: true,
                notatki: "",
                dataAktualizacji: Date()
            ),
            OkucieMeblowe(
                kod: "DRAWER-500",
                nazwa: "Prowadnica pełny wysuw 500 mm",
                producent: "Przykład",
                dostawca: "Dostawca",
                typ: .prowadnica,
                jednostka: .para,
                cenaNetto: 39.90,
                vatProcent: 23,
                rabatProcent: 0,
                iloscWOakowaniu: 1,
                system: "Soft close",
                katOtwarciaStopnie: 0,
                dlugoscMM: 500,
                szerokoscMM: 0,
                wysokoscMM: 0,
                nosnoscKG: 35,
                gruboscPlytyOdMM: 16,
                gruboscPlytyDoMM: 19,
                poziomWyceny: .standard,
                aktywne: true,
                notatki: "",
                dataAktualizacji: Date()
            )
        ]

        save()
    }
}

struct ImportOkucResult {
    let added: Int
    let updated: Int
}
