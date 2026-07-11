import DomainCore
import Foundation

enum ZrodloPomiaruSkosuV069:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case reczny
    case bluetooth
    case lidar
    case importowany
    case wyliczony

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .reczny:
            return "Wpis ręczny"
        case .bluetooth:
            return "Dalmierz Bluetooth"
        case .lidar:
            return "LiDAR / RoomPlan"
        case .importowany:
            return "Import"
        case .wyliczony:
            return "Wartość wyliczona"
        }
    }

    var systemImage: String {
        switch self {
        case .reczny:
            return "keyboard"
        case .bluetooth:
            return "dot.radiowaves.left.and.right"
        case .lidar:
            return "viewfinder"
        case .importowany:
            return "square.and.arrow.down"
        case .wyliczony:
            return "function"
        }
    }
}

enum KierunekProfiluSkosuV069:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case wzdluzSciany
    case wGlabPomieszczenia

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .wzdluzSciany:
            return "Wzdłuż ściany"
        case .wGlabPomieszczenia:
            return "W głąb pomieszczenia"
        }
    }
}

struct PunktProfiluSkosuV069:
    Identifiable,
    Hashable,
    Sendable
{
    let id: UUID
    var xMM: Double
    var wysokoscMM: Double
}

struct KonturMeblaPodSkosemV069:
    Hashable,
    Sendable
{
    var punkty: [PunktProfiluSkosuV069]
    var gornaKrawedz: [PunktProfiluSkosuV069]
    var jestSciety: Bool
    var minimalnyPrzeswitMM: Double
    var maksymalnaWysokoscMeblaMM: Double
}

enum BladSkosuPomieszczeniaV069:
    LocalizedError,
    Equatable
{
    case brakSciany
    case scianaNieIstnieje
    case zaMaloPunktow
    case powtorzonaPozycja
    case punktPozaSciana
    case nieprawidlowaWysokosc
    case profilNieObejmujeSciany
    case mebelNieMiesciSiePodSkosem

    var errorDescription: String? {
        switch self {
        case .brakSciany:
            return "Wybierz ścianę, której dotyczy skos."
        case .scianaNieIstnieje:
            return "Wybrana ściana nie istnieje w pomieszczeniu."
        case .zaMaloPunktow:
            return "Profil skosu musi zawierać co najmniej dwa punkty."
        case .powtorzonaPozycja:
            return "Dwa punkty profilu nie mogą mieć tej samej odległości."
        case .punktPozaSciana:
            return "Punkt profilu znajduje się poza zakresem ściany."
        case .nieprawidlowaWysokosc:
            return "Wysokość punktu profilu musi być dodatnia."
        case .profilNieObejmujeSciany:
            return "Profil musi zaczynać się przy początku i kończyć przy końcu ściany."
        case .mebelNieMiesciSiePodSkosem:
            return "Mebel nie mieści się pod profilem skosu z zachowaniem rezerwy montażowej."
        }
    }
}

// MARK: - Kontury dla skosu Typ 2 (ucięty tył)

/// Wynik obliczeń dla szafy stojącej prosto z uciętym tyłem.
/// Profil biegnie w głąb pomieszczenia (0 = przy ścianie, D = front szafy).
struct KonturMeblaUcietyTylV069: Hashable, Sendable {
    /// Wysokość frontu szafy (przy przedniej krawędzi).
    var frontalnaWysokoscMM: Double
    /// Wysokość tyłu szafy (przy ścianie) — tu pasuje panel tylny.
    var tylnaWysokoscMM: Double
    /// Profil boczny: punkty (xMM = głębokość od ściany 0..D, wysokoscMM = efektywna wysokość).
    var profilBoku: [PunktProfiluSkosuV069]
    /// Wymagana rezerwa montażowa [mm].
    var clearanceMM: Double
    /// True jeśli tył jest faktycznie ucięty (tylnaWysokoscMM < oczekiwana wysokość − 0.5).
    var jestSciety: Bool
    /// Przybliżony kąt skosu w stopniach (arctan(deltaH / glebokoscMM)).
    var katSkosuStopnie: Double
}

enum SilnikSkosuPomieszczeniaV069 {
    // MARK: - Prefiksy profili

    /// Profil Typ 1: wzdłuż ściany (top szafy ścięty).
    static let profileNamePrefix =
        "SKOS_V069:"

