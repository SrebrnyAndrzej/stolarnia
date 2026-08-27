import DomainCore
import Foundation

enum StronaElementuTechnicznego:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case lewa
    case prawa
    case gora
    case dol
    case przod
    case tyl
    case wewnetrzna
    case zewnetrzna

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .lewa: return "Lewa"
        case .prawa: return "Prawa"
        case .gora: return "Góra"
        case .dol: return "Dół"
        case .przod: return "Przód"
        case .tyl: return "Tył"
        case .wewnetrzna: return "Wewnętrzna"
        case .zewnetrzna: return "Zewnętrzna"
        }
    }
}

enum TypPunktuWiercenia:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case prowadnica
    case zawias
    case podporaPolki
    case uchwyt
    case lacznik
    case kolkowanie
    case inny

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .prowadnica: return "Prowadnica"
        case .zawias: return "Zawias"
        case .podporaPolki: return "Podpora półki"
        case .uchwyt: return "Uchwyt"
        case .lacznik: return "Łącznik"
        case .kolkowanie: return "Kołkowanie"
        case .inny: return "Inny"
        }
    }
}

struct PunktWierceniaSzafki:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var element = ""
    var typ:
        TypPunktuWiercenia = .inny
    var strona:
        StronaElementuTechnicznego = .wewnetrzna
    var xMM = 0.0
    var yMM = 0.0
    var srednicaMM = 5.0
    var glebokoscMM = 12.0
    var opis = ""
}

enum TypLiniiWierceniaSzafki:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case osProwadnicySzuflady
    case liniaSystemu32
    case liniaPomocnicza
    case osMechanizmuNaroznego
    case kopertaRuchuMechanizmu
    case granicaMartwejStrefy

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .osProwadnicySzuflady:
            return "Oś prowadnicy szuflady"
        case .liniaSystemu32:
            return "Linia Systemu 32"
        case .liniaPomocnicza:
            return "Linia pomocnicza"
        case .osMechanizmuNaroznego:
            return "Oś mechanizmu narożnego"
        case .kopertaRuchuMechanizmu:
            return "Koperta ruchu mechanizmu"
        case .granicaMartwejStrefy:
            return "Granica martwej strefy"
        }
    }
}

struct LiniaWierceniaSzafki:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var element = ""
    var typ:
        TypLiniiWierceniaSzafki =
            .liniaPomocnicza
    var strona:
        StronaElementuTechnicznego =
            .wewnetrzna
    var xStartMM = 0.0
    var xEndMM = 0.0
    var yMM = 0.0
    var etykieta = ""
    var opis = ""
}

struct LiniaProwadnicySzufladyKartyV084:
    Identifiable,
    Hashable
{
    var id: String
    var bok: String
    var etykietaBoku: String
    var etykietaSzuflady: String
    var producent: String
    var model: String
    var statusWeryfikacji: String
    var nominalnaDlugoscMM: Double
    var xStartMM: Double
    var xEndMM: Double
    var yMM: Double
    var opis: String

    var bokSkrot: String {
        switch bok {
        case "Lewy":
            return "L"
        case "Prawy":
            return "P"
        default:
            return bok
        }
    }

    var systemSkrocony: String {
        [
            producent,
            model
        ]
        .map {
            $0.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        }
        .filter {
            !$0.isEmpty && $0 != "—"
        }
        .joined(separator: " ")
        .ifEmpty("—")
    }
}

