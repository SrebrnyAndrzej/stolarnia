import DomainCore
import Persistence
import SwiftUI

enum ProjectReadinessIssueStatusV078:
    String,
    CaseIterable,
    Identifiable,
    Hashable
{
    case info
    case warning
    case blocking

    var id: String { rawValue }

    var title: String {
        switch self {
        case .info:
            return "Informacja"
        case .warning:
            return "Do sprawdzenia"
        case .blocking:
            return "Blokada"
        }
    }

    var symbol: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .blocking:
            return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .blocking:
            return .red
        }
    }
}

enum ProjectReadinessAreaV078:
    String,
    Hashable
{
    case measurement
    case project
    case pricing
    case production

    var title: String {
        switch self {
        case .measurement:
            return "Pomiar"
        case .project:
            return "Projekt"
        case .pricing:
            return "Wycena"
        case .production:
            return "Produkcja"
        }
    }
}

struct ProjectReadinessIssueV078:
    Identifiable,
    Hashable
{
    var id: String
    var status:
        ProjectReadinessIssueStatusV078
    var area:
        ProjectReadinessAreaV078
    var title: String
    var message: String
    var action: String
}

struct ProjectReadinessReportV078:
    Hashable
{
    var issues:
        [ProjectReadinessIssueV078]

    static let empty = Self(
        issues: []
    )

    var blockers:
        [ProjectReadinessIssueV078]
    {
        issues.filter {
            $0.status == .blocking
        }
    }

    var warnings:
        [ProjectReadinessIssueV078]
    {
        issues.filter {
            $0.status == .warning
        }
    }

    var infos:
        [ProjectReadinessIssueV078]
    {
        issues.filter {
            $0.status == .info
        }
    }

    var blockingCount: Int {
        blockers.count
    }

    var warningCount: Int {
        warnings.count
    }

    var isReadyForPricing:
        Bool
    {
        blockingCount == 0
    }

    var status:
        ProjectReadinessIssueStatusV078
    {
        if blockingCount > 0 {
            return .blocking
        }

        if warningCount > 0 {
            return .warning
        }

        return .info
    }

    var title: String {
        if blockingCount > 0 {
            return "\(blockingCount) blokad przed wyceną i produkcją"
        }

        if warningCount > 0 {
            return "\(warningCount) rzeczy do sprawdzenia"
        }

        return "Projekt gotowy do kolejnych etapów"
    }

    var message: String {
        if let first = blockers.first {
            return first.message
        }

        if let first = warnings.first {
            return first.message
        }

        return "Materiały, formatki i podstawowe dane produkcyjne są spójne."
    }
}

enum ProjectReadinessEngineV078 {
    static func build(
        room:
            RoomDefinition?,
        assemblies:
            [StoredFurnitureAssembly],
        materialy:
            GlobalneMaterialyPomieszczenia,
        lista:
            ListaFormatekProjektuV070,
        raport:
            RaportRozkrojuPlytV071
    ) -> ProjectReadinessReportV078 {
        var issues:
            [ProjectReadinessIssueV078] = []

        appendMeasurementIssues(
            room: room,
            to: &issues
        )
        appendProjectIssues(
            room: room,
            assemblies: assemblies,
            lista: lista,
            to: &issues
        )
        appendPricingIssues(
            materialy: materialy,
            lista: lista,
            to: &issues
        )
        appendProductionIssues(
            lista: lista,
            raport: raport,
            to: &issues
        )

        return ProjectReadinessReportV078(
            issues:
                issues.sorted(
                    by: issueOrder
                )
        )
    }