    /// Profil Typ 2: w głąb pomieszczenia (tył szafy ucięty).
    static let profileBackCutNamePrefix =
        "SKOS_TYL_V069:"

    static let endpointToleranceMM =
        5.0

    static func uporzadkowanePunkty(
        pomiar: PomiarGarderobySkosy
    ) throws -> [PunktProfiluSkosuV069] {
        let points =
            pomiar.punktySkosu
                .map {
                    PunktProfiluSkosuV069(
                        id: $0.id,
                        xMM:
                            $0.odlegloscOdLewejMM,
                        wysokoscMM:
                            $0.wysokoscMM
                    )
                }
                .sorted {
                    $0.xMM < $1.xMM
                }

        guard points.count >= 2 else {
            throw BladSkosuPomieszczeniaV069
                .zaMaloPunktow
        }

        guard points.allSatisfy({
            $0.wysokoscMM > 0
                && $0.xMM >= 0
        }) else {
            throw BladSkosuPomieszczeniaV069
                .nieprawidlowaWysokosc
        }

        for pair in zip(
            points,
            points.dropFirst()
        ) {
            guard abs(
                pair.0.xMM
                    - pair.1.xMM
            ) > 0.001 else {
                throw BladSkosuPomieszczeniaV069
                    .powtorzonaPozycja
            }
        }

        return points
    }

    static func waliduj(
        pomiar: PomiarGarderobySkosy,
        dlugoscScianyMM: Double
    ) throws {
        let points =
            try uporzadkowanePunkty(
                pomiar: pomiar
            )

        guard dlugoscScianyMM > 0 else {
            throw BladSkosuPomieszczeniaV069
                .scianaNieIstnieje
        }

        guard points.allSatisfy({
            $0.xMM <= dlugoscScianyMM
                + endpointToleranceMM
        }) else {
            throw BladSkosuPomieszczeniaV069
                .punktPozaSciana
        }

        guard
            let first = points.first,
            let last = points.last,
            abs(first.xMM)
                <= endpointToleranceMM,
            abs(
                last.xMM
                    - dlugoscScianyMM
            ) <= endpointToleranceMM
        else {
            throw BladSkosuPomieszczeniaV069
                .profilNieObejmujeSciany
        }
    }

    static func wysokosc(
        w pozycjiXMM: Double,
        punkty:
            [PunktProfiluSkosuV069]
    ) -> Double? {
        let points =
            punkty.sorted {
                $0.xMM < $1.xMM
            }

        guard let first = points.first,
              let last = points.last
        else {
            return nil
        }

        if pozycjiXMM <= first.xMM {
            return first.wysokoscMM
        }

        if pozycjiXMM >= last.xMM {
            return last.wysokoscMM
        }

        for pair in zip(
            points,
            points.dropFirst()
        ) {
            let left = pair.0
            let right = pair.1

            guard pozycjiXMM >= left.xMM,
                  pozycjiXMM <= right.xMM
            else {
                continue
            }

            let run =
                right.xMM - left.xMM

            guard run > 0 else {
                return left.wysokoscMM
            }

            let progress =
                (pozycjiXMM - left.xMM)
                / run

            return left.wysokoscMM
                + (
                    right.wysokoscMM
                    - left.wysokoscMM
                )
                * progress
        }

        return nil
    }

    static func wysokosc(
        w pozycjiX:
            Millimeters,
        profil:
            WallProfileDefinition
    ) -> Millimeters? {
        let points =
            profil.points.map {
                PunktProfiluSkosuV069(
                    id:
                        $0.id.rawValue,
                    xMM:
                        $0.distanceAlongProfile
                            .rawValue,
                    wysokoscMM:
                        $0.offsetFromReference
                            .rawValue
                )
            }

        guard let value =
                wysokosc(
                    w:
                        pozycjiX.rawValue,
                    punkty:
                        points
                )
        else {
            return nil
        }

        return Millimeters(value)
    }