enum KartaTechnicznaProwadniceSzufladV084 {
    static func linie(
        w card: KartaTechnicznaSzafki
    ) -> [LiniaProwadnicySzufladyKartyV084] {
        let drawersByLabel =
            card
                .efektywneSzuflady
                .reduce(
                    into:
                        [
                            String:
                                SzufladaModulu
                        ]()
                ) {
                    result,
                    drawer in

                    result[
                        drawer.etykieta
                    ] = drawer
                }

        return card
            .efektywneElementy
            .filter(jestBokiemKorpusu)
            .flatMap {
                side in

                side
                    .efektywneLinieWiercenia
                    .map {
                        line in

                        let isDrawerLine =
                            line.typ
                            == .osProwadnicySzuflady
                        let drawer =
                            isDrawerLine
                            ? drawersByLabel[
                                line.etykieta
                            ]
                            : nil
                        let profile =
                            drawer.flatMap {
                                KatalogRegulAkcesoriow
                                    .profil(
                                        id:
                                            $0.profilID
                                    )
                            }
                        let fallbackProfileID =
                            drawer?.profilID
                            ?? line.typ.nazwa
                        let model =
                            profile
                                .map {
                                    [
                                        $0.rodzina,
                                        $0.model
                                    ]
                                    .filter {
                                        !$0.isEmpty
                                    }
                                    .joined(separator: " ")
                                }
                                ?? fallbackProfileID
                        let lineLength =
                            abs(
                                line.xEndMM
                                - line.xStartMM
                            )

                        return LiniaProwadnicySzufladyKartyV084(
                            id:
                                "\(side.id.uuidString)|\(line.id.uuidString)",
                            bok:
                                bok(
                                    dla: side
                                ),
                            etykietaBoku:
                                side.etykieta
                                    .ifEmpty(
                                        side.nazwa
                                    ),
                            etykietaSzuflady:
                                line.etykieta
                                    .ifEmpty("—"),
                            producent:
                                profile?
                                    .producent
                                ?? (
                                    isDrawerLine
                                    ? "—"
                                    : "Linia"
                                ),
                            model:
                                model.ifEmpty(
                                    line.typ.nazwa
                                ),
                            statusWeryfikacji:
                                profile?
                                    .status
                                    .nazwa
                                ?? (
                                    isDrawerLine
                                    ? "Brak profilu"
                                    : "Pomocnicza"
                                ),
                            nominalnaDlugoscMM:
                                drawer?
                                    .nominalnaDlugoscMM
                                ?? lineLength,
                            xStartMM:
                                min(
                                    line.xStartMM,
                                    line.xEndMM
                                ),
                            xEndMM:
                                max(
                                    line.xStartMM,
                                    line.xEndMM
                                ),
                            yMM:
                                line.yMM,
                            opis:
                                line.opis
                        )
                    }
            }
            .sorted {
                lhs,
                rhs in

                if abs(lhs.yMM - rhs.yMM) > 0.01 {
                    return lhs.yMM < rhs.yMM
                }

                if lhs.etykietaSzuflady
                    != rhs.etykietaSzuflady {
                    return lhs.etykietaSzuflady
                        < rhs.etykietaSzuflady
                }

                return lhs.bok < rhs.bok
            }
    }

    private static func jestBokiemKorpusu(
        _ element: ElementTechnicznySzafki
    ) -> Bool {
        element.typ == .scianaBoczna
            || element.typ == .sciankaMaskujaca
    }

    private static func bok(
        dla element: ElementTechnicznySzafki
    ) -> String {
        let text =
            [
                element.etykieta,
                element.nazwa
            ]
            .joined(separator: " ")

        if text.localizedCaseInsensitiveContains(
            "lew"
        ) {
            return "Lewy"
        }

        if text.localizedCaseInsensitiveContains(
            "praw"
        ) {
            return "Prawy"
        }

        return element
            .etykieta
            .ifEmpty(element.nazwa)
            .ifEmpty("Bok")
    }
}

private extension String {
    func ifEmpty(
        _ replacement: String
    ) -> String {
        trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        .isEmpty
            ? replacement
            : self
    }
}

struct ZamkniecieBrylySzafki:
    Codable,
    Hashable
{
    var blendaLewa = false
    var szerokoscBlendyLewejMM = 50.0

    var blendaPrawa = false
    var szerokoscBlendyPrawejMM = 50.0

    var wieniecGorny = false
    var gruboscWiencaGornegoMM = 18.0
    var wysuniecieWiencaGornegoMM = 20.0

    var wieniecDolny = false
    var gruboscWiencaDolnegoMM = 18.0
    var wysuniecieWiencaDolnegoMM = 20.0

    var sciankaBocznaLewa = false
    var sciankaBocznaPrawa = false

    /// Domyślnie 20 mm, czyli 2 cm przed płaszczyznę frontu.
    var wysuniecieScianekPrzedFrontMM = 20.0
    var gruboscScianekMM = 18.0

    var posiadaElementyZamykajace:
        Bool
    {
        blendaLewa
        || blendaPrawa
        || wieniecGorny
        || wieniecDolny
        || sciankaBocznaLewa
        || sciankaBocznaPrawa
    }
}


enum TypElementuSzafki:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case scianaBoczna = "SB"
    case dno = "DN"
    case wieniecGorny = "WG"
    case wieniecDolny = "WD"
    case polka = "PL"
    case plecy = "PC"
    case front = "FR"
    case blenda = "BL"
    case sciankaMaskujaca = "SM"
    case cokół = "CK"
    case listwa = "LS"
    case przegroda = "PR"
    case szuflada = "SZ"
    case inny = "IN"

    var id: String { rawValue }

    var kod: String { rawValue }

    var nazwa: String {
        switch self {
        case .scianaBoczna:
            return "Ściana boczna"
        case .dno:
            return "Dno"
        case .wieniecGorny:
            return "Wieniec górny"
        case .wieniecDolny:
            return "Wieniec dolny"
        case .polka:
            return "Półka"
        case .plecy:
            return "Plecy"
        case .front:
            return "Front"
        case .blenda:
            return "Blenda"
        case .sciankaMaskujaca:
            return "Ścianka maskująca"
        case .cokół:
            return "Cokół"
        case .listwa:
            return "Listwa"
        case .przegroda:
            return "Przegroda"
        case .szuflada:
            return "Szuflada"
        case .inny:
            return "Inny"
        }
    }
}

