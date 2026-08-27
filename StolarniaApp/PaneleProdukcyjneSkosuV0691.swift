
import DomainCore
import Foundation

struct PunktKonturuPaneluV0691:
    Codable,
    Hashable,
    Sendable
{
    var xMM: Double
    var yMM: Double
}

enum TypPaneluSkosuV0691:
    String,
    Codable,
    CaseIterable,
    Identifiable,
    Hashable,
    Sendable
{
    case front
    case plecy
    case bokLewy
    case bokPrawy
    case wieniecSkosny
    case panelPionowy

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .front:
            return "Front"
        case .plecy:
            return "Plecy"
        case .bokLewy:
            return "Bok lewy"
        case .bokPrawy:
            return "Bok prawy"
        case .wieniecSkosny:
            return "Wieniec pod skosem"
        case .panelPionowy:
            return "Panel pionowy"
        }
    }
}

struct PanelProdukcyjnySkosuV0691:
    Identifiable,
    Codable,
    Hashable,
    Sendable
{
    var id: String
    var typ: TypPaneluSkosuV0691
    var kod: String
    var nazwa: String
    var kontur: [PunktKonturuPaneluV0691]
    var gruboscMM: Double
    var glebokoscMM: Double
    var katMontazuStopnie: Double
    var profilID: UUID
    var assemblyID: UUID
    var rezerwaMontazowaMM: Double
    var wymagaSzablonu: Bool

    var szerokoscObrysuMM: Double {
        guard
            let minimum = kontur.map(\.xMM).min(),
            let maximum = kontur.map(\.xMM).max()
        else {
            return 0
        }
        return max(maximum - minimum, 0)
    }

    var wysokoscObrysuMM: Double {
        guard
            let minimum = kontur.map(\.yMM).min(),
            let maximum = kontur.map(\.yMM).max()
        else {
            return 0
        }
        return max(maximum - minimum, 0)
    }

    var poleMM2: Double {
        guard kontur.count >= 3 else {
            return 0
        }

        var sum = 0.0
        for index in kontur.indices {
            let current = kontur[index]
            let next = kontur[(index + 1) % kontur.count]
            sum += current.xMM * next.yMM
                - next.xMM * current.yMM
        }

        return abs(sum) / 2
    }

    var obwodMM: Double {
        guard kontur.count >= 2 else {
            return 0
        }

        var sum = 0.0
        for index in kontur.indices {
            let current = kontur[index]
            let next = kontur[(index + 1) % kontur.count]
            sum += hypot(
                next.xMM - current.xMM,
                next.yMM - current.yMM
            )
        }

        return sum
    }
}

struct RaportPaneliSkosuV0691:
    Codable,
    Hashable,
    Sendable
{
    var wersjaSchematu = 1
    var profilID: UUID
    var assemblyID: UUID
    var panele: [PanelProdukcyjnySkosuV0691]
    var ostrzezenia: [String]
    var wygenerowano: Date
}

struct OdcinekGornejKrawedziSkosuV0691:
    Hashable,
    Sendable
{
    var start: PunktKonturuPaneluV0691
    var koniec: PunktKonturuPaneluV0691

    var dlugoscMM: Double {
        hypot(
            koniec.xMM - start.xMM,
            koniec.yMM - start.yMM
        )
    }

    var katStopnie: Double {
        atan2(
            koniec.yMM - start.yMM,
            koniec.xMM - start.xMM
        ) * 180 / .pi
    }
}

enum PaneleProdukcyjneSkosuV0691 {
    static let minimalnyWymiarPaneluMM = 2.0
    static let domyslnaGruboscPlytyMM = 18.0
    static let domyslnaGruboscPlecowMM = 3.0
    /// Fuga między frontami — z konwencji warsztatu.
    ///
    /// Stało tu `2.0`, czyli **luz na jedno lico wzięty za całą fugę**.
    /// To ta sama pomyłka nazewnicza, przed którą ostrzega komentarz
    /// w `ProductionRules`: `frontClearancePerEdge` (2 mm) to luz od krawędzi,
    /// a `frontToFrontGap` (4 mm) to odstęp między dwoma frontami.
    /// Panele skosu wychodziły przez to o 2 mm szersze, niż powinny.
    static let szczelinaMiedzyFrontamiMM =
        ProductionRules.frontToFrontGap.rawValue