    static func profilDomenowy(
        z pomiar:
            PomiarGarderobySkosy,
        wallID: WallID,
        dlugoscSciany:
            Millimeters
    ) throws -> WallProfileDefinition {
        try waliduj(
            pomiar: pomiar,
            dlugoscScianyMM:
                dlugoscSciany.rawValue
        )

        let sortedOriginal =
            pomiar.punktySkosu
                .sorted {
                    $0.odlegloscOdLewejMM
                    < $1.odlegloscOdLewejMM
                }

        let points =
            try sortedOriginal
                .enumerated()
                .map {
                    index,
                    point in

                    let normalizedDistance:
                        Double

                    if index == 0,
                       abs(
                            point
                                .odlegloscOdLewejMM
                       ) <= endpointToleranceMM {
                        normalizedDistance = 0
                    } else if index
                                == sortedOriginal.count - 1,
                              abs(
                                point
                                    .odlegloscOdLewejMM
                                - dlugoscSciany
                                    .rawValue
                              ) <= endpointToleranceMM {
                        normalizedDistance =
                            dlugoscSciany
                                .rawValue
                    } else {
                        normalizedDistance =
                            min(
                                max(
                                    point
                                        .odlegloscOdLewejMM,
                                    0
                                ),
                                dlugoscSciany
                                    .rawValue
                            )
                    }

                    return try WallProfilePoint(
                    id:
                        WallProfilePointID(
                            rawValue:
                                point.id
                        ),
                    distanceAlongProfile:
                        Millimeters(
                            normalizedDistance
                        ),
                    offsetFromReference:
                        Millimeters(
                            point
                                .wysokoscMM
                        ),
                    isConfirmed:
                        point
                            .potwierdzonyV069
                )
            }

        return try WallProfileDefinition(
            id:
                WallProfileID(
                    rawValue:
                        pomiar.id
                ),
            wallID:
                wallID,
            name:
                profileNamePrefix
                + pomiar
                    .nazwaPomieszczenia,
            direction:
                .horizontal,
            referenceEdge:
                .floor,
            points:
                points,
            productionAllowance:
                .zero,
            installationAllowance:
                Millimeters(
                    pomiar
                        .wymaganaRezerwaMontazowaMM
                ),
            targetGap:
                .zero
        )
    }

    static func zastosuj(
        pomiar:
            PomiarGarderobySkosy,
        do room:
            RoomDefinition,
        at date: Date = Date()
    ) throws -> RoomDefinition {
        switch pomiar.kierunekProfiluV069 {
        case .wzdluzSciany:
            return try zastosujWzdluz(
                pomiar: pomiar,
                do: room,
                at: date
            )
        case .wGlabPomieszczenia:
            return try zastosujGlebokosciowy(
                pomiar: pomiar,
                do: room,
                at: date
            )
        }
    }

    // MARK: Typ 1 — wzdłuż ściany (oryginalna logika)

    private static func zastosujWzdluz(
        pomiar:
            PomiarGarderobySkosy,
        do room:
            RoomDefinition,
        at date: Date = Date()
    ) throws -> RoomDefinition {
        guard let rawWallID =
                pomiar.wallIDRawValueV069,
              let wallID =
                WallID(rawWallID)
        else {
            throw BladSkosuPomieszczeniaV069
                .brakSciany
        }

        guard
            let wall =
                room.geometry.wall(
                    id: wallID
                ),
            let wallGeometry =
                room.geometry.geometry(
                    of: wall.id
                )
        else {
            throw BladSkosuPomieszczeniaV069
                .scianaNieIstnieje
        }

        let profile =
            try profilDomenowy(
                z: pomiar,
                wallID: wallID,
                dlugoscSciany:
                    wallGeometry.length
            )

        let profiles =
            room.wallProfiles
                .filter {
                    $0.id != profile.id
                }
                + [profile]

        var updated =
            try RoomDefinition(
                id: room.id,
                projectID:
                    room.projectID,
                name:
                    room.name,
                geometry:
                    room.geometry,
                windows:
                    room.windows,
                doors:
                    room.doors,
                recesses:
                    room.recesses,
                obstacles:
                    room.obstacles,
                wallProfiles:
                    profiles,
                bayProjections:
                    room.bayProjections,
                createdAt:
                    room.createdAt
            )

        try updated.replaceGeometry(
            updated.geometry,
            at: date
        )

        return updated
    }

    // MARK: Typ 2 — w głąb pomieszczenia (ucięty tył)

