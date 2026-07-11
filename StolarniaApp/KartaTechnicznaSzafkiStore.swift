import DomainCore
import Foundation
import os

struct PowiazanieKartyLegacyV0681:
    Hashable,
    Sendable
{
    let templateCode: String
    let moduleName: String
    let moduleKey: String
}

enum KartaTechnicznaSzafkiStore {
    private static let currentKey =
        "stolarnia.karty.techniczne.szafek.v2"
    private static let backupKey =
        "stolarnia.karty.techniczne.szafek.v2.backup"
    private static let legacyKey =
        "stolarnia.karty.techniczne.szafek.v1"
    private static let statusKey =
        "stolarnia.karty.techniczne.szafek.integrityStatus"
    private static let schemaVersion = 3

    /// v0.68.1: renderery 2D/3D nie mogą dekodować całej bazy kart
    /// osobno dla każdego modułu. Pamięciowy indeks jest aktualizowany
    /// po każdym udanym zapisie i odczytywany pod blokadą.
    private final class CacheBox:
        @unchecked Sendable
    {
        private let lock = NSLock()
        private var cards:
            [KartaTechnicznaSzafki]?
        private var cardsByModuleKey:
            [String: KartaTechnicznaSzafki] = [:]
        private var cardsByDraftID:
            [UUID: KartaTechnicznaSzafki] = [:]

        func snapshot()
            -> [KartaTechnicznaSzafki]?
        {
            lock.lock()
            defer { lock.unlock() }
            return cards
        }

        func card(
            moduleKey: String
        ) -> KartaTechnicznaSzafki? {
            lock.lock()
            defer { lock.unlock() }
            return cardsByModuleKey[moduleKey]
        }

        func card(
            draftID: UUID
        ) -> KartaTechnicznaSzafki? {
            lock.lock()
            defer { lock.unlock() }
            return cardsByDraftID[draftID]
        }

        func replace(
            with value:
                [KartaTechnicznaSzafki]
        ) {
            var moduleIndex:
                [String: KartaTechnicznaSzafki] = [:]
            var draftIndex:
                [UUID: KartaTechnicznaSzafki] = [:]

            for card in value {
                if let current =
                    draftIndex[card.draftID],
                   current.dataAktualizacji
                    >= card.dataAktualizacji {
                    // Zachowujemy najnowszą wersję, zgodnie
                    // z dotychczasową semantyką card(for:).
                } else {
                    draftIndex[card.draftID] =
                        card
                }

                guard
                    let key =
                        card.kluczModulu?
                            .trimmingCharacters(
                                in:
                                    .whitespacesAndNewlines
                            ),
                    !key.isEmpty
                else {
                    continue
                }

                if let current =
                    moduleIndex[key],
                   current.dataAktualizacji
                    >= card.dataAktualizacji {
                    continue
                }

                moduleIndex[key] = card
            }

            lock.lock()
            cards = value
            cardsByModuleKey = moduleIndex
            cardsByDraftID = draftIndex
            lock.unlock()
        }
    }

    private static let cache =
        CacheBox()

    static func save(
        _ card: KartaTechnicznaSzafki
    ) {
        var all = load()
        var normalized = card
        normalized.wersjaSchematu = schemaVersion

        let moduleKey = normalized.kluczModulu?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        all.removeAll { existing in
            if existing.draftID == normalized.draftID {
                return true
            }

            guard let moduleKey,
                  !moduleKey.isEmpty
            else {
                return false
            }

            return existing.kluczModulu == moduleKey
        }

        all.append(normalized)
        persist(uporzadkuj(all))
    }

    static func card(
        forModuleKey moduleKey: String
    ) -> KartaTechnicznaSzafki? {
        let normalizedKey =
            moduleKey
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        guard !normalizedKey.isEmpty else {
            return nil
        }

        // Pierwsze wywołanie inicjalizuje pamięciowy indeks.
        // Kolejne odczyty z planu, elewacji i 3D są O(1)
        // i nie dotykają UserDefaults.
        _ = load()
        return cache.card(
            moduleKey:
                normalizedKey
        )
    }

    /// Wyszukiwanie zachowane wyłącznie dla migracji kart sprzed v0.54.0.
    /// Powiązane karty są pomijane, aby dwa identycznie nazwane moduły
    /// nie zaczęły współdzielić jednego dokumentu technicznego.
    static func card(
        templateCode: String,
        moduleName: String
    ) -> KartaTechnicznaSzafki? {
        load()
            .filter {
                $0.kluczModulu == nil
                && $0.kodSzablonuZrodlowego == templateCode
                && $0.nazwa == moduleName
            }
            .max {
                $0.dataAktualizacji < $1.dataAktualizacji
            }
    }