    // MARK: - Punkt wejścia (obie wersje skosów)

    static func raport(
        dla assembly: FurnitureAssembly,
        room: RoomDefinition,
        at date: Date = Date()
    ) -> RaportPaneliSkosuV0691? {
        // Typ 2 (ucięty tył) ma pierwszeństwo — jeśli jest profil głębokościowy
        if let r = raportUcietyTyl(
            dla: assembly,
            room: room,
            at: date
        ) { return r }

        // Typ 1 (ucięta góra) — oryginal
        return raportUcietaGora(dla: assembly, room: room, at: date)
    }

    // MARK: - Typ 1: ucięta góra (oryginalna logika, przemianowana)

    private static func raportUcietaGora(
        dla assembly: FurnitureAssembly,
        room: RoomDefinition,
        at date: Date = Date()
    ) -> RaportPaneliSkosuV0691? {
        guard
            let placement = assembly.placement,
            let wallID = placement.wallID,
            let profile =
                SilnikSkosuPomieszczeniaV069
                    .profilSkosu(
                        dla: wallID,
                        w: room
                    ),
            let localContour =
                lokalnyKonturZespolu(
                    assembly: assembly,
                    profil: profile
                ),
            jestKonturemScietym(
                localContour,
                oczekiwanaWysokoscMM:
                    assembly.size.height.rawValue
            )
        else {
            return nil
        }

        var panels: [PanelProdukcyjnySkosuV0691] = []
        var warnings: [String] = []

        let profileID = profile.id.rawValue
        let assemblyID = assembly.id.rawValue
        let width = assembly.size.width.rawValue
        let depth = assembly.size.depth.rawValue
        let thickness = domyslnaGruboscPlytyMM

        let configuration =
            KonfiguracjaFunkcjonalnaModuluV068Resolver
                .konfiguracja(
                    dla: assembly
                )
        let frontCount =
            configuration?
                .front
                .bezpiecznaLiczbaFrontow
            ?? 1

        let frontContours =
            podzielKonturFrontow(
                localContour,
                liczbaFrontow: frontCount,
                szerokoscCalkowitaMM: width,
                szczelinaMM:
                    szczelinaMiedzyFrontamiMM
            )

        for (index, contour) in frontContours.enumerated() {
            guard contour.count >= 3 else {
                warnings.append(
                    "Pominięto front \(index + 1), ponieważ po przycięciu nie ma prawidłowego konturu."
                )
                continue
            }

            panels.append(
                makePanel(
                    id:
                        "\(assemblyID.uuidString.lowercased())-front-\(index + 1)",
                    typ: .front,
                    kod: "FR-SK-\(index + 1)",
                    nazwa:
                        frontCount > 1
                        ? "Front pod skosem \(index + 1)"
                        : "Front pod skosem",
                    kontur: contour,
                    gruboscMM: thickness,
                    glebokoscMM: thickness,
                    katMontazuStopnie: 0,
                    profile: profile,
                    assembly: assembly
                )
            )
        }

        panels.append(
            makePanel(
                id:
                    "\(assemblyID.uuidString.lowercased())-back",
                typ: .plecy,
                kod: "PC-SK",
                nazwa: "Plecy pod skosem",
                kontur: localContour,
                gruboscMM:
                    domyslnaGruboscPlecowMM,
                glebokoscMM:
                    domyslnaGruboscPlecowMM,
                katMontazuStopnie: 0,
                profile: profile,
                assembly: assembly
            )
        )

        let topEdge = gornaKrawedz(
            z: localContour
        )
        let leftHeight =
            wysokoscGornejKrawedzi(
                topEdge,
                xMM: 0
            )
            ?? 0
        let rightHeight =
            wysokoscGornejKrawedzi(
                topEdge,
                xMM: width
            )
            ?? 0

        panels.append(
            makePanel(
                id:
                    "\(assemblyID.uuidString.lowercased())-side-left",
                typ: .bokLewy,
                kod: "SB-L-SK",
                nazwa: "Bok lewy pod skosem",
                kontur:
                    prostokat(
                        szerokoscMM: depth,
                        wysokoscMM: leftHeight
                    ),
                gruboscMM: thickness,
                glebokoscMM: depth,
                katMontazuStopnie: 0,
                profile: profile,
                assembly: assembly
            )
        )

        panels.append(
            makePanel(
                id:
                    "\(assemblyID.uuidString.lowercased())-side-right",
                typ: .bokPrawy,
                kod: "SB-P-SK",
                nazwa: "Bok prawy pod skosem",
                kontur:
                    prostokat(
                        szerokoscMM: depth,
                        wysokoscMM: rightHeight
                    ),
                gruboscMM: thickness,
                glebokoscMM: depth,
                katMontazuStopnie: 0,
                profile: profile,
                assembly: assembly
            )
        )

        for (index, segment) in
            odcinkiGornejKrawedzi(
                localContour
            )
            .enumerated()
        {
            guard segment.dlugoscMM
                    >= minimalnyWymiarPaneluMM
            else {
                continue
            }

            panels.append(
                makePanel(
                    id:
                        "\(assemblyID.uuidString.lowercased())-top-\(index + 1)",
                    typ: .wieniecSkosny,
                    kod: "WG-SK-\(index + 1)",
                    nazwa:
                        "Wieniec pod skosem \(index + 1)",
                    kontur:
                        prostokat(
                            szerokoscMM:
                                segment.dlugoscMM,
                            wysokoscMM: depth
                        ),
                    gruboscMM: thickness,
                    glebokoscMM: depth,
                    katMontazuStopnie:
                        segment.katStopnie,
                    profile: profile,
                    assembly: assembly
                )
            )
        }

        if topEdge.count > 2 {
            warnings.append(
                "Profil ma więcej niż jeden odcinek. Wieniec górny został podzielony zgodnie z punktami pomiarowymi."
            )
        }

        if profile.recommendation() == .requireTemplate {
            warnings.append(
                "Odchyłka profilu przekracza próg szablonu. Przed produkcją wykonaj fizyczny szablon."
            )
        }

        return RaportPaneliSkosuV0691(
            profilID: profileID,
            assemblyID: assemblyID,
            panele: panels,
            ostrzezenia: warnings,
            wygenerowano: date
        )
    }