    private static func zastosujGlebokosciowy(
        pomiar:
            PomiarGarderobySkosy,
        do room:
            RoomDefinition,
        at date: Date = Date()
    ) throws -> RoomDefinition {
        guard let rawWallID =
                pomiar.wallIDRawValueV069,
              let wallID =
                WallID(rawWallID)
        else {
            throw BladSkosuPomieszczeniaV069
                .brakSciany
        }

        guard room.geometry.wall(id: wallID) != nil else {
            throw BladSkosuPomieszczeniaV069
                .scianaNieIstnieje
        }

        let profile =
            try profilDomenowyGlebokosci(
                z: pomiar,
                wallID: wallID
            )

        let profiles =
            room.wallProfiles
                .filter { $0.id != profile.id }
                + [profile]

        var updated =
            try RoomDefinition(
                id: room.id,
                projectID: room.projectID,
                name: room.name,
                geometry: room.geometry,
                windows: room.windows,
                doors: room.doors,
                recesses: room.recesses,
                obstacles: room.obstacles,
                wallProfiles: profiles,
                bayProjections: room.bayProjections,
                createdAt: room.createdAt
            )

        try updated.replaceGeometry(updated.geometry, at: date)
        return updated
    }

    /// Tworzy `WallProfileDefinition` dla profilu głębokościowego (Typ 2).
    /// Oś X profilu = głębokość od ściany (0 = przy ścianie, D = front szafy).
    /// Waliduje że profil obejmuje 0..glebokoscDocelowaMM.
    static func profilDomenowyGlebokosci(
        z pomiar: PomiarGarderobySkosy,
        wallID: WallID
    ) throws -> WallProfileDefinition {
        let spanMM = pomiar.glebokoscDocelowaMM

        // Walidacja reużywa istniejącej logiki z głębokością jako "długością"
        try waliduj(
            pomiar: pomiar,
            dlugoscScianyMM: spanMM
        )

        let sortedOriginal =
            pomiar.punktySkosu
                .sorted {
                    $0.odlegloscOdLewejMM
                    < $1.odlegloscOdLewejMM
                }

        let points =
            try sortedOriginal
                .enumerated()
                .map { index, point in
                    let normalizedDistance: Double
                    if index == 0,
                       abs(point.odlegloscOdLewejMM) <= endpointToleranceMM {
                        normalizedDistance = 0
                    } else if index == sortedOriginal.count - 1,
                              abs(point.odlegloscOdLewejMM - spanMM) <= endpointToleranceMM {
                        normalizedDistance = spanMM
                    } else {
                        normalizedDistance = min(
                            max(point.odlegloscOdLewejMM, 0),
                            spanMM
                        )
                    }

                    return try WallProfilePoint(
                        id: WallProfilePointID(rawValue: point.id),
                        distanceAlongProfile: Millimeters(normalizedDistance),
                        offsetFromReference: Millimeters(point.wysokoscMM),
                        isConfirmed: point.potwierdzonyV069
                    )
                }

        return try WallProfileDefinition(
            id: WallProfileID(rawValue: pomiar.id),
            wallID: wallID,
            name: profileBackCutNamePrefix + pomiar.nazwaPomieszczenia,
            direction: .horizontal,
            referenceEdge: .floor,
            points: points,
            productionAllowance: .zero,
            installationAllowance: Millimeters(pomiar.wymaganaRezerwaMontazowaMM),
            targetGap: .zero
        )
    }

    static func usunProfil(
        measurementID: UUID,
        z room:
            RoomDefinition,
        at date: Date = Date()
    ) throws -> RoomDefinition {
        let profileID =
            WallProfileID(
                rawValue:
                    measurementID
            )

        let profiles =
            room.wallProfiles
                .filter {
                    $0.id != profileID
                }

        guard profiles.count
                != room.wallProfiles.count
        else {
            return room
        }

        var updated =
            try RoomDefinition(
                id: room.id,
                projectID:
                    room.projectID,
                name:
                    room.name,
                geometry:
                    room.geometry,
                windows:
                    room.windows,
                doors:
                    room.doors,
                recesses:
                    room.recesses,
                obstacles:
                    room.obstacles,
                wallProfiles:
                    profiles,
                bayProjections:
                    room.bayProjections,
                createdAt:
                    room.createdAt
            )

        try updated.replaceGeometry(
            updated.geometry,
            at: date
        )

        return updated
    }