    private static func appendMeasurementIssues(
        room:
            RoomDefinition?,
        to issues:
            inout [ProjectReadinessIssueV078]
    ) {
        guard let room else {
            append(
                "measurement-context-missing",
                .info,
                .measurement,
                "Brak kontekstu pomieszczenia",
                "Widok produkcji działa bez pełnego kontekstu pomiaru, więc część reguł terenowych jest pomijana.",
                "Otwórz produkcję z workspace aktywnego pomieszczenia.",
                to: &issues
            )
            return
        }

        if room
            .geometry
            .walls
            .isEmpty {
            append(
                "measurement-no-walls",
                .blocking,
                .measurement,
                "Brak obrysu pomieszczenia",
                "Pomieszczenie nie ma ścian, więc nie da się bezpiecznie przejść do wyceny ani produkcji.",
                "Wykonaj pomiar po obrysie i zapisz ściany.",
                to: &issues
            )
        }

        let invalidWalls =
            room
            .geometry
            .walls
            .filter {
                wall in

                guard let segment =
                    room.geometry.geometry(
                        of: wall.id
                    )
                else {
                    return true
                }

                return segment.length.rawValue
                    <= 0
                    || wall.startHeight.rawValue
                    <= 0
                    || wall.endHeight.rawValue
                    <= 0
            }

        if !invalidWalls.isEmpty {
            append(
                "measurement-invalid-walls",
                .blocking,
                .measurement,
                "Niepełne wymiary ścian",
                "\(invalidWalls.count) ścian ma brakujący wymiar długości albo wysokości.",
                "Uzupełnij długości i wysokości w pomiarze pomieszczenia.",
                to: &issues
            )
        }

        let unknownConstruction =
            room
            .geometry
            .walls
            .filter {
                $0.constructionType == .unknown
            }

        if !unknownConstruction.isEmpty {
            append(
                "measurement-wall-construction",
                .warning,
                .measurement,
                "Nieopisany typ ścian",
                "\(unknownConstruction.count) ścian nie ma typu konstrukcji, co utrudnia dobór mocowań i montażu.",
                "Oznacz mur, beton, GK albo inną konstrukcję ściany.",
                to: &issues
            )
        }

        if isKitchenLike(room.name),
           room.windows.isEmpty,
           room.doors.isEmpty,
           room.recesses.isEmpty,
           room.obstacles.isEmpty,
           room.bayProjections.isEmpty {
            append(
                "measurement-kitchen-field-data",
                .warning,
                .measurement,
                "Brak danych terenowych kuchni",
                "Kuchnia nie ma zapisanych otworów, przeszkód ani wnęk. Przed wyceną warto potwierdzić okna, drzwi, piony i instalacje.",
                "Dodaj elementy ścian albo zdjęcia terenowe w module pomiaru.",
                to: &issues
            )
        }
    }