    // MARK: - Typ 2: ucięty tył

    /// Generuje panele produkcyjne dla szafy z uciętym tyłem.
    ///
    /// Szafa stoi prosto (front ma pełną wysokość H), ale tył i boki są
    /// przycięte do wysokości wyznaczonej przez profil głębokościowy.
    ///
    /// Panele:
    /// - Front:     W × h_front (prostokąt, pełna widoczna wysokość)
    /// - Plecy:     W × h_tył  (prostokąt, ucięty gdzie sufit niższy)
    /// - Bok lewy:  trapez (głębokość × zmienna wysokość od tyłu do frontu)
    /// - Bok prawy: jw.
    /// - Wieniec:   W × D (prostokąt montowany pod kątem skosu)
    static func raportUcietyTyl(
        dla assembly: FurnitureAssembly,
        room: RoomDefinition,
        at date: Date = Date()
    ) -> RaportPaneliSkosuV0691? {
        guard
            let placement = assembly.placement,
            let wallID = placement.wallID,
            let profile = SilnikSkosuPomieszczeniaV069
                .profilSkosuGlebokosci(dla: wallID, w: room)
        else { return nil }

        guard let kontur = try? SilnikSkosuPomieszczeniaV069
                .konturMeblaUcietyTyl(
                    glebokoscMM: assembly.size.depth.rawValue,
                    wysokoscMM:  assembly.size.height.rawValue,
                    profil: profile
                ),
              kontur.jestSciety
        else { return nil }

        let width      = assembly.size.width.rawValue
        let depth      = assembly.size.depth.rawValue
        let thickness  = domyslnaGruboscPlytyMM
        let assemblyID = assembly.id.rawValue
        let profileID  = profile.id.rawValue

        var panels:   [PanelProdukcyjnySkosuV0691] = []
        var warnings: [String] = []

        // --- Front: W × h_front prostokąt ---
        let configuration = KonfiguracjaFunkcjonalnaModuluV068Resolver
            .konfiguracja(dla: assembly)
        let frontCount = configuration?.front.bezpiecznaLiczbaFrontow ?? 1

        let frontContours = podzielKonturFrontow(
            prostokat(szerokoscMM: width, wysokoscMM: kontur.frontalnaWysokoscMM),
            liczbaFrontow: frontCount,
            szerokoscCalkowitaMM: width,
            szczelinaMM: szczelinaMiedzyFrontamiMM
        )
        for (index, contour) in frontContours.enumerated() {
            guard contour.count >= 3 else {
                warnings.append("Pominięto front \(index + 1) — zbyt mały kontur po podziale.")
                continue
            }
            panels.append(makePanel(
                id:    "\(assemblyID.uuidString.lowercased())-front-\(index + 1)",
                typ:   .front,
                kod:   "FR-TYL-\(index + 1)",
                nazwa: frontCount > 1
                    ? "Front (pełna wys.) \(index + 1)"
                    : "Front (pełna wysokość)",
                kontur: contour,
                gruboscMM: thickness,
                glebokoscMM: thickness,
                katMontazuStopnie: 0,
                profile: profile,
                assembly: assembly
            ))
        }

        // --- Plecy: W × h_tył prostokąt (ucięty) ---
        panels.append(makePanel(
            id:    "\(assemblyID.uuidString.lowercased())-back",
            typ:   .plecy,
            kod:   "PC-TYL",
            nazwa: "Plecy (ucięte pod skosem)",
            kontur: prostokat(
                szerokoscMM: width,
                wysokoscMM:  kontur.tylnaWysokoscMM
            ),
            gruboscMM:  domyslnaGruboscPlecowMM,
            glebokoscMM: domyslnaGruboscPlecowMM,
            katMontazuStopnie: 0,
            profile: profile,
            assembly: assembly
        ))

        // --- Boki lewy i prawy: trapez głębokość × zmienna wysokość ---
        let boczny = konturBokuUcietyTyl(
            profilBoku: kontur.profilBoku,
            glebokoscMM: depth
        )
        panels.append(makePanel(
            id:    "\(assemblyID.uuidString.lowercased())-side-left",
            typ:   .bokLewy,
            kod:   "SB-L-TYL",
            nazwa: "Bok lewy (trapez pod skosem)",
            kontur: boczny,
            gruboscMM: thickness,
            glebokoscMM: depth,
            katMontazuStopnie: 0,
            profile: profile,
            assembly: assembly
        ))
        panels.append(makePanel(
            id:    "\(assemblyID.uuidString.lowercased())-side-right",
            typ:   .bokPrawy,
            kod:   "SB-P-TYL",
            nazwa: "Bok prawy (trapez pod skosem)",
            kontur: boczny,
            gruboscMM: thickness,
            glebokoscMM: depth,
            katMontazuStopnie: 0,
            profile: profile,
            assembly: assembly
        ))

        // --- Wieniec górny: W × D, montowany pod kątem skosu ---
        panels.append(makePanel(
            id:    "\(assemblyID.uuidString.lowercased())-top",
            typ:   .wieniecSkosny,
            kod:   "WG-TYL",
            nazwa: "Wieniec górny (skośny)",
            kontur: prostokat(szerokoscMM: width, wysokoscMM: depth),
            gruboscMM: thickness,
            glebokoscMM: depth,
            katMontazuStopnie: kontur.katSkosuStopnie,
            profile: profile,
            assembly: assembly
        ))

        if profile.recommendation() == .requireTemplate {
            warnings.append(
                "Odchyłka profilu przekracza próg szablonu. Przed produkcją wykonaj fizyczny szablon."
            )
        }

        return RaportPaneliSkosuV0691(
            profilID:    profileID,
            assemblyID:  assemblyID,
            panele:      panels,
            ostrzezenia: warnings,
            wygenerowano: date
        )
    }