    static func profilSkosu(
        dla wallID:
            WallID,
        w room:
            RoomDefinition
    ) -> WallProfileDefinition? {
        room.wallProfiles
            .last {
                $0.wallID == wallID
                && $0.direction
                    == .horizontal
                && $0.referenceEdge
                    == .floor
                && $0.name
                    .hasPrefix(
                        profileNamePrefix
                    )
            }
    }

    /// Zwraca profil głębokościowy (Typ 2 — ucięty tył) dla danej ściany.
    static func profilSkosuGlebokosci(
        dla wallID: WallID,
        w room: RoomDefinition
    ) -> WallProfileDefinition? {
        room.wallProfiles.last {
            $0.wallID == wallID
            && $0.direction == .horizontal
            && $0.referenceEdge == .floor
            && $0.name.hasPrefix(profileBackCutNamePrefix)
        }
    }

    // MARK: - Kontur Typ 2 (ucięty tył)

    /// Oblicza dane potrzebne do produkcji szafy z uciętym tyłem.
    ///
    /// - Parameters:
    ///   - glebokoscMM: głębokość szafy (D). Oś X profilu: 0 = przy ścianie, D = front.
    ///   - wysokoscMM:  docelowa nominalna wysokość szafy (H).
    ///   - profil:      profil głębokościowy (distanceAlongProfile = 0..D).
    static func konturMeblaUcietyTyl(
        glebokoscMM: Double,
        wysokoscMM: Double,
        profil: WallProfileDefinition
    ) throws -> KonturMeblaUcietyTylV069 {
        let profilePoints = punktyProfilu(profil)
        guard profilePoints.count >= 2 else {
            throw BladSkosuPomieszczeniaV069.zaMaloPunktow
        }

        let clearance = max(
            profil.installationAllowance.rawValue
            + profil.targetGap.rawValue,
            0
        )

        // Próbkowanie na wszystkich charakterystycznych głębokościach
        var sampleX = [0.0, glebokoscMM]
        sampleX.append(contentsOf:
            profilePoints.map(\.xMM).filter { $0 > 0 && $0 < glebokoscMM }
        )
        sampleX = Array(Set(sampleX)).sorted()

        // Dla każdej głębokości: efektywna wysokość = min(H, sufit - rezerwa)
        let profilBoku: [PunktProfiluSkosuV069] = sampleX.compactMap { x in
            guard let ceilingH = wysokosc(w: x, punkty: profilePoints) else {
                return nil
            }
            let effectiveH = min(wysokoscMM, ceilingH - clearance)
            guard effectiveH > 0 else { return nil }
            return PunktProfiluSkosuV069(
                id: UUID(),
                xMM: x,
                wysokoscMM: effectiveH
            )
        }

        // Jeśli nie udało się obliczyć wszystkich punktów — szafa nie mieści się
        guard profilBoku.count == sampleX.count,
              let minH = profilBoku.map(\.wysokoscMM).min(),
              minH > 0 else {
            throw BladSkosuPomieszczeniaV069.mebelNieMiesciSiePodSkosem
        }

        let tylnaH   = profilBoku.first?.wysokoscMM ?? wysokoscMM  // x=0, przy ścianie
        let frontH   = profilBoku.last?.wysokoscMM  ?? wysokoscMM  // x=D, front
        let jestSciety = profilBoku.contains { $0.wysokoscMM < wysokoscMM - 0.5 }
        let rise     = abs(frontH - tylnaH)
        let katSkosu = glebokoscMM > 0
            ? atan2(rise, glebokoscMM) * 180 / .pi
            : 0

        return KonturMeblaUcietyTylV069(
            frontalnaWysokoscMM: frontH,
            tylnaWysokoscMM: tylnaH,
            profilBoku: profilBoku,
            clearanceMM: clearance,
            jestSciety: jestSciety,
            katSkosuStopnie: katSkosu
        )
    }

    static func punktyProfilu(
        _ profile:
            WallProfileDefinition
    ) -> [PunktProfiluSkosuV069] {
        profile.points
            .map {
                PunktProfiluSkosuV069(
                    id:
                        $0.id.rawValue,
                    xMM:
                        $0.distanceAlongProfile
                            .rawValue,
                    wysokoscMM:
                        $0.offsetFromReference
                            .rawValue
                )
            }
            .sorted {
                $0.xMM < $1.xMM
            }
    }