    private static func appendProjectIssues(
        room:
            RoomDefinition?,
        assemblies:
            [StoredFurnitureAssembly],
        lista:
            ListaFormatekProjektuV070,
        to issues:
            inout [ProjectReadinessIssueV078]
    ) {
        if assemblies.isEmpty {
            append(
                "project-no-modules",
                .blocking,
                .project,
                "Brak modułów meblowych",
                "Projekt nie ma jeszcze modułów, więc BOM, wycena i produkcja nie mają z czego powstać.",
                "Dodaj moduły w Planie 2D albo Elewacji.",
                to: &issues
            )
            return
        }

        if lista.formatki.isEmpty {
            append(
                "project-no-cutlist",
                .blocking,
                .project,
                "Brak formatek",
                "Moduły istnieją, ale generator nie utworzył żadnych formatek produkcyjnych.",
                "Sprawdź konfigurację modułów i ich komponenty.",
                to: &issues
            )
        }

        let withoutPlacement =
            assemblies.filter {
                $0.assembly.placement == nil
            }

        if !withoutPlacement.isEmpty {
            append(
                "project-module-placement",
                .warning,
                .project,
                "Moduły bez położenia",
                "\(withoutPlacement.count) modułów nie ma zapisanego położenia przy ścianie lub w pomieszczeniu.",
                "Ustaw moduły na planie albo w elewacji.",
                to: &issues
            )
        }

        if let room {
            // Walidacja: suma szerokości modułów na ścianie vs długość ściany
            for wall in room.geometry.walls {
                guard let wallGeom = room.geometry.geometry(of: wall.id) else { continue }
                let wallLengthMM = wallGeom.length.rawValue
                guard wallLengthMM > 0 else { continue }

                let totalWidthMM = assemblies
                    .filter { $0.assembly.placement?.wallID == wall.id }
                    .reduce(0.0) { $0 + $1.assembly.size.width.rawValue }

                if totalWidthMM > wallLengthMM + 10 {
                    let overflow = Int((totalWidthMM - wallLengthMM).rounded())
                    let safeWallName = String(
                        wall.name
                            .replacingOccurrences(of: " ", with: "-")
                            .prefix(30)
                    )
                    append(
                        "project-overflows-wall-\(safeWallName)",
                        .blocking,
                        .project,
                        "Ciąg przekracza ścianę \"\(wall.name)\"",
                        "Suma szerokości modułów (\(Int(totalWidthMM)) mm) jest o \(overflow) mm większa niż długość ściany (\(Int(wallLengthMM)) mm). Ciąg nie zmieści się w miejscu montażu.",
                        "Usuń lub zwęź moduły na ścianie \"\(wall.name)\", aby suma szerokości ≤ \(Int(wallLengthMM)) mm.",
                        to: &issues
                    )
                }
            }

            let wrongRoom =
                assemblies.filter {
                    stored in

                    if stored.roomID != room.id {
                        return true
                    }

                    if let placement =
                        stored
                        .assembly
                        .placement {
                        return placement.roomID
                            != room.id
                    }

                    return false
                }

            if !wrongRoom.isEmpty {
                append(
                    "project-room-mismatch",
                    .blocking,
                    .project,
                    "Moduły z innego pomieszczenia",
                    "\(wrongRoom.count) modułów ma niespójne przypisanie pomieszczenia.",
                    "Odśwież workspace albo przenieś moduły do aktywnego pomieszczenia.",
                    to: &issues
                )
            }

            // Walidacja skosu Typ 2 (ucięty tył) — sprawdź czy mebel mieści
            // się w głąb pod pochyłym stropem. Wywołujemy engine bezpośrednio,
            // bo synchronizacja paneli może jeszcze nie być gotowa.
            appendSlopeDepthIssues(
                room: room,
                assemblies: assemblies,
                to: &issues
            )
        }
    }

    private static func appendSlopeDepthIssues(
        room: RoomDefinition,
        assemblies: [StoredFurnitureAssembly],
        to issues: inout [ProjectReadinessIssueV078]
    ) {
        var tooDeepNames: [String] = []

        for stored in assemblies {
            let assembly = stored.assembly
            guard
                let placement = assembly.placement,
                let wallID = placement.wallID,
                let profile = SilnikSkosuPomieszczeniaV069
                    .profilSkosuGlebokosci(dla: wallID, w: room)
            else { continue }

            do {
                _ = try SilnikSkosuPomieszczeniaV069.konturMeblaUcietyTyl(
                    glebokoscMM: assembly.size.depth.rawValue,
                    wysokoscMM: assembly.size.height.rawValue,
                    profil: profile
                )
            } catch BladSkosuPomieszczeniaV069.mebelNieMiesciSiePodSkosem {
                tooDeepNames.append(assembly.name)
            } catch {
                // Inne błędy profilu — pomijamy w tej walidacji
            }
        }

        if !tooDeepNames.isEmpty {
            let names = tooDeepNames.prefix(3).joined(separator: ", ")
            let suffix = tooDeepNames.count > 3 ? " i \(tooDeepNames.count - 3) więcej" : ""
            append(
                "project-slope-depth-overflow",
                .blocking,
                .project,
                "Mebel nie mieści się pod skosem sufitu",
                "\(names)\(suffix) \(tooDeepNames.count == 1 ? "jest" : "są") za głęboki/-e na profil Typ 2. Skróć głębokość lub zwiększ rezerwę montażową.",
                "Zmniejsz głębokość modułu albo popraw profil skosu w głąb.",
                to: &issues
            )
        }

        // Sprawdź ściany z modułami bez profilu Typ 2, jeśli pokój ma przynajmniej
        // jeden profil głębokościowy — wtedy brak profilu na innej ścianie jest podejrzany.
        let typ2ProfileWallIDs = Set(
            room.wallProfiles
                .filter { $0.name.hasPrefix(SilnikSkosuPomieszczeniaV069.profileBackCutNamePrefix) }
                .map(\.wallID)
        )

        if !typ2ProfileWallIDs.isEmpty {
            let wallsWithModules = assemblies.compactMap { stored -> WallID? in
                guard let wallID = stored.assembly.placement?.wallID else { return nil }
                return wallID
            }
            let uniqueWallsWithModules = Set(wallsWithModules)
            let missingProfile = uniqueWallsWithModules.subtracting(typ2ProfileWallIDs)

            if !missingProfile.isEmpty {
                let wallNames = missingProfile.compactMap { wid in
                    room.geometry.walls.first { $0.id == wid }?.name
                }
                let label = wallNames.prefix(3).joined(separator: ", ")
                append(
                    "project-slope-depth-missing-profile",
                    .info,
                    .project,
                    "Brak profilu skosu Typ 2 na \(missingProfile.count == 1 ? "jednej ścianie" : "\(missingProfile.count) ścianach")",
                    "Ściany \(label) mają moduły, ale nie przypisano im profilu skosu w głąb — głębokość mebli nie jest automatycznie sprawdzana.",
                    "Otwórz inspektor ściany → Przypisz skos → wybierz Typ 2 i zapisz profil.",
                    to: &issues
                )
            }
        }
    }