    /// Buduje kontur boczny szafy z uciętym tyłem (trapez lub wielokąt).
    ///
    /// Konwencja osi: X = głębokość od ściany (0 = tył/ściana, D = front),
    /// Y = wysokość od podłogi.
    ///
    /// Ścieżka konturu (CCW):
    ///   (0,0) → (D,0) → (D, h_front) → [...punkty profilu wstecz...] → (0, h_tył)
    private static func konturBokuUcietyTyl(
        profilBoku: [PunktProfiluSkosuV069],   // x=0..D od ściany; y=efektywna wys.
        glebokoscMM: Double
    ) -> [PunktKonturuPaneluV0691] {
        let sorted = profilBoku.sorted { $0.xMM < $1.xMM }

        // Dół: tył-dół → front-dół
        var points: [PunktKonturuPaneluV0691] = [
            PunktKonturuPaneluV0691(xMM: 0,           yMM: 0),
            PunktKonturuPaneluV0691(xMM: glebokoscMM, yMM: 0)
        ]

        // Góra: front-góra → (pośrednie) → tył-góra (od ostatniego do pierwszego)
        let topEdge = sorted.reversed().map {
            PunktKonturuPaneluV0691(xMM: $0.xMM, yMM: $0.wysokoscMM)
        }
        points.append(contentsOf: topEdge)

        return uprosc(points)
    }