enum KierunekElementuSzafki:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case pionowy
    case poziomy
    case bezZnaczenia

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .pionowy:
            return "Pionowy"
        case .poziomy:
            return "Poziomy"
        case .bezZnaczenia:
            return "Bez znaczenia"
        }
    }
}

struct ElementTechnicznySzafki:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var etykieta = ""
    var typ:
        TypElementuSzafki = .inny
    var nazwa = ""
    var dlugoscMM = 0.0
    var szerokoscMM = 0.0
    var gruboscMM = 18.0
    var ilosc = 1
    var material = ""

    // Stabilne powiązanie z rekordem w Bazie materiałów.
    // Pole opcjonalne zachowuje odczyt starszych kart.
    var materialID: UUID? = nil

    var kierunek:
        KierunekElementuSzafki =
            .bezZnaczenia
    var uwagi = ""
    var punktyWiercenia:
        [PunktWierceniaSzafki] = []

    // v0.84: produkcyjne linie wierceń/montażu, np. oś prowadnicy
    // szuflady Amix/GTV na bokach korpusu. Opcjonalne dla zgodności
    // z kartami zapisanymi przed dodaniem tej warstwy.
    var linieWierceniaV084:
        [LiniaWierceniaSzafki]? = nil

    var efektywneLinieWiercenia:
        [LiniaWierceniaSzafki]
    {
        get {
            linieWierceniaV084 ?? []
        }
        set {
            linieWierceniaV084 = newValue
        }
    }

    var parametrySystemu32:
        ParametrySystemu32?

    // v0.69.1: cut angle at the top edge when cabinet is under a slope.
    // Nil means the element is rectangular (no slope cut required).
    var katCieciaGornejKrawedziStopnieV0691: Double? = nil

    // For fronts/backs under a slope the outline is non-rectangular.
    // Stored in local element coordinates: (0,0) = bottom-left corner.
    var konturSkosuV0691: [PunktKonturuPaneluV0691]? = nil

    var jestScietySkosemV0691: Bool {
        katCieciaGornejKrawedziStopnieV0691 != nil
        || konturSkosuV0691 != nil
    }
}

struct NarożnikTechnicznyKartyV086:
    Codable,
    Hashable
{
    var kind:
        CornerCabinetKindV025
    var handedness:
        CornerCabinetHandednessV025
    var accessTechnology:
        CornerCabinetAccessTechnologyV085
    var fillerKind:
        CornerCabinetFillerKindV086
    var primaryWallSpanMM: Double
    var secondaryWallSpanMM: Double
    var depthMM: Double
    var frontOpeningMM: Double
    var deadZoneMM: Double
    var frontAngleDegrees: Double
    var fillerWidthMM: Double
    var clearHeightMM: Double
    var handleProjectionMM: Double
    var requiresMotionEnvelopeCheck: Bool
    var requiresOpeningAngleLimiter: Bool
    var requiresManufacturerTemplate: Bool
    var productionNotes:
        [String]

    init(
        footprint:
            CornerCabinetFootprintV085
    ) {
        kind =
            footprint.kind
        handedness =
            footprint.handedness
        accessTechnology =
            footprint.accessTechnology
        fillerKind =
            footprint.fillerKind
        primaryWallSpanMM =
            footprint.primaryWallSpanMM
        secondaryWallSpanMM =
            footprint.secondaryWallSpanMM
        depthMM =
            footprint.depthMM
        frontOpeningMM =
            footprint.frontOpeningMM
        deadZoneMM =
            footprint.deadZoneMM
        frontAngleDegrees =
            footprint.frontAngleDegrees
        fillerWidthMM =
            footprint.fillerWidthMM
        clearHeightMM =
            footprint.clearHeightMM
        handleProjectionMM =
            footprint.handleProjectionMM
        requiresMotionEnvelopeCheck =
            footprint
                .technologyRule
                .requiresMotionEnvelopeCheck
        requiresOpeningAngleLimiter =
            footprint
                .technologyRule
                .requiresOpeningAngleLimiter
        requiresManufacturerTemplate =
            footprint
                .technologyRule
                .requiresManufacturerTemplate
        productionNotes =
            footprint.productionNotes
    }

    var shouldShowDeadZone:
        Bool
    {
        deadZoneMM > 0
            && (
                kind == .blindCorner
                || kind == .halfBlind
            )
    }
}