    static func konturMebla(
        xMM: Double,
        yMM: Double,
        szerokoscMM: Double,
        wysokoscMM: Double,
        profil:
            WallProfileDefinition
    ) throws -> KonturMeblaPodSkosemV069 {
        let profilePoints =
            punktyProfilu(profil)

        guard profilePoints.count >= 2 else {
            throw BladSkosuPomieszczeniaV069
                .zaMaloPunktow
        }

        let xStart = xMM
        let xEnd =
            xMM + szerokoscMM
        let desiredTop =
            yMM + wysokoscMM
        let clearance =
            max(
                profil
                    .installationAllowance
                    .rawValue
                + profil
                    .targetGap
                    .rawValue,
                0
            )

        var sampleX =
            [xStart, xEnd]

        sampleX.append(
            contentsOf:
                profilePoints
                    .map(\.xMM)
                    .filter {
                        $0 > xStart
                        && $0 < xEnd
                    }
        )

        sampleX =
            Array(Set(sampleX))
                .sorted()

        let topPoints =
            sampleX.compactMap {
                x -> PunktProfiluSkosuV069? in

                guard let profileHeight =
                        wysokosc(
                            w: x,
                            punkty:
                                profilePoints
                        )
                else {
                    return nil
                }

                return PunktProfiluSkosuV069(
                    id: UUID(),
                    xMM: x,
                    wysokoscMM:
                        min(
                            desiredTop,
                            profileHeight
                                - clearance
                        )
                )
            }

        guard topPoints.count
                == sampleX.count,
              let minimumTop =
                topPoints
                    .map({
                        $0.wysokoscMM
                    })
                    .min(),
              minimumTop > yMM
        else {
            throw BladSkosuPomieszczeniaV069
                .mebelNieMiesciSiePodSkosem
        }

        let contour =
            [
                PunktProfiluSkosuV069(
                    id: UUID(),
                    xMM: xStart,
                    wysokoscMM: yMM
                ),
                PunktProfiluSkosuV069(
                    id: UUID(),
                    xMM: xEnd,
                    wysokoscMM: yMM
                )
            ]
            + topPoints.reversed()

        let isCut =
            topPoints.contains {
                $0.wysokoscMM
                    < desiredTop
                    - 0.5
            }

        return KonturMeblaPodSkosemV069(
            punkty:
                Array(contour),
            gornaKrawedz:
                topPoints,
            jestSciety:
                isCut,
            minimalnyPrzeswitMM:
                clearance,
            maksymalnaWysokoscMeblaMM:
                minimumTop - yMM
        )
    }

    // Buduje punkty profilu na podstawie kąta skosu podanego w stopniach.
    // Punkt najwyższy = wysokoscMaksymalnaMM; punkt najniższy obliczany
    // z tangensa. Dla układów symetrycznych (obie / sufitDwuspadowy)
    // kąt dotyczy każdego z dwóch połaci.
    // Zwraca nil gdy kąt jest niemożliwy do osiągnięcia przy podanych wymiarach.
    static func maksymalnyKatStopnie(
        szerokoscScianyMM: Double,
        wysokoscMaksymalnaMM: Double
    ) -> Double {
        let width = max(szerokoscScianyMM, 1)
        let high  = max(wysokoscMaksymalnaMM, 1)
        let maxRise = high - 1
        return atan2(maxRise, width) * 180 / .pi
    }