    static func lokalnyKonturZespolu(
        assembly: FurnitureAssembly,
        profil: WallProfileDefinition
    ) -> [PunktKonturuPaneluV0691]? {
        guard let placement = assembly.placement else {
            return nil
        }

        guard
            let contour =
                try? SilnikSkosuPomieszczeniaV069
                    .konturMebla(
                        xMM:
                            placement
                                .offsetAlongWall
                                .rawValue,
                        yMM:
                            placement
                                .bottomOffset
                                .rawValue,
                        szerokoscMM:
                            assembly.size.width.rawValue,
                        wysokoscMM:
                            assembly.size.height.rawValue,
                        profil: profil
                    )
        else {
            return nil
        }

        let xOrigin =
            placement.offsetAlongWall.rawValue
        let yOrigin =
            placement.bottomOffset.rawValue

        return uprosc(
            contour.punkty.map {
                PunktKonturuPaneluV0691(
                    xMM:
                        $0.xMM - xOrigin,
                    yMM:
                        $0.wysokoscMM - yOrigin
                )
            }
        )
    }

    static func konturPionowegoKomponentu(
        assembly: FurnitureAssembly,
        profil: WallProfileDefinition,
        xMM: Double,
        yMM: Double,
        szerokoscMM: Double,
        wysokoscMM: Double
    ) -> [PunktKonturuPaneluV0691]? {
        guard
            let placement = assembly.placement,
            szerokoscMM > 0,
            wysokoscMM > 0
        else {
            return nil
        }

        let xStartGlobal =
            placement.offsetAlongWall.rawValue
            + xMM
        let xEndGlobal =
            xStartGlobal + szerokoscMM
        let yBottomGlobal =
            placement.bottomOffset.rawValue
            + yMM
        let yTopGlobal =
            yBottomGlobal + wysokoscMM

        var samples =
            [xStartGlobal, xEndGlobal]

        samples.append(
            contentsOf:
                profil.points
                    .map {
                        $0.distanceAlongProfile.rawValue
                    }
                    .filter {
                        $0 > xStartGlobal
                        && $0 < xEndGlobal
                    }
        )

        samples =
            Array(Set(samples))
                .sorted()

        let clearance =
            max(
                profil
                    .installationAllowance
                    .rawValue
                + profil.targetGap.rawValue,
                0
            )

        var top: [PunktKonturuPaneluV0691] = []
        for sample in samples {
            guard
                let height =
                    SilnikSkosuPomieszczeniaV069
                        .wysokosc(
                            w:
                                Millimeters(sample),
                            profil: profil
                        )
            else {
                return nil
            }

            let clippedGlobal =
                min(
                    yTopGlobal,
                    height.rawValue - clearance
                )
            let localY =
                clippedGlobal - yBottomGlobal

            guard localY
                    > minimalnyWymiarPaneluMM
            else {
                return nil
            }

            top.append(
                PunktKonturuPaneluV0691(
                    xMM:
                        sample - xStartGlobal,
                    yMM:
                        min(
                            max(localY, 0),
                            wysokoscMM
                        )
                )
            )
        }

        let contour =
            [
                PunktKonturuPaneluV0691(
                    xMM: 0,
                    yMM: 0
                ),
                PunktKonturuPaneluV0691(
                    xMM: szerokoscMM,
                    yMM: 0
                )
            ]
            + top.reversed()

        return uprosc(
            Array(contour)
        )
    }

    static func odcinkiGornejKrawedzi(
        _ contour:
            [PunktKonturuPaneluV0691]
    ) -> [OdcinekGornejKrawedziSkosuV0691] {
        let top = gornaKrawedz(
            z: contour
        )
        guard top.count >= 2 else {
            return []
        }

        return zip(
            top,
            top.dropFirst()
        )
        .map {
            OdcinekGornejKrawedziSkosuV0691(
                start: $0.0,
                koniec: $0.1
            )
        }
    }