    private static func appendPricingIssues(
        materialy:
            GlobalneMaterialyPomieszczenia,
        lista:
            ListaFormatekProjektuV070,
        to issues:
            inout [ProjectReadinessIssueV078]
    ) {
        appendMaterialIssueIfNeeded(
            materialy.korpus,
            role: "korpusu",
            idPrefix: "pricing-carcass",
            to: &issues
        )
        appendMaterialIssueIfNeeded(
            materialy.front,
            role: "frontu",
            idPrefix: "pricing-front",
            to: &issues
        )

        let frontPieces =
            lista
            .formatki
            .filter {
                $0.kategoria == .front
                    || $0.kategoria == .maskownice
            }

        if !frontPieces.isEmpty,
           materialy.front.id == nil {
            append(
                "pricing-front-price-missing",
                .blocking,
                .pricing,
                "Brak ceny frontów",
                "W projekcie jest \(frontPieces.count) formatek frontowych lub maskujących bez powiązania z pozycją cennika.",
                "Wybierz front z bazy materiałów w ustawieniach wyglądu pomieszczenia.",
                to: &issues
            )
        }

        let boardPieces =
            lista
            .formatki
            .filter {
                $0.kategoria == .korpus
                    || $0.kategoria == .plecy
                    || $0.kategoria == .cokół
            }

        if !boardPieces.isEmpty,
           materialy.korpus.id == nil {
            append(
                "pricing-board-price-missing",
                .blocking,
                .pricing,
                "Brak ceny płyty korpusowej",
                "W projekcie jest \(boardPieces.count) formatek korpusowych bez powiązania z pozycją cennika.",
                "Wybierz płytę korpusową z bazy materiałów.",
                to: &issues
            )
        }
    }