    static func przygotujProfilZKata(
        katStopnie: Double,
        szerokoscScianyMM: Double,
        wysokoscMaksymalnaMM: Double,
        strona: StronaSkosu
    ) -> [PunktPomiarowySkosu] {
        let width = max(szerokoscScianyMM, 1)
        let high  = max(wysokoscMaksymalnaMM, 1)
        let maxKat = maksymalnyKatStopnie(
            szerokoscScianyMM: szerokoscScianyMM,
            wysokoscMaksymalnaMM: wysokoscMaksymalnaMM
        )
        let effectiveKat = min(katStopnie, maxKat)
        let radians = effectiveKat * .pi / 180
        let drop = width * tan(radians)
        let low  = max(high - drop, 1)

        switch strona {
        case .lewa:
            return [
                PunktPomiarowySkosu(
                    odlegloscOdLewejMM: 0,
                    wysokoscMM: low,
                    uwagi: "Niska krawędź"
                ),
                PunktPomiarowySkosu(
                    odlegloscOdLewejMM: width,
                    wysokoscMM: high,
                    uwagi: "Wysoka krawędź"
                )
            ]

        case .prawa:
            return [
                PunktPomiarowySkosu(
                    odlegloscOdLewejMM: 0,
                    wysokoscMM: high,
                    uwagi: "Wysoka krawędź"
                ),
                PunktPomiarowySkosu(
                    odlegloscOdLewejMM: width,
                    wysokoscMM: low,
                    uwagi: "Niska krawędź"
                )
            ]

        case .obie, .sufitDwuspadowy:
            // For symmetric profiles the angle applies to each half-span.
            let halfWidth = width / 2
            let maxKatHalf = atan2(high - 1, halfWidth) * 180 / .pi
            let effectiveKatHalf = min(katStopnie, maxKatHalf)
            let halfDrop = halfWidth * tan(effectiveKatHalf * .pi / 180)
            let edgeLow  = max(high - halfDrop, 1)
            let ridgeLabel =
                strona == .sufitDwuspadowy
                ? "Kalenica"
                : "Najwyższy punkt"
            let edgeLabel =
                strona == .sufitDwuspadowy
                ? "Okapowa"
                : "Niska krawędź"
            return [
                PunktPomiarowySkosu(
                    odlegloscOdLewejMM: 0,
                    wysokoscMM: edgeLow,
                    uwagi: "Lewa \(edgeLabel)"
                ),
                PunktPomiarowySkosu(
                    odlegloscOdLewejMM: width / 2,
                    wysokoscMM: high,
                    uwagi: ridgeLabel
                ),
                PunktPomiarowySkosu(
                    odlegloscOdLewejMM: width,
                    wysokoscMM: edgeLow,
                    uwagi: "Prawa \(edgeLabel)"
                )
            ]
        }
    }

    static func przygotujProfilDwupunktowy(
        szerokoscScianyMM: Double,
        wysokoscMaksymalnaMM: Double,
        wysokoscNiskaMM: Double,
        strona:
            StronaSkosu
    ) -> [PunktPomiarowySkosu] {
        let width =
            max(
                szerokoscScianyMM,
                1
            )
        let high =
            max(
                wysokoscMaksymalnaMM,
                1
            )
        let low =
            max(
                min(
                    wysokoscNiskaMM,
                    high
                ),
                1
            )

        switch strona {
        case .lewa:
            return [
                PunktPomiarowySkosu(
                    odlegloscOdLewejMM: 0,
                    wysokoscMM: low,
                    uwagi:
                        "Niska krawędź"
                ),
                PunktPomiarowySkosu(
                    odlegloscOdLewejMM:
                        width,
                    wysokoscMM: high,
                    uwagi:
                        "Wysoka krawędź"
                )
            ]

        case .prawa:
            return [
                PunktPomiarowySkosu(
                    odlegloscOdLewejMM: 0,
                    wysokoscMM: high,
                    uwagi:
                        "Wysoka krawędź"
                ),
                PunktPomiarowySkosu(
                    odlegloscOdLewejMM:
                        width,
                    wysokoscMM: low,
                    uwagi:
                        "Niska krawędź"
                )
            ]

        case .obie:
            return [
                PunktPomiarowySkosu(
                    odlegloscOdLewejMM: 0,
                    wysokoscMM: low,
                    uwagi:
                        "Lewa niska krawędź"
                ),
                PunktPomiarowySkosu(
                    odlegloscOdLewejMM:
                        width / 2,
                    wysokoscMM: high,
                    uwagi:
                        "Najwyższy punkt"
                ),
                PunktPomiarowySkosu(
                    odlegloscOdLewejMM:
                        width,
                    wysokoscMM: low,
                    uwagi:
                        "Prawa niska krawędź"
                )
            ]

        case .sufitDwuspadowy:
            return [
                PunktPomiarowySkosu(
                    odlegloscOdLewejMM: 0,
                    wysokoscMM: low,
                    uwagi:
                        "Lewa okapowa"
                ),
                PunktPomiarowySkosu(
                    odlegloscOdLewejMM:
                        width / 2,
                    wysokoscMM: high,
                    uwagi:
                        "Kalenica"
                ),
                PunktPomiarowySkosu(
                    odlegloscOdLewejMM:
                        width,
                    wysokoscMM: low,
                    uwagi:
                        "Prawa okapowa"
                )
            ]
        }
    }
}