    static func card(
        for draftID: UUID
    ) -> KartaTechnicznaSzafki? {
        _ = load()
        return cache.card(
            draftID: draftID
        )
    }

    /// Wiąże dokładnie tę kartę, która została utworzona w konfiguratorze,
    /// z identyfikatorem zapisanej instancji mebla.
    @discardableResult
    static func powiazKarte(
        draftID: UUID,
        zKluczemModulu moduleKey: String
    ) -> KartaTechnicznaSzafki? {
        let normalizedKey = moduleKey.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !normalizedKey.isEmpty else {
            return nil
        }

        var all = load()

        if let existingIndex = all.firstIndex(
            where: {
                $0.kluczModulu == normalizedKey
            }
        ) {
            return all[existingIndex]
        }

        guard let index = all.firstIndex(
            where: {
                $0.draftID == draftID
            }
        ) else {
            return nil
        }

        all[index].kluczModulu = normalizedKey
        all[index].wersjaSchematu = schemaVersion
        all[index].dataAktualizacji = Date()

        let result = all[index]
        persist(uporzadkuj(all))
        return result
    }

    /// Migracja awaryjna dla modułów zapisanych przed dodaniem klucza.
    /// Najstarsza niepowiązana karta jest przypisywana do najstarszego
    /// pasującego modułu. Wywołanie kolejno dla modułów zachowuje relację 1:1.
    @discardableResult
    static func powiazNajstarszaKarteLegacy(
        templateCode: String,
        moduleName: String,
        zKluczemModulu moduleKey: String
    ) -> KartaTechnicznaSzafki? {
        if let existing = card(forModuleKey: moduleKey) {
            return existing
        }

        var all = load()
        let candidates = all.indices
            .filter { index in
                all[index].kluczModulu == nil
                && all[index].kodSzablonuZrodlowego == templateCode
                && all[index].nazwa == moduleName
            }
            .sorted {
                all[$0].dataAktualizacji
                    < all[$1].dataAktualizacji
            }

        guard let index = candidates.first else {
            return nil
        }

        all[index].kluczModulu = moduleKey
        all[index].wersjaSchematu = schemaVersion
        all[index].dataAktualizacji = Date()

        let result = all[index]
        persist(uporzadkuj(all))
        return result
    }


    /// v0.68.1: zbiorcze powiązanie kart legacy.
    ///
    /// Poprzednia implementacja dla każdego modułu ponownie dekodowała,
    /// sortowała i czasem zapisywała całą bazę JSON. Przy większej kuchni
    /// blokowało to MainActor przed pierwszym odświeżeniem ekranu.
    /// Ta metoda wykonuje jeden odczyt i najwyżej jeden zapis.
    @discardableResult
    static func powiazNajstarszeKartyLegacyV0681(
        _ requests:
            [PowiazanieKartyLegacyV0681]
    ) -> Int {
        guard !requests.isEmpty else {
            return 0
        }

        var all = load()
        var knownModuleKeys =
            Set(
                all.compactMap {
                    $0.kluczModulu?
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        )
                }
                .filter {
                    !$0.isEmpty
                }
            )

        var available:
            [String: [Int]] = [:]

        for index in all.indices {
            guard
                all[index].kluczModulu == nil
            else {
                continue
            }

            let key =
                legacyCandidateKey(
                    templateCode:
                        all[index]
                            .kodSzablonuZrodlowego
                        ?? "",
                    moduleName:
                        all[index].nazwa
                )
            available[key, default: []]
                .append(index)
        }

        for key in Array(
            available.keys
        ) {
            available[key]?.sort {
                all[$0].dataAktualizacji
                < all[$1].dataAktualizacji
            }
        }

        var cursors:
            [String: Int] = [:]
        var changed = 0

        for request in requests {
            let moduleKey =
                request.moduleKey
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            guard
                !moduleKey.isEmpty,
                !knownModuleKeys
                    .contains(moduleKey)
            else {
                continue
            }

            let candidateKey =
                legacyCandidateKey(
                    templateCode:
                        request.templateCode,
                    moduleName:
                        request.moduleName
                )
            let cursor =
                cursors[candidateKey, default: 0]

            guard
                let candidates =
                    available[candidateKey],
                cursor < candidates.count
            else {
                continue
            }

            let cardIndex =
                candidates[cursor]
            cursors[candidateKey] =
                cursor + 1

            all[cardIndex].kluczModulu =
                moduleKey
            all[cardIndex].wersjaSchematu =
                schemaVersion
            all[cardIndex].dataAktualizacji =
                Date()

            knownModuleKeys.insert(
                moduleKey
            )
            changed += 1
        }