    private static func appendProductionIssues(
        lista:
            ListaFormatekProjektuV070,
        raport:
            RaportRozkrojuPlytV071,
        to issues:
            inout [ProjectReadinessIssueV078]
    ) {
        if !raport.nierozmieszczone.isEmpty {
            append(
                "production-oversized-pieces",
                .blocking,
                .production,
                "Formatki poza arkuszem",
                "\(raport.nierozmieszczone.count) formatek nie mieści się na aktualnym formacie płyty.",
                "Zmień format arkusza, podziel element albo skoryguj konstrukcję modułu.",
                to: &issues
            )
        }

        let visibleEdges =
            lista
            .formatki
            .filter {
                $0.kategoria == .front
                    || $0.kategoria == .maskownice
                    || $0.kategoria == .blat
            }

        if !visibleEdges.isEmpty {
            append(
                "production-edge-banding-review",
                .warning,
                .production,
                "Obrzeża wymagają przeglądu",
                "\(visibleEdges.count) widocznych formatek powinno mieć potwierdzone reguły okleinowania.",
                "Przejdź do modułu Obrzeża i zatwierdź krawędzie widoczne.",
                to: &issues
            )
        }

        let generatedDrawers =
            lista
            .formatki
            .filter {
                $0.kodKomponentu
                    .hasPrefix(
                        "V068-DRAWER-"
                    )
                    || $0.kodKomponentu
                    .hasPrefix(
                        "SZ-"
                    )
                    || $0.kodKomponentu
                    .hasPrefix(
                        "FRONT-SZ-"
                    )
            }

        if !generatedDrawers.isEmpty {
            append(
                "production-drawer-pieces",
                .info,
                .production,
                "Szuflady w BOM",
                "Generator uwzględnia \(generatedDrawers.count) formatek szuflad i frontów szufladowych w produkcji.",
                "Zweryfikuj prowadnice, cofnięcie i fronty w karcie technicznej modułu.",
                to: &issues
            )
        }
    }

    private static func appendMaterialIssueIfNeeded(
        _ material:
            MigawkaMaterialuGlobalnego,
        role: String,
        idPrefix: String,
        to issues:
            inout [ProjectReadinessIssueV078]
    ) {
        let code =
            material
            .kod
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        if code.isEmpty {
            append(
                "\(idPrefix)-missing",
                .blocking,
                .pricing,
                "Brak materiału \(role)",
                "Materiał \(role) nie ma kodu, więc nie da się przygotować wiarygodnej wyceny.",
                "Wybierz materiał z bazy materiałów.",
                to: &issues
            )
            return
        }

        if material.id == nil {
            append(
                "\(idPrefix)-catalog-id",
                .warning,
                .pricing,
                "Materiał \(role) bez ID cennika",
                "\(material.nazwa) nie jest powiązany z rekordem bazy materiałów.",
                "Wybierz materiał z bazy, żeby wycena i lista zakupowa miały źródło ceny.",
                to: &issues
            )
        }
    }

    private static func append(
        _ id: String,
        _ status:
            ProjectReadinessIssueStatusV078,
        _ area:
            ProjectReadinessAreaV078,
        _ title: String,
        _ message: String,
        _ action: String,
        to issues:
            inout [ProjectReadinessIssueV078]
    ) {
        issues.append(
            ProjectReadinessIssueV078(
                id: id,
                status: status,
                area: area,
                title: title,
                message: message,
                action: action
            )
        )
    }

    private static func issueOrder(
        _ lhs:
            ProjectReadinessIssueV078,
        _ rhs:
            ProjectReadinessIssueV078
    ) -> Bool {
        let leftRank =
            rank(lhs.status)
        let rightRank =
            rank(rhs.status)

        if leftRank != rightRank {
            return leftRank > rightRank
        }

        if lhs.area.rawValue != rhs.area.rawValue {
            return lhs.area.rawValue < rhs.area.rawValue
        }

        return lhs.title
            .localizedStandardCompare(
                rhs.title
            )
            == .orderedAscending
    }

    private static func rank(
        _ status:
            ProjectReadinessIssueStatusV078
    ) -> Int {
        switch status {
        case .blocking:
            return 3
        case .warning:
            return 2
        case .info:
            return 1
        }
    }

    private static func isKitchenLike(
        _ name: String
    ) -> Bool {
        let normalized =
            name.lowercased()

        return normalized.contains(
            "kuch"
        )
    }
}