    static func gornaKrawedz(
        z contour:
            [PunktKonturuPaneluV0691]
    ) -> [PunktKonturuPaneluV0691] {
        guard
            let minimumY =
                contour.map(\.yMM).min()
        else {
            return []
        }

        return contour
            .filter {
                $0.yMM > minimumY + 0.5
            }
            .sorted {
                if abs($0.xMM - $1.xMM) > 0.001 {
                    return $0.xMM < $1.xMM
                }
                return $0.yMM < $1.yMM
            }
    }

    static func jestKonturemScietym(
        _ contour:
            [PunktKonturuPaneluV0691],
        oczekiwanaWysokoscMM: Double
    ) -> Bool {
        contour.contains {
            $0.yMM
                < oczekiwanaWysokoscMM - 0.5
                && $0.yMM > 0.5
        }
    }

    static func czyRolaPionowa(
        _ role:
            FurnitureComponentRole
    ) -> Bool {
        switch role {
        case .side,
             .back,
             .front,
             .divider,
             .filler,
             .maskingPanel,
             .decorativeSide,
             .reinforcement,
             .custom:
            return true
        default:
            return false
        }
    }

    private static func makePanel(
        id: String,
        typ: TypPaneluSkosuV0691,
        kod: String,
        nazwa: String,
        kontur: [PunktKonturuPaneluV0691],
        gruboscMM: Double,
        glebokoscMM: Double,
        katMontazuStopnie: Double,
        profile: WallProfileDefinition,
        assembly: FurnitureAssembly
    ) -> PanelProdukcyjnySkosuV0691 {
        PanelProdukcyjnySkosuV0691(
            id: id,
            typ: typ,
            kod: kod,
            nazwa: nazwa,
            kontur: uprosc(kontur),
            gruboscMM: gruboscMM,
            glebokoscMM: glebokoscMM,
            katMontazuStopnie:
                katMontazuStopnie,
            profilID:
                profile.id.rawValue,
            assemblyID:
                assembly.id.rawValue,
            rezerwaMontazowaMM:
                profile
                    .installationAllowance
                    .rawValue
                + profile.targetGap.rawValue,
            wymagaSzablonu:
                profile.recommendation()
                    == .requireTemplate
        )
    }

    private static func prostokat(
        szerokoscMM: Double,
        wysokoscMM: Double
    ) -> [PunktKonturuPaneluV0691] {
        let width =
            max(
                szerokoscMM,
                minimalnyWymiarPaneluMM
            )
        let height =
            max(
                wysokoscMM,
                minimalnyWymiarPaneluMM
            )

        return [
            PunktKonturuPaneluV0691(
                xMM: 0,
                yMM: 0
            ),
            PunktKonturuPaneluV0691(
                xMM: width,
                yMM: 0
            ),
            PunktKonturuPaneluV0691(
                xMM: width,
                yMM: height
            ),
            PunktKonturuPaneluV0691(
                xMM: 0,
                yMM: height
            )
        ]
    }

    private static func wysokoscGornejKrawedzi(
        _ points:
            [PunktKonturuPaneluV0691],
        xMM: Double
    ) -> Double? {
        guard
            let first = points.first,
            let last = points.last
        else {
            return nil
        }

        if xMM <= first.xMM {
            return first.yMM
        }
        if xMM >= last.xMM {
            return last.yMM
        }

        for pair in zip(
            points,
            points.dropFirst()
        ) {
            guard
                xMM >= pair.0.xMM,
                xMM <= pair.1.xMM
            else {
                continue
            }

            let run =
                pair.1.xMM - pair.0.xMM
            guard abs(run) > 0.001 else {
                return pair.0.yMM
            }

            let progress =
                (xMM - pair.0.xMM) / run
            return pair.0.yMM
                + (
                    pair.1.yMM
                    - pair.0.yMM
                )
                * progress
        }

        return nil
    }

