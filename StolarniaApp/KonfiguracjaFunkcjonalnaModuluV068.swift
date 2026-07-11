import DomainCore
import Foundation
import os

enum KierunekOtwarciaFrontuV068:
    String,
    Codable,
    CaseIterable,
    Identifiable,
    Hashable
{
    case lewy
    case prawy
    case doGory
    case wDol
    case szuflada
    case przesuwny
    case staly

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .lewy:
            return "Drzwi lewe"
        case .prawy:
            return "Drzwi prawe"
        case .doGory:
            return "Podnoszony do góry"
        case .wDol:
            return "Opuszczany w dół"
        case .szuflada:
            return "Szuflada"
        case .przesuwny:
            return "Przesuwny"
        case .staly:
            return "Panel stały"
        }
    }

    var symbolSystemowy: String {
        switch self {
        case .lewy:
            return "door.left.hand.open"
        case .prawy:
            return "door.right.hand.open"
        case .doGory:
            return "arrow.up.to.line"
        case .wDol:
            return "arrow.down.to.line"
        case .szuflada:
            return "shippingbox"
        case .przesuwny:
            return "arrow.left.and.right"
        case .staly:
            return "rectangle"
        }
    }
}

struct KonfiguracjaFrontuModuluV068:
    Codable,
    Hashable
{
    var liczbaFrontow = 1
    var otwarcie:
        KierunekOtwarciaFrontuV068 = .lewy
    var katOtwarciaStopnie = 100.0
    var profilOkuciaID = ""
    var pokazujKierunekNaRysunku = true

    var bezpiecznaLiczbaFrontow: Int {
        min(max(liczbaFrontow, 1), 12)
    }
}

struct KonfiguracjaSzufladModuluV068:
    Codable,
    Hashable
{
    var profilID = ""
    var pokazujUproszczonaGeometrie3D = true
}

struct KonfiguracjaFunkcjonalnaModuluV068:
    Codable,
    Hashable
{
    var wersjaSchematu = 1
    var front =
        KonfiguracjaFrontuModuluV068()
    var szuflady =
        KonfiguracjaSzufladModuluV068()

    /// Automatycznie oblicza domyślną liczbę frontów na podstawie szerokości modułu.
    /// Standard europejski: ≤600 mm → 1 front, 601–900 mm → 2 fronty, >900 mm → 3 fronty.
    /// Szuflady: każda szuflada ma własny front (drawerCount > 0 nadpisuje regułę szerokości).
    static func autoFrontCount(
        drawerCount: Int,
        widthMM: Double
    ) -> Int {
        guard drawerCount == 0 else {
            return drawerCount
        }
        if widthMM > 900 { return 3 }
        if widthMM > 600 { return 2 }
        return 1
    }

    static func domyslna(
        template: FurnitureTemplate,
        drawerCount: Int,
        widthMM: Double = 0,
        preset:
            PresetOkucKuchniV068 =
                PresetOkucKuchniV068Store.wczytaj()
    ) -> Self {
        let name = (
            template.name
            + " "
            + template.code
        )
        .folding(
            options: [
                .diacriticInsensitive,
                .caseInsensitive
            ],
            locale: .current
        )
        .lowercased()

        let opening:
            KierunekOtwarciaFrontuV068

        if drawerCount > 0 {
            opening = .szuflada
        } else if name.contains("przesuw") {
            opening = .przesuwny
        } else if name.contains("okap")
            || name.contains("aventos")
            || name.contains("podnos") {
            opening = .doGory
        } else {
            opening = .lewy
        }

        let hardwareID: String
        switch opening {
        case .doGory:
            hardwareID =
                preset.profilPodnosnikaID
        case .lewy, .prawy:
            hardwareID =
                preset.profilZawiasuID
        default:
            hardwareID = ""
        }

        let frontCount = autoFrontCount(
            drawerCount: drawerCount,
            widthMM: widthMM
        )

        return Self(
            front:
                KonfiguracjaFrontuModuluV068(
                    liczbaFrontow: frontCount,
                    otwarcie: opening,
                    katOtwarciaStopnie:
                        opening == .doGory
                        ? 95
                        : 100,
                    profilOkuciaID:
                        hardwareID,
                    pokazujKierunekNaRysunku:
                        true
                ),
            szuflady:
                KonfiguracjaSzufladModuluV068(
                    profilID:
                        preset
                            .profilSystemuSzufladID,
                    pokazujUproszczonaGeometrie3D:
                        true
                )
        )
    }
}

