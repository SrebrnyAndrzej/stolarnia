import Combine
import Foundation
import os

@MainActor
final class GlobalneMaterialyPomieszczeniaRepository:
    ObservableObject
{
    @Published private(set) var ustawienia:
        GlobalneMaterialyPomieszczenia
    @Published private(set) var komunikatIntegralnosci:
        String?

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
        self.key =
            "GlobalneMaterialyPomieszczenia.v1.\(roomID)"
        self.backupKey =
            "GlobalneMaterialyPomieszczenia.v1.\(roomID).backup"

        let result = BezpiecznyMagazynJSON.wczytaj(
            GlobalneMaterialyPomieszczenia.self,
            defaults: defaults,
            key: self.key,
            backupKey: self.backupKey,
            wartoscDomyslna:
                .domyslne(roomID: roomID)
        )

        self.ustawienia = result.wartosc
        self.komunikatIntegralnosci =
            result.komunikat
    }

    func zapisz(
        korpus: MaterialStolarski,
        front: MaterialStolarski
    ) {
        zapisz(
            korpus: MigawkaMaterialuGlobalnego(material: korpus),
            front: MigawkaMaterialuGlobalnego(material: front)
        )
    }

    func zapisz(
        korpus: MigawkaMaterialuGlobalnego,
        front: MigawkaMaterialuGlobalnego
    ) {
        ustawienia = GlobalneMaterialyPomieszczenia(
            roomID: roomID,
            korpus: korpus,
            front: front,
            dataAktualizacji: Date()
        )
        persist()
    }

    func przywrocDomyslne() {
        ustawienia = .domyslne(roomID: roomID)
        persist()
    }

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
                "Nie udało się zapisać globalnych materiałów: \(error.localizedDescription)"
            StolarniaLogger.zapis.error(
                "Nie udało się zapisać globalnych materiałów pomieszczenia: \(error.localizedDescription)"
            )
        }
    }
}