    private static func podzielKonturFrontow(
        _ contour:
            [PunktKonturuPaneluV0691],
        liczbaFrontow: Int,
        szerokoscCalkowitaMM: Double,
        szczelinaMM: Double
    ) -> [[PunktKonturuPaneluV0691]] {
        let count =
            min(
                max(
                    liczbaFrontow,
                    1
                ),
                12
            )
        let totalGap =
            Double(count - 1)
            * max(szczelinaMM, 0)
        let available =
            max(
                szerokoscCalkowitaMM
                - totalGap,
                minimalnyWymiarPaneluMM
                    * Double(count)
            )
        let panelWidth =
            available / Double(count)

        var result:
            [[PunktKonturuPaneluV0691]] = []

        for index in 0..<count {
            let minimumX =
                Double(index)
                * (
                    panelWidth
                    + max(szczelinaMM, 0)
                )
            let maximumX =
                minimumX + panelWidth

            let clipped =
                clipPolygon(
                    contour,
                    minimumX: minimumX,
                    maximumX: maximumX
                )

            guard !clipped.isEmpty else {
                continue
            }

            result.append(
                uprosc(
                    clipped.map {
                        PunktKonturuPaneluV0691(
                            xMM:
                                $0.xMM - minimumX,
                            yMM:
                                $0.yMM
                        )
                    }
                )
            )
        }

        return result
    }

    private static func clipPolygon(
        _ polygon:
            [PunktKonturuPaneluV0691],
        minimumX: Double,
        maximumX: Double
    ) -> [PunktKonturuPaneluV0691] {
        let leftClipped =
            clip(
                polygon,
                inside: {
                    $0.xMM >= minimumX - 0.001
                },
                intersection: {
                    intersection(
                        from: $0,
                        to: $1,
                        xMM: minimumX
                    )
                }
            )

        return clip(
            leftClipped,
            inside: {
                $0.xMM <= maximumX + 0.001
            },
            intersection: {
                intersection(
                    from: $0,
                    to: $1,
                    xMM: maximumX
                )
            }
        )
    }

    private static func clip(
        _ polygon:
            [PunktKonturuPaneluV0691],
        inside:
            (PunktKonturuPaneluV0691)
                -> Bool,
        intersection:
            (
                PunktKonturuPaneluV0691,
                PunktKonturuPaneluV0691
            ) -> PunktKonturuPaneluV0691
    ) -> [PunktKonturuPaneluV0691] {
        guard let last = polygon.last else {
            return []
        }

        var output:
            [PunktKonturuPaneluV0691] = []
        var previous = last
        var previousInside =
            inside(previous)

        for current in polygon {
            let currentInside =
                inside(current)

            if currentInside {
                if !previousInside {
                    output.append(
                        intersection(
                            previous,
                            current
                        )
                    )
                }
                output.append(current)
            } else if previousInside {
                output.append(
                    intersection(
                        previous,
                        current
                    )
                )
            }

            previous = current
            previousInside =
                currentInside
        }

        return output
    }

    private static func intersection(
        from start:
            PunktKonturuPaneluV0691,
        to end:
            PunktKonturuPaneluV0691,
        xMM: Double
    ) -> PunktKonturuPaneluV0691 {
        let run =
            end.xMM - start.xMM
        guard abs(run) > 0.001 else {
            return PunktKonturuPaneluV0691(
                xMM: xMM,
                yMM: start.yMM
            )
        }

        let progress =
            (xMM - start.xMM) / run
        return PunktKonturuPaneluV0691(
            xMM: xMM,
            yMM:
                start.yMM
                + (
                    end.yMM - start.yMM
                )
                * progress
        )
    }

    private static func uprosc(
        _ points:
            [PunktKonturuPaneluV0691]
    ) -> [PunktKonturuPaneluV0691] {
        guard !points.isEmpty else {
            return []
        }

        var result:
            [PunktKonturuPaneluV0691] = []

        for point in points {
            let normalized =
                PunktKonturuPaneluV0691(
                    xMM:
                        (point.xMM * 1_000)
                            .rounded()
                            / 1_000,
                    yMM:
                        (point.yMM * 1_000)
                            .rounded()
                            / 1_000
                )

            if let last = result.last,
               abs(last.xMM - normalized.xMM)
                    < 0.001,
               abs(last.yMM - normalized.yMM)
                    < 0.001 {
                continue
            }

            result.append(normalized)
        }

        if result.count > 1,
           let first = result.first,
           let last = result.last,
           abs(first.xMM - last.xMM) < 0.001,
           abs(first.yMM - last.yMM) < 0.001 {
            result.removeLast()
        }

        return result
    }
}
