import Combine
import Foundation
import os

@MainActor
final class UstawieniaStolarniRepository:
    ObservableObject
{
    @Published private(set) var ustawienia:
        UstawieniaStolarni

    private let defaults:
        UserDefaults
    private let key =
        "UstawieniaStolarni.v1"
    private let backupKey =
        "UstawieniaStolarni.v1.backup"

    private static let log =
        Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "StolarniaApp",
            category: "UstawieniaStolarniRepository"
        )

    init(
        defaults:
            UserDefaults = .standard
    ) {
        self.defaults = defaults
        let wynik = BezpiecznyMagazynJSON.wczytaj(
            UstawieniaStolarni.self,
            defaults: defaults,
            key: "UstawieniaStolarni.v1",
            backupKey: "UstawieniaStolarni.v1.backup",
            wartoscDomyslna: .domyslne
        )
        if let komunikat = wynik.komunikat {
            Self.log.warning("\(komunikat)")
        }
        self.ustawienia = wynik.wartosc
    }

    func zapisz(
        _ noweUstawienia:
            UstawieniaStolarni
    ) throws {
        try BezpiecznyMagazynJSON.zapisz(
            noweUstawienia,
            defaults: defaults,
            key: key,
            backupKey: backupKey
        )
        ustawienia = noweUstawienia
    }

    func przywrocDomyslne() {
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: backupKey)
        ustawienia = .domyslne
    }

    func odswiez() {
        let wynik = BezpiecznyMagazynJSON.wczytaj(
            UstawieniaStolarni.self,
            defaults: defaults,
            key: key,
            backupKey: backupKey,
            wartoscDomyslna: .domyslne
        )
        if let komunikat = wynik.komunikat {
            Self.log.warning("\(komunikat)")
        }
        ustawienia = wynik.wartosc
    }

    @MainActor
    static func aktualne(
        defaults:
            UserDefaults = .standard
    ) -> UstawieniaStolarni {
        BezpiecznyMagazynJSON.wczytaj(
            UstawieniaStolarni.self,
            defaults: defaults,
            key: "UstawieniaStolarni.v1",
            backupKey: "UstawieniaStolarni.v1.backup",
            wartoscDomyslna: .domyslne
        ).wartosc
    }
}