struct PresetOkucKuchniV068:
    Codable,
    Hashable
{
    var profilZawiasuID = ""
    var profilPodnosnikaID = ""
    var profilSystemuSzufladID = ""
    var dataAktualizacji = Date()
}

enum PresetOkucKuchniV068Store {
    private static let key =
        "PresetOkucKuchniV068.v1"

    static func wczytaj(
        defaults:
            UserDefaults = .standard
    ) -> PresetOkucKuchniV068 {
        guard
            let data =
                defaults.data(
                    forKey: key
                ),
            let value =
                try? JSONDecoder()
                    .decode(
                        PresetOkucKuchniV068.self,
                        from: data
                    )
        else {
            return PresetOkucKuchniV068()
        }

        return value
    }

    static func zapisz(
        _ value:
            PresetOkucKuchniV068,
        defaults:
            UserDefaults = .standard
    ) {
        guard
            let data =
                try? JSONEncoder()
                    .encode(value)
        else {
            StolarniaLogger.zapis.error(
                "Nie udało się zakodować presetu okuć v0.68."
            )
            return
        }

        defaults.set(
            data,
            forKey: key
        )
    }
}

enum ProfilOkuciaResolverV068 {
    static func profile(
        kategorii categories:
            Set<KategoriaAkcesoriumMeblowego>
    ) -> [ProfilAkcesoriumMeblowego] {
        KatalogRegulAkcesoriow
            .profile
            .filter {
                categories
                    .contains(
                        $0.kategoria
                    )
            }
            .sorted {
                let left =
                    "\($0.producent) \($0.rodzina) \($0.model)"
                let right =
                    "\($1.producent) \($1.rodzina) \($1.model)"
                return left
                    .localizedStandardCompare(
                        right
                    )
                    == .orderedAscending
            }
    }

    static func profil(
        id: String
    ) -> ProfilAkcesoriumMeblowego? {
        guard !id.isEmpty else {
            return nil
        }

        return KatalogRegulAkcesoriow
            .profil(id: id)
    }

    static func jestAventos(
        _ profile:
            ProfilAkcesoriumMeblowego?
    ) -> Bool {
        guard let profile else {
            return false
        }

        let text = (
            profile.producent
            + " "
            + profile.rodzina
            + " "
            + profile.model
        )
        .folding(
            options: [
                .diacriticInsensitive,
                .caseInsensitive
            ],
            locale: .current
        )
        .lowercased()

        return profile.kategoria
            == .podnosnikFrontu
            || text.contains(
                "aventos"
            )
    }

    static func efektywneOtwarcie(
        konfiguracja:
            KonfiguracjaFunkcjonalnaModuluV068
    ) -> KierunekOtwarciaFrontuV068 {
        let profile =
            profil(
                id:
                    konfiguracja
                        .front
                        .profilOkuciaID
            )

        if jestAventos(profile) {
            return .doGory
        }

        return konfiguracja
            .front
            .otwarcie
    }

    static func opis(
        id: String
    ) -> String {
        guard let profile =
            profil(id: id)
        else {
            return "Brak"
        }

        return [
            profile.producent,
            profile.rodzina,
            profile.model
        ]
        .filter {
            !$0.isEmpty
        }
        .joined(separator: " • ")
    }
}

enum KonfiguracjaFunkcjonalnaModuluV068Resolver {
    static func kluczModulu(
        _ assemblyID:
            FurnitureAssemblyID
    ) -> String {
        StabilnyKluczDomenowy
            .utworz(
                dla: assemblyID,
                prefiks:
                    "furniture"
            )
    }

    static func karta(
        dla assembly:
            FurnitureAssembly
    ) -> KartaTechnicznaSzafki? {
        KartaTechnicznaSzafkiStore
            .card(
                forModuleKey:
                    kluczModulu(
                        assembly.id
                    )
            )
    }

    static func konfiguracja(
        dla assembly:
            FurnitureAssembly
    ) -> KonfiguracjaFunkcjonalnaModuluV068? {
        karta(
            dla: assembly
        )?
        .konfiguracjaFunkcjonalnaV068
    }