struct ProdukcjaPulpitV074:
    View
{
    let lista:
        ListaFormatekProjektuV070
    let raport:
        RaportRozkrojuPlytV071
    let liczbaModulow: Int
    let reportGotowosci:
        ProjectReadinessReportV078
    let onOpen:
        (ZakladkaProdukcjiV071) -> Void

    private let columns = [
        GridItem(
            .adaptive(minimum: 170),
            spacing: 12
        )
    ]

    var body: some View {
        ScrollView {
            LazyVStack(
                alignment: .leading,
                spacing: 20
            ) {
                naglowek

                LazyVGrid(
                    columns: columns,
                    alignment: .leading,
                    spacing: 12
                ) {
                    metricCard(
                        title: "Moduły",
                        value:
                            String(liczbaModulow),
                        symbol:
                            "square.stack.3d.up",
                        description:
                            "w aktualnym projekcie"
                    )

                    metricCard(
                        title: "Formatki",
                        value:
                            String(
                                lista.liczbaFormatek
                            ),
                        symbol:
                            "rectangle.split.3x1",
                        description:
                            area(
                                lista.powierzchniaM2
                            )
                            + " m²"
                    )

                    metricCard(
                        title: "Arkusze",
                        value:
                            String(
                                raport.liczbaArkuszy
                            ),
                        symbol:
                            "square.stack.3d.up.fill",
                        description:
                            raport.arkusze.isEmpty
                                ? "rozkrój nieprzeliczony"
                                : "po przeliczeniu"
                    )

                    metricCard(
                        title: "Wykorzystanie",
                        value:
                            percent(
                                raport
                                    .wykorzystanieProcent
                            ),
                        symbol:
                            "chart.pie",
                        description:
                            "odpad "
                            + area(
                                raport.odpadM2
                            )
                            + " m²"
                    )
                }

                gotowoscCard
                readinessIssuesCard
                workflowCard
            }
            .padding(20)
            .frame(
                maxWidth: 1100,
                alignment: .leading
            )
            .frame(
                maxWidth: .infinity,
                alignment: .topLeading
            )
        }
        .background(
            Color(
                uiColor:
                    .systemGroupedBackground
            )
        )
    }

    private var naglowek:
        some View
    {
        HStack(
            alignment: .top,
            spacing: 16
        ) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(
                    Color.accentColor
                        .opacity(0.14)
                )

                Image(
                    systemName:
                        "shippingbox.fill"
                )
                .font(.title.bold())
                .foregroundStyle(
                    Color.accentColor
                )
            }
            .frame(
                width: 58,
                height: 58
            )

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(
                    "Centrum produkcji"
                )
                .font(.largeTitle.bold())

                Text(
                    "Kolejne etapy korzystają z jednego źródła danych projektu. Zacznij od kontroli formatek, następnie przejdź przez rozkrój, obrzeża, CNC oraz montaż i pakowanie."
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
            }

            Spacer()
        }
    }

    private var gotowoscCard:
        some View
    {
        GroupBox {
            HStack(
                alignment: .center,
                spacing: 14
            ) {
                Image(
                    systemName:
                        statusGotowosci.symbol
                )
                .font(.title2)
                .foregroundStyle(
                    statusGotowosci.kolor
                )

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    Text(
                        statusGotowosci.tytul
                    )
                    .font(.headline)

                    Text(
                        statusGotowosci.opis
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        } label: {
            Label(
                "Gotowość projektu",
                systemImage:
                    "checklist"
            )
        }
    }

    @ViewBuilder
    private var readinessIssuesCard:
        some View
    {
        if !reportGotowosci
            .issues
            .isEmpty {
            GroupBox {
                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(
                        widoczneProblemyGotowosci
                    ) {
                        issue in

                        readinessIssueRow(
                            issue
                        )

                        if issue.id
                            != widoczneProblemyGotowosci
                            .last?
                            .id {
                            Divider()
                        }
                    }

                    if reportGotowosci
                        .issues
                        .count > 6 {
                        Text(
                            "+ \(reportGotowosci.issues.count - 6) kolejnych pozycji do sprawdzenia"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            } label: {
                Label(
                    "Bramka gotowości",
                    systemImage:
                        "checklist.checked"
                )
            }
        }
    }

    private var widoczneProblemyGotowosci:
        [ProjectReadinessIssueV078]
    {
        Array(
            reportGotowosci
                .issues
                .prefix(6)
        )
    }

    private func readinessIssueRow(
        _ issue:
            ProjectReadinessIssueV078
    ) -> some View {
        HStack(
            alignment: .top,
            spacing: 12
        ) {
            Image(
                systemName:
                    issue.status.symbol
            )
            .font(.title3)
            .foregroundStyle(
                issue.status.color
            )
            .frame(
                width: 28,
                alignment: .center
            )

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                HStack(
                    spacing: 8
                ) {
                    Text(issue.title)
                        .font(.subheadline.weight(.semibold))

                    Text(issue.area.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            issue.status.color
                        )
                        .padding(
                            .horizontal,
                            7
                        )
                        .padding(
                            .vertical,
                            3
                        )
                        .background(
                            issue.status.color
                                .opacity(0.12),
                            in:
                                Capsule()
                        )
                }

                Text(issue.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(issue.action)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 8)
        }
        .padding(.vertical, 4)
    }

    private var workflowCard:
        some View
    {
        GroupBox {
            VStack(spacing: 0) {
                workflowRow(
                    number: 1,
                    title: "Formatki",
                    subtitle:
                        lista.formatki.isEmpty
                        ? "Brak elementów do produkcji"
                        : "\(lista.liczbaFormatek) elementów do sprawdzenia",
                    symbol:
                        "list.number",
                    status:
                        lista.formatki.isEmpty
                        ? .warning
                        : .ready,
                    destination:
                        .formatki
                )

                Divider()
                    .padding(.leading, 52)

                workflowRow(
                    number: 2,
                    title: "Rozkrój płyt",
                    subtitle:
                        raport.arkusze.isEmpty
                        ? "Przelicz rozmieszczenie na arkuszach"
                        : "\(raport.liczbaArkuszy) arkuszy • \(percent(raport.wykorzystanieProcent)) wykorzystania",
                    symbol:
                        "square.grid.3x3.square",
                    status:
                        raport.arkusze.isEmpty
                        ? .attention
                        : (
                            raport.nierozmieszczone.isEmpty
                            ? .ready
                            : .warning
                        ),
                    destination:
                        .rozkroj
                )

                Divider()
                    .padding(.leading, 52)

                workflowRow(
                    number: 3,
                    title: "Obrzeża",
                    subtitle:
                        "Sprawdź automatyczne reguły i ręczne korekty",
                    symbol:
                        "rectangle.and.hand.point.up.left",
                    status:
                        lista.formatki.isEmpty
                        ? .warning
                        : .attention,
                    destination:
                        .obrzeza
                )

                Divider()
                    .padding(.leading, 52)

                workflowRow(
                    number: 4,
                    title: "CNC i wiercenia",
                    subtitle:
                        "Zweryfikuj operacje oraz położenia otworów",
                    symbol:
                        "gearshape.2",
                    status:
                        lista.formatki.isEmpty
                        ? .warning
                        : .attention,
                    destination:
                        .obrobki
                )

                Divider()
                    .padding(.leading, 52)

                workflowRow(
                    number: 5,
                    title: "Zakup płyt",
                    subtitle:
                        raport.zapotrzebowanie.isEmpty
                        ? "Dane pojawią się po przeliczeniu rozkroju"
                        : "\(raport.zapotrzebowanie.count) pozycji materiałowych",
                    symbol:
                        "cart",
                    status:
                        raport.zapotrzebowanie.isEmpty
                        ? .attention
                        : .ready,
                    destination:
                        .zakup
                )
                
                Divider()
                    .padding(.leading, 52)

                workflowRow(
                    number: 6,
                    title: "Montaż i pakowanie",
                    subtitle:
                        lista.formatki.isEmpty
                        ? "Brak elementów do montażu"
                        : "Kolejność operacji, paczki i kontrola transportu",
                    symbol:
                        "shippingbox",
                    status:
                        lista.formatki.isEmpty
                        ? .warning
                        : .attention,
                    destination:
                        .montaz
                )
            }
        } label: {
            Label(
                "Przebieg produkcji",
                systemImage:
                    "arrow.triangle.branch"
            )
        }
    }

    private func metricCard(
        title: String,
        value: String,
        symbol: String,
        description: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            HStack {
                Image(
                    systemName: symbol
                )
                .font(.title3)
                .foregroundStyle(
                    Color.accentColor
                )

                Spacer()

                Text(value)
                    .font(
                        .title2
                            .bold()
                            .monospacedDigit()
                    )
            }

            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(
            maxWidth: .infinity,
            minHeight: 112,
            alignment: .leading
        )
        .background(
            Color(
                uiColor:
                    .secondarySystemGroupedBackground
            ),
            in:
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(
                Color.secondary
                    .opacity(0.12),
                lineWidth: 1
            )
        }
    }

    private func workflowRow(
        number: Int,
        title: String,
        subtitle: String,
        symbol: String,
        status: WorkflowStatusV074,
        destination:
            ZakladkaProdukcjiV071
    ) -> some View {
        Button {
            onOpen(destination)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            status.kolor
                                .opacity(0.14)
                        )

                    Text(String(number))
                        .font(
                            .subheadline
                                .bold()
                                .monospacedDigit()
                        )
                        .foregroundStyle(
                            status.kolor
                        )
                }
                .frame(
                    width: 36,
                    height: 36
                )

                Image(
                    systemName: symbol
                )
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22)

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                Label(
                    status.tytul,
                    systemImage:
                        status.symbol
                )
                .font(
                    .caption
                        .weight(.semibold)
                )
                .foregroundStyle(
                    status.kolor
                )

                Image(
                    systemName:
                        "chevron.right"
                )
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var statusGotowosci:
        (
            tytul: String,
            opis: String,
            symbol: String,
            kolor: Color
        )
    {
        if reportGotowosci
            .blockingCount > 0
            || reportGotowosci
            .warningCount > 0 {
            return (
                reportGotowosci.title,
                reportGotowosci.message,
                reportGotowosci.status.symbol,
                reportGotowosci.status.color
            )
        }

        if lista.formatki.isEmpty {
            return (
                "Brak danych produkcyjnych",
                "Dodaj moduły zawierające komponenty płytowe, aby uruchomić produkcję.",
                "exclamationmark.triangle.fill",
                .orange
            )
        }

        if !raport.nierozmieszczone.isEmpty {
            return (
                "Wymagana korekta rozkroju",
                "\(raport.nierozmieszczone.count) formatek nie mieści się na aktualnym formacie arkusza.",
                "exclamationmark.triangle.fill",
                .orange
            )
        }

        if raport.arkusze.isEmpty {
            return (
                "Dane gotowe do przeliczenia",
                "Formatki są dostępne. Przejdź do rozkroju i sprawdź parametry arkusza.",
                "arrow.clockwise.circle",
                .blue
            )
        }

        return (
            "Rozkrój gotowy",
            "Możesz kontynuować kontrolę obrzeży, operacji CNC i listy zakupowej.",
            "checkmark.circle.fill",
            .green
        )
    }

    private func area(
        _ value: Double
    ) -> String {
        value.formatted(
            .number
                .locale(
                    Locale(
                        identifier:
                            "pl_PL"
                    )
                )
                .precision(
                    .fractionLength(0...2)
                )
        )
    }

    private func percent(
        _ value: Double
    ) -> String {
        value.formatted(
            .number
                .locale(
                    Locale(
                        identifier:
                            "pl_PL"
                    )
                )
                .precision(
                    .fractionLength(0...1)
                )
        )
        + "%"
    }
}

private enum WorkflowStatusV074 {
    case ready
    case attention
    case warning

    var tytul: String {
        switch self {
        case .ready:
            return "Gotowe"
        case .attention:
            return "Sprawdź"
        case .warning:
            return "Uwaga"
        }
    }

    var symbol: String {
        switch self {
        case .ready:
            return "checkmark.circle.fill"
        case .attention:
            return "circle.dashed"
        case .warning:
            return "exclamationmark.triangle.fill"
        }
    }

    var kolor: Color {
        switch self {
        case .ready:
            return .green
        case .attention:
            return .blue
        case .warning:
            return .orange
        }
    }
}