struct KartaTechnicznaSzafki:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var draftID: UUID
    var numerSzafki = ""
    var nazwa = ""
    var szerokoscMM = 0.0
    var wysokoscMM = 0.0
    var glebokoscMM = 0.0
    var rodzajKonstrukcji = ""
    var materialKorpusu = ""
    var materialFrontu = ""
    var liczbaSegmentow = 1
    var punktyWiercenia:
        [PunktWierceniaSzafki] = []
    var uwagi = ""
    var dataAktualizacji = Date()

    // v0.54.0: karta należy do konkretnej instancji mebla, a nie tylko
    // do pary „kod szablonu + nazwa”. Pola opcjonalne zachowują pełną
    // zgodność z kartami utworzonymi we wcześniejszych wersjach.
    var kluczModulu: String? = nil
    var materialKorpusuID: UUID? = nil
    var materialFrontuID: UUID? = nil
    var wersjaSchematu: Int? = nil

    // v0.68.0: jedno źródło prawdy dla frontów, kierunku otwierania
    // oraz systemu szuflad. Pole opcjonalne zachowuje odczyt starszych kart.
    var konfiguracjaFunkcjonalnaV068:
        KonfiguracjaFunkcjonalnaModuluV068? = nil

    // v0.69.1: produkcyjny kontur paneli wynikający z profilu skosu.
    // Pole opcjonalne zachowuje odczyt wszystkich kart sprzed tej wersji.
    var raportPaneliSkosuV0691:
        RaportPaneliSkosuV0691? = nil

    // v0.80: wnęki specjalne dla customCarcass (np. iRobot).
    // Pole opcjonalne zachowuje odczyt kart sprzed tej wersji.
    var wnekiSpecjalneV080: [WnekaSpecjalnaV080]? = nil

    // v0.86: rzut i reguły produkcyjne szafek narożnych.
    /// Po której stronie wisi front uchylny tej szafki.
    ///
    /// Potrzebne do **asymetrycznego** odsunięcia szuflad za frontem: front
    /// zostaje w świetle tylko po stronie zawiasu. Do 2026-08-27 ta informacja
    /// nie wychodziła poza edytor elewacji, więc silnik odsuwał skrzynkę po
    /// obu stronach.
    ///
    /// `nil` znaczy „nieznana" — wtedy odsunięcie zostaje symetryczne.
    /// Zgadywanie strony byłoby gorsze niż jej brak: skrzynka wyszłaby
    /// odsunięta w złą stronę i nie zmieściłaby się przy zawiasie.
    var stronaZawiasuV0104: FurnitureFrontOpeningV020?

    var narożnikTechnicznyV086:
        NarożnikTechnicznyKartyV086? = nil

    var wneki: [WnekaSpecjalnaV080] {
        wnekiSpecjalneV080 ?? []
    }

    var efektywnaKonfiguracjaFunkcjonalnaV068:
        KonfiguracjaFunkcjonalnaModuluV068
    {
        get {
            konfiguracjaFunkcjonalnaV068
            ?? KonfiguracjaFunkcjonalnaModuluV068()
        }
        set {
            konfiguracjaFunkcjonalnaV068 =
                newValue
        }
    }

    // Pola opcjonalne zachowują odczyt kart zapisanych w v0.45.0.
    var kodSzablonuZrodlowego:
        String?
    var jestGotowymModulem:
        Bool?
    var liczbaPolek:
        Int?
    var zamkniecieBryly:
        ZamkniecieBrylySzafki?
    var elementy:
        [ElementTechnicznySzafki]?
    var akcesoria:
        [InstancjaAkcesoriumSzafki]?
    var szuflady:
        [SzufladaModulu]?

    var efektywneSzuflady:
        [SzufladaModulu]
    {
        get {
            szuflady ?? []
        }
        set {
            szuflady = newValue
        }
    }

    var efektywneAkcesoria:
        [InstancjaAkcesoriumSzafki]
    {
        get {
            akcesoria ?? []
        }
        set {
            akcesoria = newValue
        }
    }

    var efektywneElementy:
        [ElementTechnicznySzafki]
    {
        get {
            elementy ?? []
        }
        set {
            elementy = newValue
        }
    }

    var efektywneZamkniecieBryly:
        ZamkniecieBrylySzafki
    {
        get {
            zamkniecieBryly
            ?? ZamkniecieBrylySzafki()
        }
        set {
            zamkniecieBryly = newValue
        }
    }
}