    static func efektywneOtwarcie(
        dla assembly:
            FurnitureAssembly
    ) -> KierunekOtwarciaFrontuV068? {
        guard let configuration =
            konfiguracja(
                dla: assembly
            )
        else {
            return nil
        }

        return ProfilOkuciaResolverV068
            .efektywneOtwarcie(
                konfiguracja:
                    configuration
            )
    }
}

enum GeometriaSzuflad3DV068 {
    private static let movingPrefix =
        "V068-DRAWER-MOVING-"
    private static let frontPrefix =
        "V068-DRAWER-FRONT-"
    private static let railPrefix =
        "V068-DRAWER-RAIL-"

    static func jestRuchomymElementemSzuflady(
        _ component:
            FurnitureComponent
    ) -> Bool {
        if component.code
            .hasPrefix(
                movingPrefix
            )
            || component.code
                .hasPrefix(
                    frontPrefix
                ) {
            return true
        }

        if standardowyNumerSzuflady(
            dla: component
        ) == nil {
            return false
        }

        return !standardowyKodProwadnicy(
            component.code
        )
    }

    static func jestElementemWygenerowanym(
        _ component:
            FurnitureComponent
    ) -> Bool {
        jestRuchomymElementemSzuflady(
            component
        )
        || component.code
            .hasPrefix(
                railPrefix
            )
        || standardowyKodProwadnicy(
            component.code
        )
    }

    static func numerSzuflady(
        dla component:
            FurnitureComponent
    ) -> Int? {
        guard jestRuchomymElementemSzuflady(
            component
        ) else {
            return nil
        }

        if let generatedNumber =
            component
            .code
            .split(separator: "-")
            .last
            .flatMap({ Int($0) }) {
            return generatedNumber
        }

        return standardowyNumerSzuflady(
            dla: component
        )
    }

    private static func standardowyNumerSzuflady(
        dla component:
            FurnitureComponent
    ) -> Int? {
        let parts = component
            .code
            .split(separator: "-")

        if parts.count >= 3,
           parts[0] == "FRONT",
           parts[1] == "SZ" {
            return Int(parts[2])
        }

        if parts.count >= 2,
           parts[0] == "SZ" {
            return Int(parts[1])
        }

        return nil
    }

    private static func standardowyKodProwadnicy(
        _ code: String
    ) -> Bool {
        let parts = code
            .split(separator: "-")

        return parts.count >= 3
            && parts[0] == "SZ"
            && parts[2] == "PROW"
    }