        guard changed > 0 else {
            return 0
        }

        persist(
            uporzadkuj(all)
        )
        return changed
    }




    /// v0.69.1: zbiorczo aktualizuje produkcyjne panele skosu.
    ///
    /// Operacja wykonuje jeden odczyt i najwyżej jeden zapis całej bazy,
    /// dzięki czemu nie blokuje renderowania przy większej liczbie modułów.
    @discardableResult
    static func synchronizujPaneleSkosuV0691(
        room: RoomDefinition,
        assemblies: [FurnitureAssembly],
        at date: Date = Date()
    ) -> Int {
        guard !assemblies.isEmpty else {
            return 0
        }

        var all = load()
        var indexByModuleKey:
            [String: Int] = [:]

        for index in all.indices {
            guard
                let key =
                    all[index]
                        .kluczModulu?
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        ),
                !key.isEmpty
            else {
                continue
            }

            indexByModuleKey[key] = index
        }

        var changed = 0

        for assembly in assemblies {
            let moduleKey =
                KonfiguracjaFunkcjonalnaModuluV068Resolver
                    .kluczModulu(
                        assembly.id
                    )
            let newReport =
                PaneleProdukcyjneSkosuV0691
                    .raport(
                        dla: assembly,
                        room: room,
                        at: date
                    )

            if let existingIndex =
                indexByModuleKey[moduleKey] {
                let oldReport =
                    all[existingIndex]
                        .raportPaneliSkosuV0691

                guard !raportyPaneliSkosuV0691SaRownowazne(
                    oldReport,
                    newReport
                ) else {
                    continue
                }

                all[existingIndex]
                    .raportPaneliSkosuV0691 =
                        newReport
                all[existingIndex]
                    .wersjaSchematu =
                        schemaVersion
                all[existingIndex]
                    .dataAktualizacji =
                        date
                KartaTechnicznaSzafkiBuilder
                    .applySlopeCutAngles(
                        to: &all[existingIndex]
                    )
                changed += 1
                continue
            }

            guard let newReport else {
                continue
            }

            var card =
                KartaTechnicznaSzafki(
                    draftID: UUID()
                )
            card.nazwa = assembly.name
            card.szerokoscMM =
                assembly.size.width.rawValue
            card.wysokoscMM =
                assembly.size.height.rawValue
            card.glebokoscMM =
                assembly.size.depth.rawValue
            card.kluczModulu = moduleKey
            card.wersjaSchematu =
                schemaVersion
            card.raportPaneliSkosuV0691 =
                newReport
            card.dataAktualizacji = date
            KartaTechnicznaSzafkiBuilder
                .applySlopeCutAngles(to: &card)

            all.append(card)
            indexByModuleKey[moduleKey] =
                all.count - 1
            changed += 1
        }

        guard changed > 0 else {
            return 0
        }

        persist(
            uporzadkuj(all)
        )
        return changed
    }

    private static func raportyPaneliSkosuV0691SaRownowazne(
        _ left:
            RaportPaneliSkosuV0691?,
        _ right:
            RaportPaneliSkosuV0691?
    ) -> Bool {
        switch (left, right) {
        case (nil, nil):
            return true
        case let (.some(lhs), .some(rhs)):
            return lhs.wersjaSchematu
                    == rhs.wersjaSchematu
                && lhs.profilID
                    == rhs.profilID
                && lhs.assemblyID
                    == rhs.assemblyID
                && lhs.panele
                    == rhs.panele
                && lhs.ostrzezenia
                    == rhs.ostrzezenia
        default:
            return false
        }
    }


    @discardableResult
    static func duplikujKarteV065(
        zKluczaModulu sourceModuleKey: String,
        doKluczaModulu targetModuleKey: String,
        nowaNazwa: String
    ) -> KartaTechnicznaSzafki? {
        guard var card = card(forModuleKey: sourceModuleKey) else {
            return nil
        }

        card.id = UUID()
        card.draftID = UUID()
        card.numerSzafki = ""
        card.nazwa = nowaNazwa
        card.kluczModulu = targetModuleKey
        card.wersjaSchematu = schemaVersion
        card.raportPaneliSkosuV0691 = nil
        card.dataAktualizacji = Date()

        for index in card.punktyWiercenia.indices {
            card.punktyWiercenia[index].id = UUID()
        }

        if var elements = card.elementy {
            for index in elements.indices {
                elements[index].id = UUID()
                for pointIndex in elements[index].punktyWiercenia.indices {
                    elements[index].punktyWiercenia[pointIndex].id = UUID()
                }
            }
            card.elementy = elements
        }

        if var accessories = card.akcesoria {
            for index in accessories.indices {
                accessories[index].id = UUID()
                accessories[index].dataDodania = Date()
            }
            card.akcesoria = accessories
        }

        if var drawers = card.szuflady {
            for index in drawers.indices {
                drawers[index].id = UUID()
            }
            card.szuflady = drawers
        }

        save(card)
        return card
    }

    static func usunKarte(
        forDraftID draftID: UUID
    ) {
        var all = load()
        let oldCount = all.count
        all.removeAll {
            $0.draftID == draftID
        }

        guard all.count != oldCount else {
            return
        }

        persist(all)
    }

    static func usunKarte(
        forModuleKey moduleKey: String
    ) {
        var all = load()
        let oldCount = all.count
        all.removeAll {
            $0.kluczModulu == moduleKey
        }

        guard all.count != oldCount else {
            return
        }

        persist(all)
    }

    static func load()
        -> [KartaTechnicznaSzafki]
    {
        if let cached =
            cache.snapshot()
        {
            return cached
        }

        let defaults =
            UserDefaults.standard

        if defaults.data(
            forKey: currentKey
        ) != nil
            || defaults.data(
                forKey: backupKey
            ) != nil
        {
            let result =
                BezpiecznyMagazynJSON
                    .wczytaj(
                        [KartaTechnicznaSzafki].self,
                        defaults: defaults,
                        key: currentKey,
                        backupKey:
                            backupKey,
                        wartoscDomyslna: []
                    )

            defaults.set(
                result.komunikat,
                forKey: statusKey
            )

            let normalized =
                uporzadkuj(
                    result.wartosc
                )
            cache.replace(
                with: normalized
            )
            return normalized
        }

        guard
            let legacyData =
                defaults.data(
                    forKey: legacyKey
                )
        else {
            cache.replace(with: [])
            return []
        }

        do {
            var legacyCards =
                try JSONDecoder()
                    .decode(
                        [KartaTechnicznaSzafki].self,
                        from:
                            legacyData
                    )

            for index
                in legacyCards.indices {
                legacyCards[index]
                    .wersjaSchematu =
                    schemaVersion
            }

            let migrated =
                uporzadkuj(
                    legacyCards
                )
            persist(migrated)
            return migrated
        } catch {
            defaults.set(
                "Nie udało się odczytać kart technicznych z wersji v1: \(error.localizedDescription)",
                forKey: statusKey
            )
            cache.replace(with: [])
            return []
        }
    }

    static var ostatniKomunikatIntegralnosci:
        String?
    {
        UserDefaults.standard.string(
            forKey: statusKey
        )
    }

    private static func legacyCandidateKey(
        templateCode: String,
        moduleName: String
    ) -> String {
        templateCode
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
        + "\u{1F}"
        + moduleName
            .trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
    }

    private static func persist(
        _ cards: [KartaTechnicznaSzafki]
    ) {
        let normalized =
            uporzadkuj(cards)

        do {
            try BezpiecznyMagazynJSON
                .zapisz(
                    normalized,
                    defaults: .standard,
                    key: currentKey,
                    backupKey: backupKey
                )
            cache.replace(
                with: normalized
            )
        } catch {
            UserDefaults.standard.set(
                "Nie udało się zapisać kart technicznych: \(error.localizedDescription)",
                forKey: statusKey
            )
            StolarniaLogger.zapis.error(
                "Nie udało się zapisać kart technicznych: \(error.localizedDescription)"
            )
        }
    }

    private static func uporzadkuj(
        _ cards: [KartaTechnicznaSzafki]
    ) -> [KartaTechnicznaSzafki] {
        var result: [String: KartaTechnicznaSzafki] = [:]

        for var card in cards {
            card.wersjaSchematu = max(
                card.wersjaSchematu ?? 0,
                schemaVersion
            )

            let key: String
            if let moduleKey = card.kluczModulu,
               !moduleKey.isEmpty
            {
                key = "module:\(moduleKey)"
            } else {
                key = "draft:\(card.draftID.uuidString)"
            }

            if let existing = result[key],
               existing.dataAktualizacji
                    >= card.dataAktualizacji
            {
                continue
            }

            result[key] = card
        }

        return result.values.sorted {
            if $0.numerSzafki != $1.numerSzafki {
                return $0.numerSzafki
                    .localizedStandardCompare(
                        $1.numerSzafki
                    ) == .orderedAscending
            }

            return $0.dataAktualizacji
                < $1.dataAktualizacji
        }
    }
}
