import Combine
import DomainCore
import Foundation
import Persistence

struct SugerowanePolozenieModulu: Sendable {
    let offsetAlongWall: Millimeters
    let offsetFromWall: Millimeters
    let bottomOffset: Millimeters
    let maximumWidth: Millimeters
    let requiredAnchoringMode: FurnitureAnchoringMode?
    let requiredRunKind: KitchenRunKindV015?
    let rightEdgeAnchor: Millimeters?

    init(
        offsetAlongWall: Millimeters,
        offsetFromWall: Millimeters,
        bottomOffset: Millimeters,
        maximumWidth: Millimeters,
        requiredAnchoringMode: FurnitureAnchoringMode?,
        requiredRunKind: KitchenRunKindV015? = nil,
        rightEdgeAnchor: Millimeters? = nil
    ) {
        self.offsetAlongWall = offsetAlongWall
        self.offsetFromWall = offsetFromWall
        self.bottomOffset = bottomOffset
        self.maximumWidth = maximumWidth
        self.requiredAnchoringMode = requiredAnchoringMode
        self.requiredRunKind = requiredRunKind
        self.rightEdgeAnchor = rightEdgeAnchor
    }
}

struct MigawkaPolozeniaModuluV064: Sendable {
    let furnitureID: FurnitureAssemblyID
    let placement: FurniturePlacement
}

struct OperacjaPolozeniaModulowV064: Sendable {
    let nazwa: String
    let przed: [MigawkaPolozeniaModuluV064]
    let po: [MigawkaPolozeniaModuluV064]
}

@MainActor
final class MeblePomieszczeniaViewModel: ObservableObject {
    @Published private(set) var templates: [FurnitureTemplate] = []
    @Published private(set) var storedAssemblies: [StoredFurnitureAssembly] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var lastCreatedAssemblyID: FurnitureAssemblyID?
    @Published private(set) var renderRevision = 0
    @Published var errorMessage: String?

    let roomID: RoomID

    private let repositories: MebleRepositoryContainer
    private let minimumAdjacentModuleWidth: Millimeters = 150

    // Task #93: O(1) lookup zamiast O(N) .first { } scan.
    // Aktualizowany po każdym przypisaniu storedAssemblies.
    private var _assemblyByID: [FurnitureAssemblyID: StoredFurnitureAssembly] = [:]

    private func rebuildAssemblyIndex() {
        _assemblyByID = Dictionary(
            storedAssemblies.map { ($0.id, $0) },
            uniquingKeysWith: { _, last in last }
        )
    }

    init(
        roomID: RoomID,
        repositories: MebleRepositoryContainer
    ) {
        self.roomID = roomID
        self.repositories = repositories
    }

    var assemblies: [FurnitureAssembly] {
        storedAssemblies.map(\.assembly)
    }

    func saveCustomTemplateV020(
        draft: FurnitureCreatorDraftV018
    ) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            let mapped =
                try FurnitureCreatorTemplateMapperV020.make(
                    from: draft
                )

            try await repositories.templateRepository.save(
                mapped.template
            )

            let sidecar =
                try FurnitureTechnicalSidecarRepositoryV020()
            try await sidecar.save(
                mapped.specification
            )

            templates =
                try await repositories.templateRepository
                    .fetchAll()