    static func uzupelnioneKomponenty(
        assembly:
            FurnitureAssembly,
        bazowe:
            [FurnitureComponent]
    ) -> [FurnitureComponent] {
        guard
            let card =
                KonfiguracjaFunkcjonalnaModuluV068Resolver
                    .karta(
                        dla: assembly
                    ),
            let configuration =
                card
                    .konfiguracjaFunkcjonalnaV068,
            configuration
                .szuflady
                .pokazujUproszczonaGeometrie3D
        else {
            return bazowe
        }

        let drawers =
            card
                .efektywneSzuflady
                .filter(\.aktywna)
                .sorted {
                    $0.pozycjaDolnaYMM
                    < $1.pozycjaDolnaYMM
                }

        guard !drawers.isEmpty else {
            return bazowe
        }

        let replacesOuterFronts =
            drawers.contains {
                $0.typFrontu == .zewnetrzny
            }

        var result =
            bazowe.filter {
                !jestElementemWygenerowanym(
                    $0
                )
                && (
                    !replacesOuterFronts
                    || $0.role
                    != .front
                )
            }

        let width =
            assembly.size
                .width
                .rawValue
        let depth =
            assembly.size
                .depth
                .rawValue
        let sideClearance = 18.0
        let boxWidth =
            max(
                width
                - sideClearance * 2,
                40
            )

        for (
            index,
            drawer
        ) in drawers.enumerated() {
            let number = index + 1
            let frontHeight =
                max(
                    drawer
                        .wysokoscFrontuMM,
                    40
                )
            // boxHeight musi zmieścić się w frontHeight
            // minus 20mm dolny prześwit (prowadnica) i 4mm górny luz
            let boxHeight =
                max(
                    min(
                        drawer
                            .wysokoscSkrzynkiMM,
                        frontHeight - 24
                    ),
                    35
                )
            let drawerDepth =
                max(
                    min(
                        drawer
                            .nominalnaDlugoscMM,
                        depth - 15
                    ),
                    80
                )
            let bottomY =
                max(
                    drawer
                        .pozycjaDolnaYMM,
                    0
                )
            let profile =
                KatalogRegulAkcesoriow
                    .profil(
                        id:
                            drawer.profilID
                    )
            let frontSetback =
                SzufladyModuluEngine
                    .cofniecieOdFrontuMM(
                        dla: drawer,
                        profil: profile,
                        w: card
                    )
            let boxStartZ =
                frontSetback
                + 22

            append(
                component(
                    code:
                        "\(frontPrefix)\(number)",
                    role: .front,
                    width: width,
                    height:
                        frontHeight,
                    depth: 18,
                    x: 0,
                    y: bottomY,
                    z: frontSetback
                ),
                to: &result
            )

            append(
                component(
                    code:
                        "\(movingPrefix)BOTTOM-\(number)",
                    role: .custom,
                    width:
                        boxWidth,
                    height: 16,
                    depth:
                        drawerDepth,
                    x:
                        sideClearance,
                    y:
                        bottomY + 20,
                    z: boxStartZ
                ),
                to: &result
            )

            append(
                component(
                    code:
                        "\(movingPrefix)LEFT-\(number)",
                    role: .custom,
                    width: 16,
                    height:
                        boxHeight,
                    depth:
                        drawerDepth,
                    x:
                        sideClearance,
                    y:
                        bottomY + 20,
                    z: boxStartZ
                ),
                to: &result
            )

            append(
                component(
                    code:
                        "\(movingPrefix)RIGHT-\(number)",
                    role: .custom,
                    width: 16,
                    height:
                        boxHeight,
                    depth:
                        drawerDepth,
                    x:
                        max(
                            width
                            - sideClearance
                            - 16,
                            sideClearance
                        ),
                    y:
                        bottomY + 20,
                    z: boxStartZ
                ),
                to: &result
            )

            append(
                component(
                    code:
                        "\(movingPrefix)BACK-\(number)",
                    role: .custom,
                    width:
                        boxWidth,
                    height:
                        boxHeight,
                    depth: 16,
                    x:
                        sideClearance,
                    y:
                        bottomY + 20,
                    z:
                        max(
                            boxStartZ
                            + drawerDepth
                            - 16,
                            boxStartZ
                        )
                ),
                to: &result
            )

            for isRight in [
                false,
                true
            ] {
                append(
                    component(
                        code:
                            "\(railPrefix)\(isRight ? "R" : "L")-\(number)",
                        role: .rail,
                        width: 8,
                        height: 12,
                        depth:
                            drawerDepth,
                        x:
                            isRight
                            ? max(
                                width - 26,
                                0
                            )
                            : 18,
                        y:
                            bottomY
                            + boxHeight / 2,
                        z: boxStartZ
                    ),
                    to: &result
                )
            }
        }

        return result
    }

    private static func component(
        code: String,
        role:
            FurnitureComponentRole,
        width: Double,
        height: Double,
        depth: Double,
        x: Double,
        y: Double,
        z: Double
    ) -> FurnitureComponent? {
        try? FurnitureComponent(
            code: code,
            role: role,
            size:
                Size3MM(
                    width:
                        Millimeters(
                            max(
                                width,
                                1
                            )
                        ),
                    height:
                        Millimeters(
                            max(
                                height,
                                1
                            )
                        ),
                    depth:
                        Millimeters(
                            max(
                                depth,
                                1
                            )
                        )
                ),
            localPosition:
                Point3MM(
                    x:
                        Millimeters(
                            max(
                                x,
                                0
                            )
                        ),
                    y:
                        Millimeters(
                            max(
                                y,
                                0
                            )
                        ),
                    z:
                        Millimeters(
                            max(
                                z,
                                0
                            )
                        )
                )
        )
    }

    private static func append(
        _ component:
            FurnitureComponent?,
        to result:
            inout [FurnitureComponent]
    ) {
        guard let component else {
            return
        }

        result.append(component)
    }
}
