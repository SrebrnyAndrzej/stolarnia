import Foundation

enum TypPomiaruNietypowego:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case wneka
    case podSchodami
    case scianaLukowa
    case scianyNieprostopadle
    case kominSlup
    case wykusz
    case belkiSufitowe
    case pionInstalacyjny
    case nierownaPodloga
    case zabudowaWokolOkna
    case zabudowaWokolDrzwi
    case skosWieloplaszczyznowy

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .wneka:
            return "Wnęka"
        case .podSchodami:
            return "Zabudowa pod schodami"
        case .scianaLukowa:
            return "Ściana łukowa"
        case .scianyNieprostopadle:
            return "Ściany bez kąta 90°"
        case .kominSlup:
            return "Komin lub słup"
        case .wykusz:
            return "Wykusz"
        case .belkiSufitowe:
            return "Belki sufitowe"
        case .pionInstalacyjny:
            return "Pion instalacyjny"
        case .nierownaPodloga:
            return "Nierówna podłoga"
        case .zabudowaWokolOkna:
            return "Zabudowa wokół okna"
        case .zabudowaWokolDrzwi:
            return "Zabudowa wokół drzwi"
        case .skosWieloplaszczyznowy:
            return "Skos wielopłaszczyznowy"
        }
    }

    var systemImage: String {
        switch self {
        case .wneka:
            return "rectangle.inset.filled"
        case .podSchodami:
            return "stairs"
        case .scianaLukowa:
            return "circle.grid.cross"
        case .scianyNieprostopadle:
            return "angle"
        case .kominSlup:
            return "square.split.2x2"
        case .wykusz:
            return "hexagon"
        case .belkiSufitowe:
            return "rectangle.split.3x1"
        case .pionInstalacyjny:
            return "pipe.and.drop"
        case .nierownaPodloga:
            return "waveform.path"
        case .zabudowaWokolOkna:
            return "window.vertical.closed"
        case .zabudowaWokolDrzwi:
            return "door.left.hand.closed"
        case .skosWieloplaszczyznowy:
            return "square.3.layers.3d.down.right"
        }
    }

    var wskazowki: [String] {
        switch self {
        case .wneka:
            return [
                "Zmierz szerokość na dole, w połowie i u góry.",
                "Zmierz głębokość po lewej, środku i prawej.",
                "Sprawdź pion obu boków oraz poziom nadproża."
            ]
        case .podSchodami:
            return [
                "Zapisz wysokość co 200–300 mm.",
                "Zmierz głębokość pod każdym stopniem.",
                "Zaznacz konstrukcję schodów i strefy bez możliwości wiercenia."
            ]
        case .scianaLukowa:
            return [
                "Wyznacz linię bazową i strzałkę łuku.",
                "Zapisz punkty profilu co 200–300 mm.",
                "Sprawdź promień w kilku przekrojach wysokości."
            ]
        case .scianyNieprostopadle:
            return [
                "Zmierz obie przekątne.",
                "Zmierz odchyłkę kąta przy podłodze i suficie.",
                "Zapisz szerokość zabudowy przy froncie i przy ścianie."
            ]
        case .kominSlup:
            return [
                "Zmierz wszystkie boki słupa.",
                "Zapisz odległość słupa od dwóch stałych ścian.",
                "Sprawdź pion i ewentualne uskoki tynku."
            ]
        case .wykusz:
            return [
                "Zmierz każdy odcinek osobno.",
                "Zmierz kąty pomiędzy odcinkami.",
                "Sprawdź parapet, grzejnik i głębokość wnęk."
            ]
        case .belkiSufitowe:
            return [
                "Zmierz szerokość, wysokość i rozstaw belek.",
                "Sprawdź różnice wysokości po obu końcach.",
                "Zaznacz miejsca instalacji ukrytych w belkach."
            ]
        case .pionInstalacyjny:
            return [
                "Zmierz obrys pionu na kilku wysokościach.",
                "Zaznacz rewizję i wymagany dostęp serwisowy.",
                "Ustal strefę bez wiercenia."
            ]
        case .nierownaPodloga:
            return [
                "Wykonaj siatkę wysokości co 300–500 mm.",
                "Zapisz najwyższy i najniższy punkt.",
                "Sprawdź spadek w obu kierunkach."
            ]
        case .zabudowaWokolOkna:
            return [
                "Zmierz otwór, wnękę i parapet.",
                "Zapisz położenie klamki i zakres otwarcia.",
                "Sprawdź grzejnik, nawiewniki i dostęp do serwisu."
            ]
        case .zabudowaWokolDrzwi:
            return [
                "Zmierz ościeżnicę i opaski.",
                "Zapisz kierunek oraz zakres otwierania.",
                "Sprawdź miejsce na zawiasy i klamkę."
            ]
        case .skosWieloplaszczyznowy:
            return [
                "Wprowadź osobne punkty dla każdej płaszczyzny.",
                "Zmierz linie załamań i ich odległość od ścian.",
                "Wykonaj zdjęcia z zaznaczonymi numerami punktów."
            ]
        }
    }
}

struct PunktPomiaruNietypowego:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var xMM: Double
    var yMM: Double
    var zMM: Double
    var opis: String
}

struct PomiarNietypowy:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()

    // Opcjonalne pola zachowują zgodność ze starszymi zapisami JSON.
    var projectID: String?
    var roomID: String?
    var projectName: String?
    var roomName: String?
    var statusRawValue: String?
    var lastModified: Date?

    var typ: TypPomiaruNietypowego = .wneka
    var nazwa = "Nowy pomiar nietypowy"
    var klient = ""
    var pomieszczenie = ""
    var dataPomiaru = Date()

    var szerokoscMM = 1000.0
    var wysokoscMM = 2500.0
    var glebokoscMM = 600.0
    var katStopnie = 90.0
    var promienMM = 0.0
    var strzalkaLukuMM = 0.0

    var punkty: [PunktPomiaruNietypowego] = []
    var strefaBezWiercenia = false
    var wymaganyDostepSerwisowy = false
    var wymaganaWentylacja = false
    var wymaganaRezerwaMontazowaMM = 20.0
    var notatki = ""

    var status:
        StatusPomiaruPomieszczenia
    {
        get {
            guard let statusRawValue,
                  let value =
                    StatusPomiaruPomieszczenia(
                        rawValue:
                            statusRawValue
                    )
            else {
                return automatycznyStatus
            }

            return value
        }
        set {
            statusRawValue =
                newValue.rawValue
        }
    }

    var automatycznyStatus:
        StatusPomiaruPomieszczenia
    {
        if szerokoscMM <= 0
            || wysokoscMM <= 0 {
            return .wymagaUzupełnienia
        }

        if punkty.isEmpty
            && [
                TypPomiaruNietypowego
                    .podSchodami,
                .scianaLukowa,
                .nierownaPodloga,
                .skosWieloplaszczyznowy
            ].contains(typ) {
            return .wymagaUzupełnienia
        }

        if klient.isEmpty
            || pomieszczenie.isEmpty {
            return .rozpoczęty
        }

        return .kompletny
    }

    var minimalneX: Double? {
        punkty.map(\.xMM).min()
    }

    var maksymalneX: Double? {
        punkty.map(\.xMM).max()
    }

    var roznicaWysokosciMM: Double? {
        guard
            let minY = punkty.map(\.yMM).min(),
            let maxY = punkty.map(\.yMM).max()
        else {
            return nil
        }

        return maxY - minY
    }
}