            return true
        } catch {
            errorMessage =
                "Nie udało się zapisać własnego szablonu: "
                + error.localizedDescription
            return false
        }
    }

    func load() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await repositories.templateRepository
                .installCurrentSystemTemplates()

            let kitchenTemplatesV0143 = try StandardKitchenTemplatesV0143.make()
            try await repositories.templateRepository.installSystemTemplates(
                kitchenTemplatesV0143
            )

            let finishingTemplatesV015 =
                try StandardKitchenFinishingTemplatesV015.make()
            try await repositories.templateRepository.installSystemTemplates(
                finishingTemplatesV015
            )

            let furnitureTemplatesV077 =
                try StandardFurnitureModuleCatalogV077
                    .make()
            try await repositories.templateRepository.installSystemTemplates(
                furnitureTemplatesV077
            )

            async let loadedTemplates = repositories.templateRepository.fetchAll()
            async let loadedAssemblies = repositories.assemblyRepository.fetchAll(
                roomID: roomID
            )

            let fetchedTemplates = try await loadedTemplates
            let fetchedAssemblies = try await loadedAssemblies

            templates = fetchedTemplates
            let normalizedAssemblies =
                try await normalizeLegacyAssemblies(
                    fetchedAssemblies,
                    templates: fetchedTemplates
                )
            storedAssemblies =
                normalizedAssemblies
            rebuildAssemblyIndex()
            renderRevision &+= 1

            // v0.68.1: najpierw publikujemy wczytane meble,
            // aby plan nie pozostawał na "0 modułów" podczas migracji kart.
            await Task.yield()

            powiazLegacyKartyTechniczne(
                dla: normalizedAssemblies,
                templates:
                    fetchedTemplates
            )
            renderRevision &+= 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }


    /// Aktualizuje produkcyjne kontury paneli dla modułów stojących
    /// pod profilem skosu. Zapis jest zbiorczy i nie zmienia geometrii mebli.
    @discardableResult
    func synchronizujPaneleSkosuV0691(
        room: RoomDefinition
    ) -> Int {
        KartaTechnicznaSzafkiStore
            .synchronizujPaneleSkosuV0691(
                room: room,
                assemblies: assemblies
            )
    }


    private func normalizeLegacyAssemblies(
        _ values: [StoredFurnitureAssembly],
        templates: [FurnitureTemplate]
    ) async throws -> [StoredFurnitureAssembly] {
        var normalized: [StoredFurnitureAssembly] = []
        normalized.reserveCapacity(values.count)

        for stored in values {
            guard var placement = stored.assembly.placement,
                  let templateID = stored.assembly.templateID,
                  let template = templates.first(where: { $0.id == templateID }) else {
                normalized.append(stored)
                continue
            }

            let expectedAnchoring = anchoringMode(for: template)
            var didChange = false

            if expectedAnchoring == .wallMounted {
                if placement.anchoringMode != .wallMounted {
                    placement.anchoringMode = .wallMounted
                    didChange = true
                }

                // Starsze rekordy mogły zapisać 1,4 zamiast 1400 mm.
                // Korekta dotyczy wyłącznie modułów wiszących i wartości
                // odpowiadających metrom wpisanym do pola milimetrowego.
                let rawBottomOffset = placement.bottomOffset.rawValue
                if rawBottomOffset > 0, rawBottomOffset < 10 {
                    placement.bottomOffset = Millimeters(rawBottomOffset * 1000)
                    didChange = true
                }
            } else if expectedAnchoring == .builtIn,
                      placement.anchoringMode == .floorStanding {
                placement.anchoringMode = .builtIn
                didChange = true
            }

            guard didChange else {
                normalized.append(stored)
                continue
            }

            var assembly = stored.assembly
            assembly.placement = placement

            let updated = StoredFurnitureAssembly(
                roomID: stored.roomID,
                assembly: assembly,
                parameters: stored.parameters,
                createdAt: stored.createdAt,
                updatedAt: Date()
            )

            try await repositories.assemblyRepository.save(updated)
            normalized.append(updated)
        }

        return normalized
    }


    private func powiazLegacyKartyTechniczne(
        dla assemblies:
            [StoredFurnitureAssembly],
        templates:
            [FurnitureTemplate]
    ) {
        let sortedAssemblies =
            assemblies.sorted {
                $0.createdAt
                < $1.createdAt
            }

        var requests:
            [PowiazanieKartyLegacyV0681] = []
        requests.reserveCapacity(
            sortedAssemblies.count
        )

        for stored in sortedAssemblies {
            guard
                let templateID =
                    stored.assembly
                        .templateID,
                let template =
                    templates.first(
                        where: {
                            $0.id
                            == templateID
                        }
                    )
            else {
                continue
            }

            let moduleKey =
                StabilnyKluczDomenowy
                    .utworz(
                        dla: stored.id,
                        prefiks:
                            "furniture"
                    )

            requests.append(
                PowiazanieKartyLegacyV0681(
                    templateCode:
                        template.code,
                    moduleName:
                        stored.assembly
                            .name,
                    moduleKey:
                        moduleKey
                )
            )
        }

        KartaTechnicznaSzafkiStore
            .powiazNajstarszeKartyLegacyV0681(
                requests
            )
    }



    func zastosujGlobalneMaterialy(
        _ ustawienia:
            GlobalneMaterialyPomieszczenia
    ) {
        for stored in storedAssemblies {
            guard
                let template = template(
                    for: stored
                )
            else {
                continue
            }

            let moduleKey =
                StabilnyKluczDomenowy.utworz(
                    dla: stored.id,
                    prefiks: "furniture"
                )

            var card =
                KartaTechnicznaSzafkiStore
                    .card(
                        forModuleKey:
                            moduleKey
                    )
                ?? KartaTechnicznaSzafkiStore
                    .powiazNajstarszaKarteLegacy(
                        templateCode:
                            template.code,
                        moduleName:
                            stored
                                .assembly
                                .name,
                        zKluczemModulu:
                            moduleKey
                    )
                ?? KartaTechnicznaSzafkiBuilder
                    .build(
                        template:
                            template,
                        moduleName:
                            stored.assembly.name,
                        width:
                            stored.assembly.size.width,
                        height:
                            stored.assembly.size.height,
                        depth:
                            stored.assembly.size.depth,
                        shelfCount:
                            (
                                try? stored.parameters
                                    .integer(
                                        for:
                                            .shelfCount
                                    )
                            )
                            ?? 0
                    )

            card.materialKorpusu =
                pelnaNazwa(
                    ustawienia.korpus
                )
            card.materialFrontu =
                pelnaNazwa(
                    ustawienia.front
                )
            card.materialKorpusuID =
                ustawienia.korpus.id
            card.materialFrontuID =
                ustawienia.front.id
            card.kluczModulu =
                moduleKey
            card.wersjaSchematu =
                2

            var elements =
                card.efektywneElementy
            for index in elements.indices {
                switch elements[index].typ {
                case .front,
                     .blenda,
                     .sciankaMaskujaca:
                    elements[index].material =
                        card.materialFrontu
                    elements[index].materialID =
                        card.materialFrontuID

                case .scianaBoczna,
                     .dno,
                     .wieniecGorny,
                     .wieniecDolny,
                     .polka,
                     .cokół,
                     .listwa,
                     .przegroda:
                    elements[index].material =
                        card.materialKorpusu
                    elements[index].materialID =
                        card.materialKorpusuID

                case .plecy,
                     .szuflada,
                     .inny:
                    break
                }
            }

            card.efektywneElementy =
                elements
            card.dataAktualizacji =
                Date()
            KartaTechnicznaSzafkiStore
                .save(card)
        }

        renderRevision &+= 1
    }

    private func pelnaNazwa(
        _ material:
            MigawkaMaterialuGlobalnego
    ) -> String {
        [
            material.producent,
            material.kod,
            material.nazwa
        ]
        .filter {
            !$0.trimmingCharacters(
                in:
                    .whitespacesAndNewlines
            )
            .isEmpty
        }
        .joined(separator: " ")
    }

    func storedAssembly(
        id: FurnitureAssemblyID?
    ) -> StoredFurnitureAssembly? {
        guard let id else { return nil }
        return _assemblyByID[id]
    }

    func template(
        for storedAssembly: StoredFurnitureAssembly
    ) -> FurnitureTemplate? {
        guard let templateID = storedAssembly.assembly.templateID else {
            return nil
        }

        return templates.first { $0.id == templateID }
    }

    func templates(
        compatibleWith suggestion: SugerowanePolozenieModulu
    ) -> [FurnitureTemplate] {
        templates.filter { template in
            guard !StandardKitchenFinishingTemplatesV015
                .isFinishingTemplate(template) else {
                return false
            }

            if let requiredRunKind = suggestion.requiredRunKind {
                return KitchenRunTemplateClassifierV015.kind(
                    for: template
                ) == requiredRunKind
            }

            guard let required = suggestion.requiredAnchoringMode else {
                return true
            }

            return anchoringMode(for: template) == required
        }
    }

    func suggestedOffset(
        for template: FurnitureTemplate,
        wallID: WallID
    ) -> Millimeters {
        let candidateHeight =
            (try? template.defaultParameters.millimeters(for: .height)) ?? 720
        let candidateDepth =
            (try? template.defaultParameters.millimeters(for: .depth)) ?? 560
        let candidateBottom = defaultBottomOffset(for: template)

        // v0.14.6:
        // Pozycja nie może być liczona wyłącznie według rodzaju mocowania.
        // Słupek `.builtIn` stojący od podłogi zajmuje tę samą przestrzeń,
        // co szafki dolne i część szafek wiszących. Dlatego uwzględniamy
        // wszystkie bryły, które faktycznie przecinają się z kandydatem
        // w pionie oraz w głąb pomieszczenia.
        return storedAssemblies.reduce(.zero) { result, stored in
            guard let placement = stored.assembly.placement,
                  placement.wallID == wallID else {
                return result
            }

            let overlapsVertically = overlaps(
                lhsStart: candidateBottom,
                lhsLength: candidateHeight,
                rhsStart: placement.bottomOffset,
                rhsLength: stored.assembly.size.height
            )
            let overlapsInDepth = overlaps(
                lhsStart: .zero,
                lhsLength: candidateDepth,
                rhsStart: placement.offsetFromWall,
                rhsLength: stored.assembly.size.depth
            )

            guard overlapsVertically, overlapsInDepth else {
                return result
            }

            return max(
                result,
                placement.offsetAlongWall + stored.assembly.size.width
            )
        }
    }

    func suggestedPlacement(
        for template: FurnitureTemplate,
        wall: WallSegment,
        room: RoomDefinition
    ) -> SugerowanePolozenieModulu {
        let offset = suggestedOffset(for: template, wallID: wall.id)
        let length = room.geometry.geometry(of: wall.id)?.length ?? .zero
        let maximumWidth = max(length - offset, .zero)

        return SugerowanePolozenieModulu(
            offsetAlongWall: offset,
            offsetFromWall: .zero,
            bottomOffset: defaultBottomOffset(for: template),
            maximumWidth: maximumWidth,
            requiredAnchoringMode: nil
        )
    }

    func adjacentSuggestion(
        after stored: StoredFurnitureAssembly,
        in room: RoomDefinition
    ) -> SugerowanePolozenieModulu? {
        guard let placement = stored.assembly.placement,
              let wallID = placement.wallID,
              let wallGeometry = room.geometry.geometry(of: wallID),
              case .line = wallGeometry else {
            return nil
        }

        let sourceRight = placement.offsetAlongWall + stored.assembly.size.width
        let sourceBottom = placement.bottomOffset
        let sourceTop = placement.bottomOffset + stored.assembly.size.height

        var nextBlockingOffset = wallGeometry.length

        for other in storedAssemblies where other.id != stored.id {
            guard let otherPlacement = other.assembly.placement,
                  otherPlacement.wallID == wallID,
                  otherPlacement.offsetAlongWall >= sourceRight else {
                continue
            }

            let otherBottom = otherPlacement.bottomOffset
            let otherTop = otherPlacement.bottomOffset + other.assembly.size.height
            let overlapsVertically = sourceBottom < otherTop && sourceTop > otherBottom

            guard overlapsVertically else { continue }
            nextBlockingOffset = min(nextBlockingOffset, otherPlacement.offsetAlongWall)
        }

        let availableWidth = nextBlockingOffset - sourceRight
        guard availableWidth >= minimumAdjacentModuleWidth else {
            return nil
        }

        return SugerowanePolozenieModulu(
            offsetAlongWall: sourceRight,
            offsetFromWall: placement.offsetFromWall,
            bottomOffset: placement.bottomOffset,
            maximumWidth: availableWidth,
            requiredAnchoringMode: placement.anchoringMode
        )
    }

    func createModule(
        template: FurnitureTemplate,
        data: KonfiguracjaModuluMeblowegoDane,
        wall: WallSegment,
        room: RoomDefinition
    ) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            let parameters = try parameterOverrides(
                from: data,
                template: template
            )
            let builder = try builder(for: template)
            var assembly = try builder.build(
                template: template,
                parameters: parameters,
                preservingIDsFrom: nil
            )
            assembly = rozwiazWiezyMebla(assembly)
            assembly.name = data.name

            assembly.placement = try FurniturePlacement(
                roomID: room.id,
                wallID: wall.id,
                assemblyID: assembly.id,
                offsetAlongWall: data.offsetAlongWall,
                offsetFromWall: data.offsetFromWall,
                bottomOffset: data.bottomOffset,
                anchoringMode: anchoringMode(for: template)
            )

            try validatePlacement(
                candidate: assembly,
                wall: wall,
                room: room,
                excluding: nil
            )

            let resolvedParameters = try template.resolvedParameters(
                overrides: parameters
            )

            let stored = StoredFurnitureAssembly(
                roomID: room.id,
                assembly: assembly,
                parameters: resolvedParameters
            )

            try await repositories.assemblyRepository.save(stored)

            // Aktualizujemy stan ekranu natychmiast po udanym zapisie.
            // Nie czekamy na ponowne pobranie z osobnego kontekstu SwiftData,
            // dzięki czemu rzut 2D i elewacja od razu dostają nowy moduł.
            upsert(stored)
            lastCreatedAssemblyID = assembly.id

            KartaTechnicznaSzafkiStore
                .powiazKarte(
                    draftID:
                        data.technicalCardDraftID,
                    zKluczemModulu:
                        StabilnyKluczDomenowy
                            .utworz(
                                dla: assembly.id,
                                prefiks: "furniture"
                            )
                )

            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Buduje `KonfiguracjaModuluMeblowegoDane` z istniejącego modułu,
    /// opcjonalnie z nadpisanymi wartościami dla szybkiej edycji przy kliencie.
    func daneForQuickEdit(
        stored: StoredFurnitureAssembly,
        template: FurnitureTemplate,
        overrideShelfCount: Int? = nil,
        overrideDrawerCount: Int? = nil
    ) -> KonfiguracjaModuluMeblowegoDane {
        let p = stored.parameters
        let placement = stored.assembly.placement
        let kluczModulu = StabilnyKluczDomenowy.utworz(dla: stored.id, prefiks: "furniture")
        let card = KartaTechnicznaSzafkiStore.card(forModuleKey: kluczModulu)

        let currentDrawerCount = overrideDrawerCount
            ?? card?.efektywneSzuflady.filter(\.aktywna).count
            ?? 0
        let currentShelfCount = overrideShelfCount
            ?? (try? p.integer(for: .shelfCount))
            ?? 1

        return KonfiguracjaModuluMeblowegoDane(
            name: stored.assembly.name,
            width: stored.assembly.size.width,
            height: stored.assembly.size.height,
            depth: stored.assembly.size.depth,
            shelfCount: max(0, currentShelfCount),
            drawerCount: max(0, currentDrawerCount),
            carcassThickness: (try? p.millimeters(for: .carcassThickness)) ?? 18,
            shelfFrontSetback: (try? p.millimeters(for: .shelfFrontSetback)) ?? 20,
            backType: (try? p.cabinetBackType(for: .backType)) ?? .inset,
            backThickness: (try? p.millimeters(for: .backThickness)) ?? 3,
            backInset: (try? p.millimeters(for: .backInset)) ?? 10,
            topConstruction: (try? p.cabinetTopConstruction(for: .topConstruction)) ?? .fullPanel,
            topRailDepth: (try? p.millimeters(for: .topRailDepth)) ?? 100,
            frontEnabled: (try? p.boolean(for: .frontEnabled)) ?? true,
            frontThickness: (try? p.millimeters(for: .frontThickness)) ?? 18,
            frontGap: (try? p.millimeters(for: .frontGap)) ?? 2,
            frontInset: (try? p.millimeters(for: .frontInset)) ?? 0,
            openingTechnology: (try? p.openingTechnology(for: .openingTechnology)) ?? .handle,
            bottomShortening: (try? p.millimeters(for: .bottomShortening)) ?? 0,
            technicalCardDraftID: card?.draftID ?? UUID(),
            offsetAlongWall: placement?.offsetAlongWall ?? .zero,
            offsetFromWall: placement?.offsetFromWall ?? .zero,
            bottomOffset: placement?.bottomOffset ?? .zero
        )
    }

    /// Przelicza więzy parametryczne (`FurnitureConstraint`) zespołu po zbudowaniu z
    /// buildera. Więzy są opcjonalne — przy błędzie solvera zwracamy zespół sprzed
    /// przeliczenia, aby nie blokować zapisu modułu.
    private func rozwiazWiezyMebla(
        _ assembly: FurnitureAssembly
    ) -> FurnitureAssembly {
        guard !assembly.constraints.isEmpty else { return assembly }
        do {
            return try FurnitureConstraintSolver.solve(assembly).assembly
        } catch {
            return assembly
        }
    }

    /// Zapis modułu edytowanego w kreatorze rysunkowym (`ModulEdytorElewacjiView`).
    /// Przebudowuje komponenty z `ElevationModule`, zachowując tożsamość zespołu
    /// (id, szablon, położenie na ścianie). Parametry szablonu synchronizuje
    /// tylko w zakresie gabarytu — konfiguracja wnętrza żyje w komponentach,
    /// więc późniejsza edycja formularzem odtworzy wnętrze z parametrów szablonu.
    func zapiszModulZKreatoraElewacji(
        stored: StoredFurnitureAssembly,
        modul: ElevationModule,
        wall: WallSegment,
        room: RoomDefinition
    ) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            let fresh = try modul.makeAssembly(named: modul.name)
            let assembly = try FurnitureAssembly(
                id: stored.assembly.id,
                templateID: stored.assembly.templateID,
                name: modul.name,
                kind: stored.assembly.kind,
                size: fresh.size,
                components: fresh.components,
                subassemblies: [],
                constraints: [],
                placement: stored.assembly.placement
            )

            try validatePlacement(
                candidate: assembly,
                wall: wall,
                room: room,
                excluding: stored.id
            )

            var parameters = stored.parameters
            parameters = (try? parameters.setting(.millimeters(modul.width), for: .width)) ?? parameters
            parameters = (try? parameters.setting(.millimeters(modul.height), for: .height)) ?? parameters
            parameters = (try? parameters.setting(.millimeters(modul.depth), for: .depth)) ?? parameters

            let updated = StoredFurnitureAssembly(
                roomID: stored.roomID,
                assembly: assembly,
                parameters: parameters,
                createdAt: stored.createdAt,
                updatedAt: Date()
            )

            try await repositories.assemblyRepository.save(updated)
            upsert(updated)
            return true
        } catch {
            errorMessage =
                "Nie udało się zapisać modułu z kreatora rysunkowego: "
                + error.localizedDescription
            return false
        }
    }

    func updateModule(
        stored: StoredFurnitureAssembly,
        template: FurnitureTemplate,
        data: KonfiguracjaModuluMeblowegoDane,
        wall: WallSegment,
        room: RoomDefinition,
        skipCollisionCheck: Bool = false
    ) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            let parameters = try parameterOverrides(
                from: data,
                template: template
            )
            let builder = try builder(for: template)
            var assembly = try builder.build(
                template: template,
                parameters: parameters,
                preservingIDsFrom: stored.assembly
            )
            assembly = rozwiazWiezyMebla(assembly)
            assembly.name = data.name

            let resolvedAnchoringMode =
                stored.assembly.placement?.anchoringMode
                ?? anchoringMode(for: template)

            assembly.placement = try FurniturePlacement(
                id: stored.assembly.placement?.id ?? FurniturePlacementID(),
                roomID: room.id,
                wallID: wall.id,
                assemblyID: assembly.id,
                offsetAlongWall: data.offsetAlongWall,
                offsetFromWall: data.offsetFromWall,
                bottomOffset: data.bottomOffset,
                rotationDegrees: stored.assembly.placement?.rotationDegrees ?? 0,
                anchoringMode: resolvedAnchoringMode
            )

            // Pomijamy walidację kolizji gdy moduł nie zmienił rozmiaru/pozycji —
            // np. szybka edycja półek/szuflad. Moduł był już poprawnie
            // umieszczony przed edycją, więc kolizja jest niemożliwa.
            if !skipCollisionCheck {
                try validatePlacement(
                    candidate: assembly,
                    wall: wall,
                    room: room,
                    excluding: stored.id
                )
            }

            let resolvedParameters = try template.resolvedParameters(
                overrides: parameters
            )

            let updatedStored = StoredFurnitureAssembly(
                roomID: room.id,
                assembly: assembly,
                parameters: resolvedParameters,
                createdAt: stored.createdAt,
                updatedAt: Date()
            )

            try await repositories.assemblyRepository.save(updatedStored)
            upsert(updatedStored)

            KartaTechnicznaSzafkiStore
                .powiazKarte(
                    draftID:
                        data.technicalCardDraftID,
                    zKluczemModulu:
                        StabilnyKluczDomenowy
                            .utworz(
                                dla: updatedStored.id,
                                prefiks: "furniture"
                            )
                )

            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Przesuwa moduł wzdłuż aktualnej ściany albo zamienia jego kolejność
    /// z modułem wskazanym przez gest przeciągania.
    ///
    /// Zmieniane jest wyłącznie `FurniturePlacement`, dlatego identyfikator
    /// mebla, komponenty, parametry i karta techniczna pozostają bez zmian.
    func przesunLubZamienModul(
        _ context: KontekstPrzesunieciaModulu2D,
        room: RoomDefinition
    ) async -> Bool {
        guard !isSaving else {
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            guard let source = storedAssemblies.first(where: {
                $0.id == context.furnitureID
            }),
            source.assembly.placement?.wallID
                == context.wallID else {
                throw DomainError.invariantViolation(
                    "Nie znaleziono modułu w wybranym ciągu."
                )
            }

            if let targetID = context.celZamianyID,
               targetID != source.id {
                try await zamienKolejnoscModulow(
                    sourceID: source.id,
                    targetID: targetID,
                    room: room
                )
            } else {
                try await przesunModul(
                    source,
                    do: context.proponowaneOdsuniecie,
                    bottomOffset:
                        context.proponowaneOdsuniecieOdDolu,
                    room: room
                )
            }

            return true
        } catch {
            errorMessage =
                "Nie udało się zmienić położenia modułu: "
                + error.localizedDescription
            return false
        }
    }

    private func przesunModul(
        _ stored: StoredFurnitureAssembly,
        do offset: Millimeters,
        bottomOffset: Millimeters?,
        room: RoomDefinition
    ) async throws {
        guard let placement = stored.assembly.placement,
              let wallID = placement.wallID,
              let wall = room.geometry.wall(id: wallID) else {
            throw DomainError.invariantViolation(
                "Moduł nie jest przypisany do prostej ściany."
            )
        }

        let proposedBottom =
            bottomOffset ?? placement.bottomOffset
        let horizontalUnchanged = abs(
            placement.offsetAlongWall.rawValue
                - offset.rawValue
        ) <= 0.5
        let verticalUnchanged = abs(
            placement.bottomOffset.rawValue
                - proposedBottom.rawValue
        ) <= 0.5

        if horizontalUnchanged && verticalUnchanged {
            return
        }

        let updated = storedZmieniajacPolozenie(
            stored,
            offsetAlongWall: offset,
            bottomOffset: proposedBottom
        )
        let finalStored = storedAssemblies.map {
            $0.id == updated.id ? updated : $0
        }
        let finalAssemblies = finalStored.map(\.assembly)

        try validatePlacement(
            candidate: updated.assembly,
            wall: wall,
            room: room,
            excluding: updated.id,
            among: finalAssemblies
        )

        try await repositories.assemblyRepository.save(
            updated
        )
        zastosujAktualizacjePolozen([updated])
    }

    private func zamienKolejnoscModulow(
        sourceID: FurnitureAssemblyID,
        targetID: FurnitureAssemblyID,
        room: RoomDefinition
    ) async throws {
        guard let source = storedAssemblies.first(where: {
            $0.id == sourceID
        }),
        let target = storedAssemblies.first(where: {
            $0.id == targetID
        }),
        tenSamPasPrzesuwania(source, target) else {
            throw DomainError.invariantViolation(
                "Moduły można zamieniać tylko w tym samym ciągu i na tej samej wysokości."
            )
        }

        let lane = storedAssemblies
            .filter {
                tenSamPasPrzesuwania(source, $0)
            }
            .sorted {
                ($0.assembly.placement?.offsetAlongWall ?? .zero)
                    <
                ($1.assembly.placement?.offsetAlongWall ?? .zero)
            }

        guard let sourceIndex = lane.firstIndex(where: {
            $0.id == sourceID
        }),
        let targetIndex = lane.firstIndex(where: {
            $0.id == targetID
        }),
        sourceIndex != targetIndex else {
            return
        }

        let lowerIndex = min(sourceIndex, targetIndex)
        let upperIndex = max(sourceIndex, targetIndex)
        let originalRange = Array(
            lane[lowerIndex...upperIndex]
        )

        guard let firstOffset =
                originalRange.first?
                    .assembly
                    .placement?
                    .offsetAlongWall else {
            throw DomainError.invariantViolation(
                "Nie można odczytać początku ciągu."
            )
        }

        var gaps: [Millimeters] = []
        if originalRange.count > 1 {
            for index in 0..<(originalRange.count - 1) {
                guard
                    let currentPlacement =
                        originalRange[index]
                            .assembly
                            .placement,
                    let nextPlacement =
                        originalRange[index + 1]
                            .assembly
                            .placement
                else {
                    throw DomainError.invariantViolation(
                        "Ciąg zawiera moduł bez poprawnego osadzenia."
                    )
                }

                let currentEnd =
                    currentPlacement.offsetAlongWall
                    + originalRange[index]
                        .assembly
                        .size
                        .width
                gaps.append(
                    Millimeters(
                        max(
                            nextPlacement
                                .offsetAlongWall
                                .rawValue
                            - currentEnd.rawValue,
                            0
                        )
                    )
                )
            }
        }

        var reordered = originalRange
        let sourceLocalIndex =
            sourceIndex - lowerIndex
        let targetLocalIndex =
            targetIndex - lowerIndex
        reordered.swapAt(
            sourceLocalIndex,
            targetLocalIndex
        )

        var cursor = firstOffset
        var updates: [StoredFurnitureAssembly] = []
        updates.reserveCapacity(reordered.count)

        for index in reordered.indices {
            let updated = storedZmieniajacPolozenie(
                reordered[index],
                offsetAlongWall: cursor
            )
            updates.append(updated)

            cursor =
                cursor
                + updated.assembly.size.width

            if index < gaps.count {
                cursor = cursor + gaps[index]
            }
        }

        let updatesByID = Dictionary(
            uniqueKeysWithValues: updates.map {
                ($0.id, $0)
            }
        )
        let finalStored = storedAssemblies.map {
            updatesByID[$0.id] ?? $0
        }
        let finalAssemblies = finalStored.map(\.assembly)

        for updated in updates {
            guard
                let wallID =
                    updated.assembly.placement?.wallID,
                let wall =
                    room.geometry.wall(id: wallID)
            else {
                throw DomainError.invariantViolation(
                    "Nie znaleziono ściany dla zamienianego modułu."
                )
            }

            try validatePlacement(
                candidate: updated.assembly,
                wall: wall,
                room: room,
                excluding: updated.id,
                among: finalAssemblies
            )
        }

        do {
            for updated in updates {
                try await repositories
                    .assemblyRepository
                    .save(updated)
            }
        } catch {
            // Repozytorium zapisuje rekordy pojedynczo. W przypadku błędu
            // przywracamy cały zmieniany fragment ciągu.
            for original in originalRange {
                try? await repositories
                    .assemblyRepository
                    .save(original)
            }
            throw error
        }

        zastosujAktualizacjePolozen(updates)
    }

    private func storedZmieniajacPolozenie(
        _ stored: StoredFurnitureAssembly,
        offsetAlongWall: Millimeters,
        bottomOffset: Millimeters? = nil
    ) -> StoredFurnitureAssembly {
        var assembly = stored.assembly

        if var placement = assembly.placement {
            placement.offsetAlongWall =
                offsetAlongWall
            if let bottomOffset {
                placement.bottomOffset = bottomOffset
            }
            assembly.placement = placement
        }

        return StoredFurnitureAssembly(
            roomID: stored.roomID,
            assembly: assembly,
            parameters: stored.parameters,
            createdAt: stored.createdAt,
            updatedAt: Date()
        )
    }

    private func tenSamPasPrzesuwania(
        _ lhs: StoredFurnitureAssembly,
        _ rhs: StoredFurnitureAssembly
    ) -> Bool {
        guard let lhsPlacement =
                lhs.assembly.placement,
              let rhsPlacement =
                rhs.assembly.placement,
              lhsPlacement.wallID
                == rhsPlacement.wallID else {
            return false
        }

        return MebelPlan2DGeometry.layer(
            for: lhs.assembly
        ) == MebelPlan2DGeometry.layer(
            for: rhs.assembly
        )
        && abs(
            lhsPlacement.bottomOffset.rawValue
                - rhsPlacement.bottomOffset.rawValue
        ) <= 1
        && abs(
            lhsPlacement.offsetFromWall.rawValue
                - rhsPlacement.offsetFromWall.rawValue
        ) <= 1
    }

    private func zastosujAktualizacjePolozen(
        _ updates: [StoredFurnitureAssembly]
    ) {
        let updatesByID = Dictionary(
            uniqueKeysWithValues: updates.map {
                ($0.id, $0)
            }
        )

        storedAssemblies = storedAssemblies.map {
            updatesByID[$0.id] ?? $0
        }
        storedAssemblies.sort { lhs, rhs in
            let lhsPlacement =
                lhs.assembly.placement
            let rhsPlacement =
                rhs.assembly.placement

            if lhsPlacement?.wallID
                == rhsPlacement?.wallID {
                return (
                    lhsPlacement?
                        .offsetAlongWall
                    ?? .zero
                ) < (
                    rhsPlacement?
                        .offsetAlongWall
                    ?? .zero
                )
            }

            return lhs.createdAt < rhs.createdAt
        }
        rebuildAssemblyIndex()
        renderRevision &+= 1
    }

    func migawkiPolozenV064(
        ids: [FurnitureAssemblyID]
    ) -> [MigawkaPolozeniaModuluV064] {
        let requested = Set(ids)
        return storedAssemblies.compactMap { stored in
            guard requested.contains(stored.id),
                  let placement = stored.assembly.placement else {
                return nil
            }
            return MigawkaPolozeniaModuluV064(
                furnitureID: stored.id,
                placement: placement
            )
        }
    }

    func przywrocPolozeniaV064(
        _ snapshots: [MigawkaPolozeniaModuluV064]
    ) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        defer { isSaving = false }

        do {
            var replacements: [FurnitureAssemblyID: StoredFurnitureAssembly] = [:]

            for snapshot in snapshots {
                guard let stored = storedAssemblies.first(where: {
                    $0.id == snapshot.furnitureID
                }) else {
                    continue
                }

                var assembly = stored.assembly
                assembly.placement = snapshot.placement

                let updated = StoredFurnitureAssembly(
                    roomID: stored.roomID,
                    assembly: assembly,
                    parameters: stored.parameters,
                    createdAt: stored.createdAt,
                    updatedAt: Date()
                )

                try await repositories.assemblyRepository.save(updated)
                replacements[stored.id] = updated
            }

            storedAssemblies = storedAssemblies.map {
                replacements[$0.id] ?? $0
            }
            storedAssemblies.sort { lhs, rhs in
                let left = lhs.assembly.placement
                let right = rhs.assembly.placement
                if left?.wallID == right?.wallID {
                    return (left?.offsetAlongWall ?? .zero)
                        < (right?.offsetAlongWall ?? .zero)
                }
                return lhs.createdAt < rhs.createdAt
            }
            rebuildAssemblyIndex()
            renderRevision &+= 1
            return true
        } catch {
            errorMessage =
                "Nie udało się przywrócić położenia modułu: "
                + error.localizedDescription
            return false
        }
    }


    func duplikujModulV065(
        id: FurnitureAssemblyID,
        room: RoomDefinition
    ) async -> WynikDuplikowaniaModuluV065? {
        guard !isSaving,
              let source = storedAssemblies.first(where: { $0.id == id }),
              let sourcePlacement = source.assembly.placement,
              let wallID = sourcePlacement.wallID,
              let wall = room.geometry.wall(id: wallID) else {
            return nil
        }

        isSaving = true
        defer { isSaving = false }

        var originalRuns: [FurnitureRun] = []
        var savedDuplicateID: FurnitureAssemblyID?

        do {
            originalRuns =
                try await repositories.runRepository
                    .fetchAll(roomID: room.id)
                    .filter { $0.moduleIDs.contains(source.id) }

            let duplicateName = nazwaDuplikatuV065(for: source.assembly.name)
            var duplicate = try KlonowanieModuluV065.wykonaj(
                source: source,
                nowaNazwa: duplicateName
            )

            let offset = try wolneOdsuniecieDlaDuplikatuV065(
                duplicate: duplicate.assembly,
                source: source.assembly,
                wall: wall,
                room: room
            )

            guard var duplicatePlacement = duplicate.assembly.placement else {
                throw DomainError.invariantViolation(
                    "Nie można zduplikować modułu bez położenia."
                )
            }

            duplicatePlacement.offsetAlongWall = offset
            var duplicateAssembly = duplicate.assembly
            duplicateAssembly.placement = duplicatePlacement
            duplicate = StoredFurnitureAssembly(
                roomID: duplicate.roomID,
                assembly: duplicateAssembly,
                parameters: duplicate.parameters
            )

            try validatePlacement(
                candidate: duplicate.assembly,
                wall: wall,
                room: room,
                excluding: nil
            )

            try await repositories.assemblyRepository.save(duplicate)
            savedDuplicateID = duplicate.id

            var updatedRuns: [FurnitureRun] = []
            updatedRuns.reserveCapacity(originalRuns.count)

            for var run in originalRuns {
                if let sourceIndex = run.moduleIDs.firstIndex(of: source.id) {
                    run.moduleIDs.insert(
                        duplicate.id,
                        at: run.moduleIDs.index(after: sourceIndex)
                    )
                }
                try await repositories.runRepository.save(run)
                updatedRuns.append(run)
            }

            let sourceKey = StabilnyKluczDomenowy.utworz(
                dla: source.id,
                prefiks: "furniture"
            )
            let duplicateKey = StabilnyKluczDomenowy.utworz(
                dla: duplicate.id,
                prefiks: "furniture"
            )
            let duplicateCard =
                KartaTechnicznaSzafkiStore.duplikujKarteV065(
                    zKluczaModulu: sourceKey,
                    doKluczaModulu: duplicateKey,
                    nowaNazwa: duplicateName
                )

            upsert(duplicate)
            lastCreatedAssemblyID = duplicate.id

            let operation = OperacjaStanuModulowV065(
                nazwa: "Duplikowanie modułu",
                przed: StanEdycjiModulowV065(
                    moduly: [
                        MigawkaStanuModuluV065(
                            furnitureID: duplicate.id,
                            stored: nil,
                            kartaTechniczna: nil
                        )
                    ],
                    ciagi: originalRuns
                ),
                po: StanEdycjiModulowV065(
                    moduly: [
                        MigawkaStanuModuluV065(
                            furnitureID: duplicate.id,
                            stored: duplicate,
                            kartaTechniczna: duplicateCard
                        )
                    ],
                    ciagi: updatedRuns
                ),
                zaznaczeniePrzed: source.id,
                zaznaczeniePo: duplicate.id
            )

            return WynikDuplikowaniaModuluV065(
                nowyID: duplicate.id,
                operacja: operation
            )
        } catch {
            if let savedDuplicateID {
                for run in originalRuns {
                    try? await repositories.runRepository.save(run)
                }
                try? await repositories.assemblyRepository.delete(
                    id: savedDuplicateID
                )
                KartaTechnicznaSzafkiStore.usunKarte(
                    forModuleKey:
                        StabilnyKluczDomenowy.utworz(
                            dla: savedDuplicateID,
                            prefiks: "furniture"
                        )
                )
            }

            errorMessage =
                "Nie udało się zduplikować modułu: "
                + error.localizedDescription
            return nil
        }
    }

    func duplikujGrupeModulowV067(
        ids: Set<FurnitureAssemblyID>,
        glowneID: FurnitureAssemblyID?,
        room: RoomDefinition
    ) async -> WynikDuplikowaniaGrupyV067? {
        guard !isSaving, ids.count > 1 else {
            return nil
        }

        let sources = storedAssemblies
            .filter { ids.contains($0.id) }
            .sorted { lhs, rhs in
                let left = lhs.assembly.placement?.offsetAlongWall ?? .zero
                let right = rhs.assembly.placement?.offsetAlongWall ?? .zero
                if left == right {
                    return lhs.assembly.name < rhs.assembly.name
                }
                return left < right
            }

        guard sources.count == ids.count,
              let firstPlacement = sources.first?.assembly.placement,
              let wallID = firstPlacement.wallID,
              let wall = room.geometry.wall(id: wallID),
              sources.allSatisfy({
                  $0.assembly.placement?.wallID == wallID
                      && $0.roomID == room.id
              }) else {
            errorMessage =
                "Grupę można duplikować wyłącznie na jednej wspólnej ścianie."
            return nil
        }

        isSaving = true
        defer { isSaving = false }

        var originalRuns: [FurnitureRun] = []
        var savedDuplicateIDs: [FurnitureAssemblyID] = []
        var plannedDuplicateIDs: [FurnitureAssemblyID] = []

        do {
            originalRuns =
                try await repositories.runRepository
                    .fetchAll(roomID: room.id)
                    .filter { run in
                        run.moduleIDs.contains { ids.contains($0) }
                    }

            var reservedNames = Set(
                storedAssemblies.map {
                    $0.assembly.name.lowercased()
                }
            )
            var duplicateBySource:
                [FurnitureAssemblyID: StoredFurnitureAssembly] = [:]

            for source in sources {
                let duplicateName =
                    unikalnaNazwaDuplikatuGrupyV067(
                        for: source.assembly.name,
                        reservedNames: &reservedNames
                    )
                let duplicate = try KlonowanieModuluV065.wykonaj(
                    source: source,
                    nowaNazwa: duplicateName
                )
                duplicateBySource[source.id] = duplicate
                plannedDuplicateIDs.append(duplicate.id)
            }

            let baseDuplicates = sources.compactMap {
                duplicateBySource[$0.id]
            }
            guard baseDuplicates.count == sources.count else {
                throw DomainError.invariantViolation(
                    "Nie udało się przygotować wszystkich kopii grupy."
                )
            }

            let translation =
                try przesuniecieDlaDuplikatuGrupyV067(
                    duplicates: baseDuplicates,
                    sources: sources,
                    wall: wall,
                    room: room
                )
            let duplicates =
                przesunieteDuplikatyGrupyV067(
                    baseDuplicates,
                    dx: translation
                )
            let duplicateAssemblies = duplicates.map(\.assembly)
            let validationPool = assemblies + duplicateAssemblies

            for duplicate in duplicateAssemblies {
                try validatePlacement(
                    candidate: duplicate,
                    wall: wall,
                    room: room,
                    excluding: duplicate.id,
                    among: validationPool
                )
            }

            for duplicate in duplicates {
                try await repositories.assemblyRepository.save(
                    duplicate
                )
                savedDuplicateIDs.append(duplicate.id)
            }

            var updatedRuns: [FurnitureRun] = []
            updatedRuns.reserveCapacity(originalRuns.count)

            for var run in originalRuns {
                var expandedIDs: [FurnitureAssemblyID] = []
                expandedIDs.reserveCapacity(
                    run.moduleIDs.count + ids.count
                )

                for moduleID in run.moduleIDs {
                    expandedIDs.append(moduleID)
                    if let duplicate = duplicateBySource[moduleID] {
                        expandedIDs.append(duplicate.id)
                    }
                }

                run.moduleIDs = expandedIDs
                try await repositories.runRepository.save(run)
                updatedRuns.append(run)
            }

            var afterSnapshots: [MigawkaStanuModuluV065] = []
            afterSnapshots.reserveCapacity(duplicates.count)

            for duplicate in duplicates {
                guard let sourceID = duplicateBySource.first(
                    where: { $0.value.id == duplicate.id }
                )?.key,
                      let source = sources.first(
                          where: { $0.id == sourceID }
                      ) else {
                    throw DomainError.invariantViolation(
                        "Nie udało się odtworzyć relacji kopii z modułem źródłowym."
                    )
                }

                let sourceKey = StabilnyKluczDomenowy.utworz(
                    dla: source.id,
                    prefiks: "furniture"
                )
                let duplicateKey = StabilnyKluczDomenowy.utworz(
                    dla: duplicate.id,
                    prefiks: "furniture"
                )
                let duplicateCard =
                    KartaTechnicznaSzafkiStore.duplikujKarteV065(
                        zKluczaModulu: sourceKey,
                        doKluczaModulu: duplicateKey,
                        nowaNazwa: duplicate.assembly.name
                    )

                afterSnapshots.append(
                    MigawkaStanuModuluV065(
                        furnitureID: duplicate.id,
                        stored: duplicate,
                        kartaTechniczna: duplicateCard
                    )
                )
            }

            for duplicate in duplicates {
                upsert(duplicate)
            }

            let newIDs = Set(duplicates.map(\.id))
            let primarySourceID =
                glowneID.flatMap { ids.contains($0) ? $0 : nil }
                ?? sources.first?.id
            let primaryDuplicateID =
                primarySourceID.flatMap {
                    duplicateBySource[$0]?.id
                }

            lastCreatedAssemblyID =
                primaryDuplicateID ?? duplicates.first?.id

            let operation = OperacjaStanuModulowV065(
                nazwa: "Duplikowanie grupy modułów",
                przed: StanEdycjiModulowV065(
                    moduly: duplicates.map {
                        MigawkaStanuModuluV065(
                            furnitureID: $0.id,
                            stored: nil,
                            kartaTechniczna: nil
                        )
                    },
                    ciagi: originalRuns
                ),
                po: StanEdycjiModulowV065(
                    moduly: afterSnapshots,
                    ciagi: updatedRuns
                ),
                zaznaczeniePrzed:
                    primarySourceID,
                zaznaczeniePo:
                    primaryDuplicateID,
                zaznaczeniaPrzedV066: ids,
                zaznaczeniaPoV066: newIDs
            )

            return WynikDuplikowaniaGrupyV067(
                noweID: newIDs,
                glowneID: primaryDuplicateID,
                operacja: operation
            )
        } catch {
            for run in originalRuns {
                try? await repositories.runRepository.save(run)
            }

            for duplicateID in savedDuplicateIDs {
                try? await repositories.assemblyRepository.delete(
                    id: duplicateID
                )
            }

            for duplicateID in plannedDuplicateIDs {
                KartaTechnicznaSzafkiStore.usunKarte(
                    forModuleKey:
                        StabilnyKluczDomenowy.utworz(
                            dla: duplicateID,
                            prefiks: "furniture"
                        )
                )
            }

            errorMessage =
                "Nie udało się zduplikować grupy: "
                + error.localizedDescription
            return nil
        }
    }


    func usunModulV065(
        id: FurnitureAssemblyID
    ) async -> OperacjaStanuModulowV065? {
        await usunModulyV066(
            ids: [id],
            glowneID: id
        )
    }

    func przywrocStanEdycjiV065(
        _ state: StanEdycjiModulowV065
    ) async -> Bool {
        guard !isSaving else { return false }

        isSaving = true
        defer { isSaving = false }

        do {
            for snapshot in state.moduly {
                guard let stored = snapshot.stored else { continue }
                try await repositories.assemblyRepository.save(stored)
            }

            for snapshot in state.moduly where snapshot.stored == nil {
                guard storedAssemblies.contains(where: {
                    $0.id == snapshot.furnitureID
                }) else {
                    continue
                }

                try await repositories.assemblyRepository.delete(
                    id: snapshot.furnitureID
                )
            }

            for snapshot in state.moduly {
                let moduleKey = StabilnyKluczDomenowy.utworz(
                    dla: snapshot.furnitureID,
                    prefiks: "furniture"
                )

                if let card = snapshot.kartaTechniczna {
                    KartaTechnicznaSzafkiStore.save(card)
                } else {
                    KartaTechnicznaSzafkiStore.usunKarte(
                        forModuleKey: moduleKey
                    )
                }
            }

            for run in state.ciagi {
                try await repositories.runRepository.save(run)
            }

            var restored = storedAssemblies
            for snapshot in state.moduly {
                restored.removeAll { $0.id == snapshot.furnitureID }
                if let stored = snapshot.stored {
                    restored.append(stored)
                }
            }

            storedAssemblies = restored.sorted { lhs, rhs in
                let left = lhs.assembly.placement
                let right = rhs.assembly.placement

                if left?.wallID == right?.wallID {
                    return (left?.offsetAlongWall ?? .zero)
                        < (right?.offsetAlongWall ?? .zero)
                }

                return lhs.createdAt < rhs.createdAt
            }
            rebuildAssemblyIndex()
            renderRevision &+= 1
            return true
        } catch {
            errorMessage =
                "Nie udało się przywrócić stanu modułu: "
                + error.localizedDescription
            return false
        }
    }


    func przesunGrupeModulowV066(
        ids: Set<FurnitureAssemblyID>,
        dx: Double,
        dy: Double,
        room: RoomDefinition,
        glowneID: FurnitureAssemblyID?
    ) async -> WynikOperacjiGrupowejV066? {
        guard !isSaving, ids.count > 1 else {
            return nil
        }

        let selected = storedAssemblies.filter { ids.contains($0.id) }
        guard selected.count == ids.count else {
            errorMessage =
                "Nie wszystkie zaznaczone moduły są dostępne w projekcie."
            return nil
        }

        let wallIDs = Set(selected.compactMap {
            $0.assembly.placement?.wallID
        })
        guard wallIDs.count == 1, wallIDs.first != nil else {
            errorMessage =
                "Grupę można przesuwać tylko na jednej wspólnej ścianie."
            return nil
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let updates = try selected.map { stored -> StoredFurnitureAssembly in
                guard let placement = stored.assembly.placement,
                      let wallID = placement.wallID,
                      let wall = room.geometry.wall(id: wallID) else {
                    throw DomainError.invariantViolation(
                        "Zaznaczony moduł nie ma poprawnego osadzenia."
                    )
                }

                let x = placement.offsetAlongWall.rawValue + dx
                let y = placement.bottomOffset.rawValue + dy
                guard x >= -0.01, y >= -0.01 else {
                    throw DomainError.invariantViolation(
                        "Grupa nie może wyjść poza początek ściany ani poniżej podłogi."
                    )
                }

                let wallHeight = min(
                    wall.startHeight.rawValue,
                    wall.endHeight.rawValue
                )
                guard y + stored.assembly.size.height.rawValue
                    <= wallHeight + 0.1 else {
                    throw DomainError.invariantViolation(
                        "Grupa nie mieści się w wysokości ściany."
                    )
                }

                return storedZmieniajacPolozenie(
                    stored,
                    offsetAlongWall: Millimeters(max(0, x)),
                    bottomOffset: Millimeters(max(0, y))
                )
            }

            return try await zapiszPolozeniaGrupyV066(
                originals: selected,
                updates: updates,
                room: room,
                nazwa: "Przesunięcie grupy",
                selectedIDs: ids,
                primaryID: glowneID
            )
        } catch {
            errorMessage =
                "Nie udało się przesunąć grupy: "
                + error.localizedDescription
            return nil
        }
    }

    func wykonajOperacjeGrupowaV066(
        _ operation: RodzajOperacjiGrupowejV066,
        ids: Set<FurnitureAssemblyID>,
        glowneID: FurnitureAssemblyID?,
        room: RoomDefinition
    ) async -> WynikOperacjiGrupowejV066? {
        // Operacje przebudowujące moduły (zmiana rozmiaru) mają osobną ścieżkę
        // zapisu i cofania — patrz rozlozRownaSzerokoscV081.
        guard !operation.przebudowujeModuly else { return nil }

        guard !isSaving,
              ids.count >= operation.minimalnaLiczbaModulow else {
            return nil
        }

        let selected = storedAssemblies
            .filter { ids.contains($0.id) }
            .sorted {
                ($0.assembly.placement?.offsetAlongWall ?? .zero)
                    <
                ($1.assembly.placement?.offsetAlongWall ?? .zero)
            }

        guard selected.count == ids.count,
              let first = selected.first,
              let firstPlacement = first.assembly.placement,
              let commonWallID = firstPlacement.wallID,
              let wall = room.geometry.wall(id: commonWallID),
              selected.allSatisfy({
                  $0.assembly.placement?.wallID == commonWallID
              }) else {
            errorMessage =
                "Operacja grupowa wymaga modułów na jednej wspólnej ścianie."
            return nil
        }

        let primary = selected.first(where: {
            $0.id == glowneID
        }) ?? first

        if operation == .domknijOdstepy
            || operation == .rozlozRownomiernie {
            let referenceLayer = MebelPlan2DGeometry.layer(
                for: first.assembly
            )
            let referenceDepth =
                firstPlacement.offsetFromWall.rawValue
            guard selected.allSatisfy({
                guard let placement = $0.assembly.placement else {
                    return false
                }
                return MebelPlan2DGeometry.layer(
                    for: $0.assembly
                ) == referenceLayer
                && abs(
                    placement.offsetFromWall.rawValue
                        - referenceDepth
                ) <= 1
                && abs(
                    placement.bottomOffset.rawValue
                        - firstPlacement.bottomOffset.rawValue
                ) <= 1
            }) else {
                errorMessage =
                    "Domykanie i równy rozstaw wymagają modułów w tym samym pasie zabudowy."
                return nil
            }
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let updates: [StoredFurnitureAssembly]

            switch operation {
            case .wyrownajDol:
                guard let targetBottom =
                    primary.assembly.placement?.bottomOffset else {
                    throw DomainError.invariantViolation(
                        "Nie można odczytać położenia modułu głównego."
                    )
                }
                updates = selected.map {
                    storedZmieniajacPolozenie(
                        $0,
                        offsetAlongWall:
                            $0.assembly.placement?
                                .offsetAlongWall
                            ?? .zero,
                        bottomOffset: targetBottom
                    )
                }

            case .wyrownajGore:
                guard let primaryPlacement =
                    primary.assembly.placement else {
                    throw DomainError.invariantViolation(
                        "Nie można odczytać położenia modułu głównego."
                    )
                }
                let targetTop =
                    primaryPlacement.bottomOffset.rawValue
                    + primary.assembly.size.height.rawValue

                updates = try selected.map { stored in
                    let targetBottom =
                        targetTop
                        - stored.assembly.size.height.rawValue
                    guard targetBottom >= -0.01 else {
                        throw DomainError.invariantViolation(
                            "Wyrównanie górą przesunęłoby moduł poniżej podłogi."
                        )
                    }
                    return storedZmieniajacPolozenie(
                        stored,
                        offsetAlongWall:
                            stored.assembly.placement?
                                .offsetAlongWall
                            ?? .zero,
                        bottomOffset:
                            Millimeters(max(0, targetBottom))
                    )
                }

            case .domknijOdstepy:
                var cursor = firstPlacement.offsetAlongWall
                var result: [StoredFurnitureAssembly] = []
                result.reserveCapacity(selected.count)

                for stored in selected {
                    let updated = storedZmieniajacPolozenie(
                        stored,
                        offsetAlongWall: cursor
                    )
                    result.append(updated)
                    cursor =
                        cursor
                        + stored.assembly.size.width
                }
                updates = result

            case .rozlozRownomiernie:
                guard let last = selected.last,
                      let lastPlacement = last.assembly.placement else {
                    throw DomainError.invariantViolation(
                        "Nie można wyznaczyć zakresu zaznaczenia."
                    )
                }

                let start = firstPlacement.offsetAlongWall.rawValue
                let end =
                    lastPlacement.offsetAlongWall.rawValue
                    + last.assembly.size.width.rawValue
                let widths = selected.reduce(0.0) {
                    $0 + $1.assembly.size.width.rawValue
                }
                let available = end - start - widths
                let divider = Double(selected.count - 1)
                guard available >= -0.1, divider > 0 else {
                    throw DomainError.invariantViolation(
                        "Zaznaczone moduły nie mają miejsca na równy rozstaw."
                    )
                }
                let gap = max(0, available / divider)
                var cursor = start
                var result: [StoredFurnitureAssembly] = []
                result.reserveCapacity(selected.count)

                for stored in selected {
                    result.append(
                        storedZmieniajacPolozenie(
                            stored,
                            offsetAlongWall: Millimeters(cursor)
                        )
                    )
                    cursor +=
                        stored.assembly.size.width.rawValue
                        + gap
                }
                updates = result

            case .rozlozRownaSzerokosc:
                // Obsługiwane osobną ścieżką (przebudowa + cofanie stanu V065).
                return nil
            }

            let wallHeight = min(
                wall.startHeight.rawValue,
                wall.endHeight.rawValue
            )
            guard updates.allSatisfy({
                guard let placement = $0.assembly.placement else {
                    return false
                }
                return placement.bottomOffset.rawValue >= -0.01
                    && placement.bottomOffset.rawValue
                        + $0.assembly.size.height.rawValue
                        <= wallHeight + 0.1
            }) else {
                throw DomainError.invariantViolation(
                    "Wynik operacji nie mieści się w wysokości ściany."
                )
            }

            return try await zapiszPolozeniaGrupyV066(
                originals: selected,
                updates: updates,
                room: room,
                nazwa: operation.tytul,
                selectedIDs: ids,
                primaryID: primary.id
            )
        } catch {
            errorMessage =
                "Nie udało się wykonać operacji „\(operation.tytul)”: "
                + error.localizedDescription
            return nil
        }
    }

    /// Rozkłada zaznaczone moduły na **równą szerokość** wypełniając ich rozpiętość
    /// (styl PRO100 „podziel na równe"). W odróżnieniu od `.rozlozRownomiernie`
    /// (równe odstępy, stałe szerokości) — przebudowuje każdy moduł do wspólnej
    /// szerokości przez builder, przelicza więzy i zapisuje ze stanem cofania V065.
    /// Szerokości i pozycje liczy `FurnitureRunDistributor` (DomainCore).
    func rozlozRownaSzerokoscV081(
        ids: Set<FurnitureAssemblyID>,
        glowneID: FurnitureAssemblyID?,
        room: RoomDefinition
    ) async -> OperacjaStanuModulowV065? {
        guard !isSaving, ids.count >= 2 else { return nil }

        let selected = storedAssemblies
            .filter { ids.contains($0.id) }
            .sorted {
                ($0.assembly.placement?.offsetAlongWall ?? .zero)
                    < ($1.assembly.placement?.offsetAlongWall ?? .zero)
            }

        guard selected.count == ids.count,
              let first = selected.first,
              let last = selected.last,
              let firstPlacement = first.assembly.placement,
              let lastPlacement = last.assembly.placement,
              let wallID = firstPlacement.wallID,
              let wall = room.geometry.wall(id: wallID),
              selected.allSatisfy({ $0.assembly.placement?.wallID == wallID }) else {
            errorMessage = "Równa szerokość wymaga modułów na jednej ścianie."
            return nil
        }

        // Każdy moduł musi mieć szablon parametryczny ze zmienną szerokością.
        guard selected.allSatisfy({ stored in
            guard let template = template(for: stored) else { return false }
            return template.supportedParameters.contains { $0.key == .width }
        }) else {
            errorMessage =
                "Równa szerokość działa tylko dla modułów parametrycznych o zmiennej szerokości."
            return nil
        }

        let spanStart = firstPlacement.offsetAlongWall
        let spanEnd = lastPlacement.offsetAlongWall + last.assembly.size.width

        isSaving = true
        defer { isSaving = false }

        let originals = selected
        var savedIDs: [FurnitureAssemblyID] = []
        var originalRuns: [FurnitureRun] = []

        do {
            // Rozpiętość liczona przez dystrybutor: traktujemy span jak "ścianę"
            // z zerowymi odsunięciami, a offsety przesuwamy o spanStart.
            let span = spanEnd - spanStart
            let run = try FurnitureRun(
                roomID: room.id,
                wallID: wallID,
                name: "Podział równej szerokości",
                kind: .base,
                startOffset: .zero,
                endOffset: .zero,
                moduleIDs: selected.map(\.id),
                technology: try CabinetRunTechnology()
            )
            let dystrybucja = try FurnitureRunDistributor.distributeEqualWidth(
                wallLength: span,
                run: run
            )
            guard let targetWidth = dystrybucja.equalModuleWidth,
                  targetWidth >= 100 else {
                errorMessage = "Równy podział dałby moduły węższe niż 100 mm."
                return nil
            }

            let selectedIDs = Set(selected.map(\.id))
            originalRuns = try await repositories.runRepository
                .fetchAll(roomID: room.id)
                .filter { !$0.moduleIDs.filter(selectedIDs.contains).isEmpty }

            // Zbuduj przebudowane, repozycjonowane moduły BEZ zapisu (walidacja najpierw).
            let offsetByID = Dictionary(
                uniqueKeysWithValues: dystrybucja.placements.map {
                    ($0.moduleID, spanStart + $0.offsetAlongWall)
                }
            )
            var rebuilt: [StoredFurnitureAssembly] = []
            rebuilt.reserveCapacity(selected.count)

            for stored in selected {
                guard let template = template(for: stored) else {
                    throw DomainError.invariantViolation("Brak szablonu modułu.")
                }
                let newParameters = try stored.parameters.setting(
                    .millimeters(targetWidth),
                    for: .width
                )
                let builder = try builder(for: template)
                var assembly = try builder.build(
                    template: template,
                    parameters: newParameters,
                    preservingIDsFrom: stored.assembly
                )
                assembly.name = stored.assembly.name
                assembly = rozwiazWiezyMebla(assembly)

                if var placement = stored.assembly.placement {
                    placement.offsetAlongWall =
                        offsetByID[stored.id] ?? placement.offsetAlongWall
                    assembly.placement = placement
                }

                let resolved = try template.resolvedParameters(overrides: newParameters)
                rebuilt.append(
                    StoredFurnitureAssembly(
                        roomID: stored.roomID,
                        assembly: assembly,
                        parameters: resolved,
                        createdAt: stored.createdAt,
                        updatedAt: Date()
                    )
                )
            }

            // Walidacja WSZYSTKICH przed jakimkolwiek zapisem (brak częściowych zapisów).
            let rebuiltByID = Dictionary(uniqueKeysWithValues: rebuilt.map { ($0.id, $0) })
            let projectedFinal = storedAssemblies.map {
                rebuiltByID[$0.id]?.assembly ?? $0.assembly
            }
            for updated in rebuilt {
                try validatePlacement(
                    candidate: updated.assembly,
                    wall: wall,
                    room: room,
                    excluding: updated.id,
                    among: projectedFinal
                )
            }

            // Zapis dopiero po walidacji całości.
            for updated in rebuilt {
                try await repositories.assemblyRepository.save(updated)
                savedIDs.append(updated.id)
                upsert(updated)
            }

            // Cofanie na poziomie stanu V065 (ciągi bez zmian — moduleIDs zachowane).
            let przedModuly = originals.map {
                MigawkaStanuModuluV065(furnitureID: $0.id, stored: $0, kartaTechniczna: nil)
            }
            let poModuly = rebuilt.map {
                MigawkaStanuModuluV065(furnitureID: $0.id, stored: $0, kartaTechniczna: nil)
            }
            return OperacjaStanuModulowV065(
                nazwa: "Równa szerokość",
                przed: StanEdycjiModulowV065(moduly: przedModuly, ciagi: originalRuns),
                po: StanEdycjiModulowV065(moduly: poModuly, ciagi: originalRuns),
                zaznaczeniePrzed: glowneID,
                zaznaczeniePo: glowneID,
                zaznaczeniaPrzedV066: ids,
                zaznaczeniaPoV066: ids
            )
        } catch {
            // Wycofanie zapisanych modułów do stanu wyjściowego.
            for original in originals where savedIDs.contains(original.id) {
                try? await repositories.assemblyRepository.save(original)
                upsert(original)
            }
            errorMessage =
                "Nie udało się rozłożyć na równą szerokość: "
                + error.localizedDescription
            return nil
        }
    }

    func usunModulyV066(
        ids: Set<FurnitureAssemblyID>,
        glowneID: FurnitureAssemblyID?
    ) async -> OperacjaStanuModulowV065? {
        guard !isSaving, !ids.isEmpty else {
            return nil
        }

        let selected = storedAssemblies.filter {
            ids.contains($0.id)
        }
        guard selected.count == ids.count,
              let roomID = selected.first?.roomID,
              selected.allSatisfy({ $0.roomID == roomID }) else {
            errorMessage =
                "Nie wszystkie zaznaczone moduły należą do tego samego pomieszczenia."
            return nil
        }

        isSaving = true
        defer { isSaving = false }

        var originalRuns: [FurnitureRun] = []

        let originalCards: [FurnitureAssemblyID: KartaTechnicznaSzafki?] =
            Dictionary(
                uniqueKeysWithValues: selected.map { stored in
                    let key = StabilnyKluczDomenowy.utworz(
                        dla: stored.id,
                        prefiks: "furniture"
                    )
                    return (
                        stored.id,
                        KartaTechnicznaSzafkiStore.card(
                            forModuleKey: key
                        )
                    )
                }
            )

        do {
            let allRuns =
                try await repositories.runRepository
                    .fetchAll(roomID: roomID)
            originalRuns = allRuns.filter { run in
                run.moduleIDs.contains {
                    ids.contains($0)
                }
            }
            let updatedRuns = originalRuns.map { original -> FurnitureRun in
                var updated = original
                updated.moduleIDs.removeAll {
                    ids.contains($0)
                }
                return updated
            }

            for run in updatedRuns {
                try await repositories.runRepository.save(run)
            }

            do {
                for stored in selected {
                    try await repositories.assemblyRepository.delete(
                        id: stored.id
                    )
                }
            } catch {
                for stored in selected {
                    try? await repositories.assemblyRepository.save(
                        stored
                    )
                }
                for run in originalRuns {
                    try? await repositories.runRepository.save(run)
                }
                throw error
            }

            for stored in selected {
                let key = StabilnyKluczDomenowy.utworz(
                    dla: stored.id,
                    prefiks: "furniture"
                )
                KartaTechnicznaSzafkiStore.usunKarte(
                    forModuleKey: key
                )
            }

            storedAssemblies.removeAll {
                ids.contains($0.id)
            }
            rebuildAssemblyIndex()
            renderRevision &+= 1

            let beforeModules = selected.map { stored in
                MigawkaStanuModuluV065(
                    furnitureID: stored.id,
                    stored: stored,
                    kartaTechniczna:
                        originalCards[stored.id] ?? nil
                )
            }
            let afterModules = selected.map { stored in
                MigawkaStanuModuluV065(
                    furnitureID: stored.id,
                    stored: nil,
                    kartaTechniczna: nil
                )
            }

            return OperacjaStanuModulowV065(
                nazwa:
                    ids.count > 1
                    ? "Usunięcie grupy modułów"
                    : "Usunięcie modułu",
                przed: StanEdycjiModulowV065(
                    moduly: beforeModules,
                    ciagi: originalRuns
                ),
                po: StanEdycjiModulowV065(
                    moduly: afterModules,
                    ciagi: updatedRuns
                ),
                zaznaczeniePrzed:
                    glowneID ?? selected.first?.id,
                zaznaczeniePo: nil,
                zaznaczeniaPrzedV066: ids,
                zaznaczeniaPoV066: []
            )
        } catch {
            for stored in selected {
                try? await repositories.assemblyRepository.save(
                    stored
                )
            }
            for run in originalRuns {
                try? await repositories.runRepository.save(run)
            }
            for (id, card) in originalCards {
                let key = StabilnyKluczDomenowy.utworz(
                    dla: id,
                    prefiks: "furniture"
                )
                if let card {
                    KartaTechnicznaSzafkiStore.save(card)
                } else {
                    KartaTechnicznaSzafkiStore.usunKarte(
                        forModuleKey: key
                    )
                }
            }
            errorMessage =
                "Nie udało się usunąć zaznaczonych modułów: "
                + error.localizedDescription
            return nil
        }
    }

    private func zapiszPolozeniaGrupyV066(
        originals: [StoredFurnitureAssembly],
        updates: [StoredFurnitureAssembly],
        room: RoomDefinition,
        nazwa: String,
        selectedIDs: Set<FurnitureAssemblyID>,
        primaryID: FurnitureAssemblyID?
    ) async throws -> WynikOperacjiGrupowejV066 {
        guard originals.count == updates.count,
              !updates.isEmpty else {
            throw DomainError.invariantViolation(
                "Operacja grupowa nie zawiera poprawnych zmian."
            )
        }

        let originalByID = Dictionary(
            uniqueKeysWithValues: originals.map {
                ($0.id, $0)
            }
        )
        let updatesByID = Dictionary(
            uniqueKeysWithValues: updates.map {
                ($0.id, $0)
            }
        )
        guard Set(originalByID.keys) == Set(updatesByID.keys) else {
            throw DomainError.invariantViolation(
                "Operacja grupowa zmieniła zestaw identyfikatorów."
            )
        }

        let changed = updates.filter { updated in
            guard let original = originalByID[updated.id],
                  let before = original.assembly.placement,
                  let after = updated.assembly.placement else {
                return false
            }
            return abs(
                before.offsetAlongWall.rawValue
                    - after.offsetAlongWall.rawValue
            ) > 0.1
            || abs(
                before.bottomOffset.rawValue
                    - after.bottomOffset.rawValue
            ) > 0.1
        }
        guard !changed.isEmpty else {
            throw DomainError.invariantViolation(
                "Moduły są już ustawione w żądany sposób."
            )
        }

        let finalStored = storedAssemblies.map {
            updatesByID[$0.id] ?? $0
        }
        let finalAssemblies = finalStored.map(\.assembly)

        for updated in updates {
            guard let wallID = updated.assembly.placement?.wallID,
                  let wall = room.geometry.wall(id: wallID) else {
                throw DomainError.invariantViolation(
                    "Nie znaleziono ściany dla zaznaczonego modułu."
                )
            }
            try validatePlacement(
                candidate: updated.assembly,
                wall: wall,
                room: room,
                excluding: updated.id,
                among: finalAssemblies
            )
        }

        do {
            for updated in changed {
                try await repositories.assemblyRepository.save(
                    updated
                )
            }
        } catch {
            for original in originals {
                try? await repositories.assemblyRepository.save(
                    original
                )
            }
            throw error
        }

        zastosujAktualizacjePolozen(changed)

        let before = originals.compactMap { stored -> MigawkaPolozeniaModuluV064? in
            guard let placement = stored.assembly.placement else {
                return nil
            }
            return MigawkaPolozeniaModuluV064(
                furnitureID: stored.id,
                placement: placement
            )
        }
        let after = updates.compactMap { stored -> MigawkaPolozeniaModuluV064? in
            guard let placement = stored.assembly.placement else {
                return nil
            }
            return MigawkaPolozeniaModuluV064(
                furnitureID: stored.id,
                placement: placement
            )
        }

        let positionOperation = OperacjaPolozeniaModulowV064(
            nazwa: nazwa,
            przed: before,
            po: after
        )
        let groupOperation = OperacjaPolozeniaGrupyV066(
            nazwa: nazwa,
            polozenia: positionOperation,
            zaznaczeniaPrzed: selectedIDs,
            zaznaczeniaPo: selectedIDs,
            zaznaczenieGlownePrzed: primaryID,
            zaznaczenieGlownePo: primaryID
        )
        return WynikOperacjiGrupowejV066(
            operacja: groupOperation,
            zaznaczoneID: selectedIDs,
            glowneID: primaryID
        )
    }

    private func unikalnaNazwaDuplikatuGrupyV067(
        for sourceName: String,
        reservedNames: inout Set<String>
    ) -> String {
        let base = sourceName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let firstCandidate = base + " – kopia"

        if reservedNames.insert(
            firstCandidate.lowercased()
        ).inserted {
            return firstCandidate
        }

        var number = 2
        while true {
            let candidate = "\(firstCandidate) \(number)"
            if reservedNames.insert(
                candidate.lowercased()
            ).inserted {
                return candidate
            }
            number += 1
        }
    }

    private func przesunieteDuplikatyGrupyV067(
        _ duplicates: [StoredFurnitureAssembly],
        dx: Double
    ) -> [StoredFurnitureAssembly] {
        duplicates.compactMap { duplicate in
            guard var placement = duplicate.assembly.placement else {
                return nil
            }

            placement.offsetAlongWall = Millimeters(
                placement.offsetAlongWall.rawValue + dx
            )

            var assembly = duplicate.assembly
            assembly.placement = placement

            return StoredFurnitureAssembly(
                roomID: duplicate.roomID,
                assembly: assembly,
                parameters: duplicate.parameters,
                createdAt: duplicate.createdAt,
                updatedAt: Date()
            )
        }
    }

    private func przesuniecieDlaDuplikatuGrupyV067(
        duplicates: [StoredFurnitureAssembly],
        sources: [StoredFurnitureAssembly],
        wall: WallSegment,
        room: RoomDefinition
    ) throws -> Double {
        guard let geometry = room.geometry.geometry(of: wall.id),
              case .line = geometry else {
            throw DomainError.invariantViolation(
                "Duplikowanie grupy wymaga prostego odcinka ściany."
            )
        }

        let placements = sources.compactMap {
            $0.assembly.placement
        }
        guard placements.count == sources.count,
              let groupMin = placements.map({
                  $0.offsetAlongWall.rawValue
              }).min(),
              let groupMax = zip(sources, placements).map({
                  $0.1.offsetAlongWall.rawValue
                      + $0.0.assembly.size.width.rawValue
              }).max() else {
            throw DomainError.invariantViolation(
                "Nie można wyznaczyć zakresu zaznaczonej grupy."
            )
        }

        let groupWidth = groupMax - groupMin
        let minimumTranslation = -groupMin
        let maximumTranslation =
            geometry.length.rawValue - groupMax

        guard groupWidth > 0,
              minimumTranslation <= maximumTranslation else {
            throw DomainError.invariantViolation(
                "Zaznaczona grupa nie mieści się na tej ścianie."
            )
        }

        let preferredTranslation = groupWidth
        var rawCandidates: [Double] = [
            preferredTranslation,
            -groupWidth,
            minimumTranslation,
            maximumTranslation
        ]

        for stored in storedAssemblies {
            guard let placement = stored.assembly.placement,
                  placement.wallID == wall.id else {
                continue
            }

            rawCandidates.append(
                placement.offsetAlongWall.rawValue
                    + stored.assembly.size.width.rawValue
                    - groupMin
            )
            rawCandidates.append(
                placement.offsetAlongWall.rawValue
                    - groupMax
            )
        }

        for window in room.windows
        where window.placement.wallID == wall.id {
            rawCandidates.append(
                window.placement.offsetFromWallStart.rawValue
                    + window.placement.width.rawValue
                    - groupMin
            )
            rawCandidates.append(
                window.placement.offsetFromWallStart.rawValue
                    - groupMax
            )
        }

        for door in room.doors
        where door.placement.wallID == wall.id {
            rawCandidates.append(
                door.placement.offsetFromWallStart.rawValue
                    + door.placement.width.rawValue
                    - groupMin
            )
            rawCandidates.append(
                door.placement.offsetFromWallStart.rawValue
                    - groupMax
            )
        }

        for bay in room.bayProjections
        where bay.wallID == wall.id && bay.direction == .inward {
            rawCandidates.append(
                bay.offsetFromWallStart.rawValue
                    + bay.width.rawValue
                    - groupMin
            )
            rawCandidates.append(
                bay.offsetFromWallStart.rawValue
                    - groupMax
            )
        }

        var seen: Set<Int64> = []
        let candidates = rawCandidates
            .filter {
                $0 >= minimumTranslation - 0.01
                    && $0 <= maximumTranslation + 0.01
            }
            .filter {
                seen.insert(
                    Int64(($0 * 10).rounded())
                ).inserted
            }
            .sorted { lhs, rhs in
                let leftDistance =
                    abs(lhs - preferredTranslation)
                let rightDistance =
                    abs(rhs - preferredTranslation)
                if abs(leftDistance - rightDistance) > 0.01 {
                    return leftDistance < rightDistance
                }
                return lhs > rhs
            }

        for translation in candidates {
            let moved = przesunieteDuplikatyGrupyV067(
                duplicates,
                dx: translation
            )
            guard moved.count == duplicates.count else {
                continue
            }

            let movedAssemblies = moved.map(\.assembly)
            let validationPool = assemblies + movedAssemblies

            do {
                for candidate in movedAssemblies {
                    try validatePlacement(
                        candidate: candidate,
                        wall: wall,
                        room: room,
                        excluding: candidate.id,
                        among: validationPool
                    )
                }
                return translation
            } catch {
                continue
            }
        }

        throw DomainError.invariantViolation(
            "Na tej ścianie nie znaleziono miejsca na kopię całej grupy."
        )
    }

    private func nazwaDuplikatuV065(
        for sourceName: String
    ) -> String {
        let base = sourceName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let firstCandidate = base + " – kopia"
        let existingNames = Set(
            storedAssemblies.map {
                $0.assembly.name.lowercased()
            }
        )

        guard existingNames.contains(firstCandidate.lowercased()) else {
            return firstCandidate
        }

        var number = 2
        while existingNames.contains(
            "\(firstCandidate) \(number)".lowercased()
        ) {
            number += 1
        }
        return "\(firstCandidate) \(number)"
    }

    private func wolneOdsuniecieDlaDuplikatuV065(
        duplicate: FurnitureAssembly,
        source: FurnitureAssembly,
        wall: WallSegment,
        room: RoomDefinition
    ) throws -> Millimeters {
        guard let sourcePlacement = source.placement,
              let duplicatePlacement = duplicate.placement,
              let geometry = room.geometry.geometry(of: wall.id),
              case .line = geometry else {
            throw DomainError.invariantViolation(
                "Duplikowanie wymaga prostego odcinka ściany."
            )
        }

        let width = duplicate.size.width.rawValue
        let maximumOffset = geometry.length.rawValue - width
        guard maximumOffset >= 0 else {
            throw DomainError.invariantViolation(
                "Moduł jest szerszy niż wybrana ściana."
            )
        }

        let preferred =
            sourcePlacement.offsetAlongWall.rawValue
            + source.size.width.rawValue
        var rawCandidates: [Double] = [
            preferred,
            sourcePlacement.offsetAlongWall.rawValue - width,
            0,
            maximumOffset
        ]

        for stored in storedAssemblies {
            guard let placement = stored.assembly.placement,
                  placement.wallID == duplicatePlacement.wallID else {
                continue
            }

            rawCandidates.append(
                placement.offsetAlongWall.rawValue
                + stored.assembly.size.width.rawValue
            )
            rawCandidates.append(
                placement.offsetAlongWall.rawValue - width
            )
        }

        for window in room.windows
        where window.placement.wallID == wall.id {
            rawCandidates.append(
                window.placement.offsetFromWallStart.rawValue
                + window.placement.width.rawValue
            )
            rawCandidates.append(
                window.placement.offsetFromWallStart.rawValue - width
            )
        }

        for door in room.doors
        where door.placement.wallID == wall.id {
            rawCandidates.append(
                door.placement.offsetFromWallStart.rawValue
                + door.placement.width.rawValue
            )
            rawCandidates.append(
                door.placement.offsetFromWallStart.rawValue - width
            )
        }

        for bay in room.bayProjections
        where bay.wallID == wall.id && bay.direction == .inward {
            rawCandidates.append(
                bay.offsetFromWallStart.rawValue
                + bay.width.rawValue
            )
            rawCandidates.append(
                bay.offsetFromWallStart.rawValue - width
            )
        }

        var seen: Set<Int64> = []
        let candidates = rawCandidates
            .filter { $0 >= 0 && $0 <= maximumOffset }
            .filter {
                seen.insert(Int64(($0 * 10).rounded())).inserted
            }
            .sorted { lhs, rhs in
                let lhsDistance = abs(lhs - preferred)
                let rhsDistance = abs(rhs - preferred)
                if abs(lhsDistance - rhsDistance) > 0.01 {
                    return lhsDistance < rhsDistance
                }
                return lhs > rhs
            }

        for rawOffset in candidates {
            var candidate = duplicate
            guard var placement = candidate.placement else { continue }
            placement.offsetAlongWall = Millimeters(rawOffset)
            candidate.placement = placement

            do {
                try validatePlacement(
                    candidate: candidate,
                    wall: wall,
                    room: room,
                    excluding: nil
                )
                return placement.offsetAlongWall
            } catch {
                continue
            }
        }

        throw DomainError.invariantViolation(
            "Na tej ścianie nie znaleziono wolnego miejsca na duplikat."
        )
    }

    func deleteModule(
        id: FurnitureAssemblyID
    ) async {
        do {
            try await repositories.assemblyRepository.delete(id: id)
            storedAssemblies.removeAll { $0.id == id }
            rebuildAssemblyIndex()

            KartaTechnicznaSzafkiStore
                .usunKarte(
                    forModuleKey:
                        StabilnyKluczDomenowy
                            .utworz(
                                dla: id,
                                prefiks: "furniture"
                            )
                )

            renderRevision &+= 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }


    private func upsert(
        _ stored: StoredFurnitureAssembly
    ) {
        if let index = storedAssemblies.firstIndex(where: { $0.id == stored.id }) {
            storedAssemblies[index] = stored
        } else {
            storedAssemblies.append(stored)
        }

        storedAssemblies.sort { lhs, rhs in
            let lhsPlacement = lhs.assembly.placement
            let rhsPlacement = rhs.assembly.placement

            if lhsPlacement?.wallID == rhsPlacement?.wallID {
                return (lhsPlacement?.offsetAlongWall ?? .zero)
                    < (rhsPlacement?.offsetAlongWall ?? .zero)
            }

            return lhs.createdAt < rhs.createdAt
        }

        rebuildAssemblyIndex()
        renderRevision &+= 1
    }

    /// Wymusza ponowne renderowanie canvasów 2D bez zapisu stanu.
    /// Używaj po bezpośredniej modyfikacji KartaTechnicznaSzafkiStore
    /// (np. zmiana liczby frontów z SzybkiEdytorModuluV083).
    func forceRenderRefresh() {
        renderRevision &+= 1
    }

    private func parameterOverrides(
        from data: KonfiguracjaModuluMeblowegoDane,
        template: FurnitureTemplate
    ) throws -> FurnitureParameterSet {
        let supportedKeys =
            Set(
                template.supportedParameters
                    .map(\.key)
            )

        var entries: [FurnitureParameterEntry] = []

        func append(
            _ key: FurnitureParameterKey,
            _ value: FurnitureParameterValue
        ) {
            guard supportedKeys.contains(key) else {
                return
            }

            entries.append(
                .init(
                    key: key,
                    value: value
                )
            )
        }

        append(.width, .millimeters(data.width))
        append(.height, .millimeters(data.height))
        append(.depth, .millimeters(data.depth))
        append(.shelfCount, .integer(data.shelfCount))
        append(
            .carcassThickness,
            .millimeters(data.carcassThickness)
        )
        append(
            .shelfFrontSetback,
            .millimeters(data.shelfFrontSetback)
        )
        append(
            .backType,
            .cabinetBackType(data.backType)
        )
        append(
            .backThickness,
            .millimeters(data.backThickness)
        )
        append(
            .backInset,
            .millimeters(data.backInset)
        )
        append(
            .topConstruction,
            .cabinetTopConstruction(data.topConstruction)
        )
        append(
            .topRailDepth,
            .millimeters(data.topRailDepth)
        )
        append(
            .frontEnabled,
            .boolean(data.frontEnabled)
        )
        append(
            .frontThickness,
            .millimeters(data.frontThickness)
        )
        append(
            .frontGap,
            .millimeters(data.frontGap)
        )
        append(
            .frontInset,
            .millimeters(data.frontInset)
        )
        append(
            .openingTechnology,
            .openingTechnology(data.openingTechnology)
        )
        append(
            .bottomShortening,
            .millimeters(data.bottomShortening)
        )

        return try FurnitureParameterSet(
            entries: entries
        )
    }

    private func builder(
        for template: FurnitureTemplate
    ) throws -> any FurnitureBuilding {
        if let standardKind =
            StandardFurnitureModuleCatalogV077.kind(
                for: template
            ) {
            return ParametricFurnitureBuilderV077(
                builderType: template.builderType,
                assemblyKind:
                    assemblyKind(
                        for: standardKind,
                        fallback: template.builderType
                    )
            )
        }

        return try builder(for: template.builderType)
    }

    private func builder(
        for type: FurnitureBuilderType
    ) throws -> any FurnitureBuilding {
        switch type {
        case .baseCabinet:
            return BaseCabinetBuilder()
        case .wallCabinet:
            return WallCabinetBuilder()
        case .wardrobe:
            return ParametricFurnitureBuilderV077(
                builderType: .wardrobe,
                assemblyKind: .wardrobe
            )
        case .slidingWardrobe:
            return ParametricFurnitureBuilderV077(
                builderType: .slidingWardrobe,
                assemblyKind: .slidingWardrobe
            )
        case .desk:
            return ParametricFurnitureBuilderV077(
                builderType: .desk,
                assemblyKind: .desk
            )
        case .shelving:
            return ParametricFurnitureBuilderV077(
                builderType: .shelving,
                assemblyKind: .shelving
            )
        case .table:
            return ParametricFurnitureBuilderV077(
                builderType: .table,
                assemblyKind: .table
            )
        case .recessBuiltIn:
            return ParametricFurnitureBuilderV077(
                builderType: .recessBuiltIn,
                assemblyKind: .recessBuiltIn
            )
        case .custom:
            return KitchenFillerBuilderV015()
        default:
            throw DomainError.invariantViolation(
                "Szablon \(type.rawValue) nie ma jeszcze buildera dostępnego w interfejsie."
            )
        }
    }

    private func assemblyKind(
        for standardKind: StandardFurnitureModuleKindV077,
        fallback builderType: FurnitureBuilderType
    ) -> FurnitureAssemblyKind {
        switch standardKind {
        case .slidingWardrobe:
            return .slidingWardrobe
        case .hingedWardrobe,
             .builtInWardrobe,
             .dressingRoom,
             .pantryStorage,
             .bathroomTallCabinet,
             .laundryUtility,
             .utilityCabinet,
             .coatCloset,
             .underStairsBuiltIn,
             .slopedBuiltIn:
            return .wardrobe
        case .bookcase:
            return .shelving
        case .desk:
            return .desk
        case .table:
            return .table
        case .wallPanel:
            return .recessBuiltIn
        case .kitchenIsland,
             .kitchenDrawerBase,
             .sinkBase,
             .cornerBase,
             .cargoCabinet,
             .applianceHousing,
             .kitchenWallCabinet,
             .hoodWallCabinet,
             .glassWallCabinet,
             .storage,
             .bathroomVanity,
             .hallwayShoeCabinet,
             .hallwayBench,
             .tvUnit:
            return .cabinet
        }
    }

    private func anchoringMode(
        for template: FurnitureTemplate
    ) -> FurnitureAnchoringMode {
        if let finishingMode =
            StandardKitchenFinishingTemplatesV015.anchoringMode(
                for: template
            ) {
            return finishingMode
        }

        if let catalogMode = StandardKitchenTemplatesV0143.anchoringMode(
            for: template
        ) {
            return catalogMode
        }

        if let generalMode =
            StandardFurnitureModuleCatalogV077
            .anchoringMode(
                for: template
            ) {
            return generalMode
        }

        switch template.category {
        case .kitchenWallCabinet:
            return .wallMounted
        case .kitchenTallCabinet,
             .recessBuiltIn,
             .slidingWardrobe:
            return .builtIn
        default:
            break
        }

        switch template.builderType {
        case .wallCabinet:
            return .wallMounted
        default:
            return .floorStanding
        }
    }

    private func defaultBottomOffset(
        for template: FurnitureTemplate
    ) -> Millimeters {
        StandardKitchenFinishingTemplatesV015.defaultBottomOffset(
            for: template
        )
        ?? StandardKitchenTemplatesV0143.defaultBottomOffset(
            for: template
        )
        ?? StandardFurnitureModuleCatalogV077.defaultBottomOffset(
            for: template
        )
        ?? (
            anchoringMode(for: template) == .wallMounted
            ? 1400
            : .zero
        )
    }

    private func overlaps(
        lhsStart: Millimeters,
        lhsLength: Millimeters,
        rhsStart: Millimeters,
        rhsLength: Millimeters
    ) -> Bool {
        let overlapStart = max(
            lhsStart.rawValue,
            rhsStart.rawValue
        )
        let overlapEnd = min(
            (lhsStart + lhsLength).rawValue,
            (rhsStart + rhsLength).rawValue
        )

        // Taki sam próg jak w walidatorze kolizji v0.14.3.
        // Sam styk krawędzi nie blokuje kolejnego modułu.
        return overlapEnd - overlapStart > 0.1
    }

    private func validatePlacement(
        candidate: FurnitureAssembly,
        wall: WallSegment,
        room: RoomDefinition,
        excluding assemblyID: FurnitureAssemblyID?,
        among candidates: [FurnitureAssembly]? = nil
    ) throws {
        guard let placement = candidate.placement,
              placement.roomID == room.id,
              placement.wallID == wall.id else {
            throw DomainError.invariantViolation(
                "Moduł nie ma poprawnego osadzenia w wybranym pomieszczeniu."
            )
        }

        guard let geometry = room.geometry.geometry(of: wall.id) else {
            throw DomainError.invariantViolation(
                "Nie znaleziono geometrii wskazanej ściany."
            )
        }

        guard case .line = geometry else {
            throw DomainError.invariantViolation(
                "W tej wersji moduły można dostawiać wyłącznie do prostych odcinków ścian."
            )
        }

        let rightEdge = placement.offsetAlongWall + candidate.size.width
        guard rightEdge <= geometry.length else {
            let missing = rightEdge - geometry.length
            throw DomainError.invariantViolation(
                "Moduł wychodzi poza ścianę o \(formatted(missing))."
            )
        }

        if let conflicting = MebelCollisionValidatorV0143.firstCollision(
            for: candidate,
            excluding: assemblyID,
            among: candidates ?? assemblies
        ) {
            throw DomainError.invariantViolation(
                "Moduł koliduje z \(conflicting.name)."
            )
        }

        try validateArchitecturalClearance(
            candidate: candidate,
            room: room
        )
    }

    private func validateArchitecturalClearance(
        candidate: FurnitureAssembly,
        room: RoomDefinition
    ) throws {
        guard let placement = candidate.placement,
              let wallID = placement.wallID else {
            return
        }

        let openings: [(
            title: String,
            x: Millimeters,
            y: Millimeters,
            width: Millimeters,
            height: Millimeters
        )] =
            room.windows.compactMap { window in
                guard window.placement.wallID == wallID else {
                    return nil
                }
                return (
                    "oknem",
                    window.placement.offsetFromWallStart,
                    window.placement.bottomOffset,
                    window.placement.width,
                    window.placement.height
                )
            }
            + room.doors.compactMap { door in
                guard door.placement.wallID == wallID else {
                    return nil
                }
                return (
                    "drzwiami",
                    door.placement.offsetFromWallStart,
                    door.placement.bottomOffset,
                    door.placement.width,
                    door.placement.height
                )
            }
            + room.bayProjections.compactMap { bay in
                guard bay.wallID == wallID,
                      bay.direction == .inward else {
                    return nil
                }
                return (
                    "uskokiem ściany",
                    bay.offsetFromWallStart,
                    bay.bottomOffset,
                    bay.width,
                    bay.height
                )
            }

        for opening in openings {
            let horizontal = overlaps(
                lhsStart: placement.offsetAlongWall,
                lhsLength: candidate.size.width,
                rhsStart: opening.x,
                rhsLength: opening.width
            )
            let vertical = overlaps(
                lhsStart: placement.bottomOffset,
                lhsLength: candidate.size.height,
                rhsStart: opening.y,
                rhsLength: opening.height
            )

            if horizontal, vertical {
                throw DomainError.invariantViolation(
                    "Moduł koliduje z \(opening.title) na wybranej ścianie."
                )
            }
        }
    }

    private func formatted(
        _ value: Millimeters
    ) -> String {
        "\(value.rawValue.formatted(.number.precision(.fractionLength(0...1)))) mm"
    }
}
