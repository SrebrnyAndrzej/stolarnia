import Foundation

enum StronaSkosu:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case lewa
    case prawa
    case obie
    case sufitDwuspadowy

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .lewa:
            return "Skos z lewej"
        case .prawa:
            return "Skos z prawej"
        case .obie:
            return "Skosy po obu stronach"
        case .sufitDwuspadowy:
            return "Sufit dwuspadowy"
        }
    }
}

struct PunktPomiarowySkosu:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var odlegloscOdLewejMM: Double
    var wysokoscMM: Double
    var uwagi: String

    // Pola opcjonalne zachowują zgodność ze starszym JSON-em.
    var zrodloRawValueV069: String?
    var nazwaUrzadzeniaV069: String?
    var zmierzonoAtV069: Date?
    var tolerancjaMMV069: Double?
    var potwierdzonyRawValueV069: Bool?

    var zrodloV069:
        ZrodloPomiaruSkosuV069
    {
        get {
            guard let raw =
                    zrodloRawValueV069,
                  let value =
                    ZrodloPomiaruSkosuV069(
                        rawValue: raw
                    )
            else {
                return .reczny
            }

            return value
        }
        set {
            zrodloRawValueV069 =
                newValue.rawValue
        }
    }

    var potwierdzonyV069: Bool {
        get {
            potwierdzonyRawValueV069
            ?? false
        }
        set {
            potwierdzonyRawValueV069 =
                newValue
        }
    }

    var efektywnaTolerancjaMMV069:
        Double
    {
        max(
            tolerancjaMMV069
            ?? 3,
            0
        )
    }
}

struct PrzeszkodaPomiarowa:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var nazwa: String
    var odLewejMM: Double
    var odPodlogiMM: Double
    var szerokoscMM: Double
    var wysokoscMM: Double
    var glebokoscMM: Double
    var uwagi: String
}

struct PomiarGarderobySkosy:
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

    // v0.69.0: profil jest przypisany do konkretnej ściany i ma
    // jawne źródło pomiaru. Pola są opcjonalne dla zgodności wstecznej.
    var wallIDRawValueV069: String?
    var wallNameV069: String?
    var kierunekProfiluRawValueV069: String?
    var zrodloPomiaruRawValueV069: String?
    var producentUrzadzeniaV069: String?
    var modelUrzadzeniaV069: String?
    var numerSeryjnyUrzadzeniaV069: String?
    var tolerancjaDomyslnaMMV069: Double?
    var profilZweryfikowanyRawValueV069: Bool?
    var dataWeryfikacjiV069: Date?
    var zastosujDoPomieszczeniaRawValueV069: Bool?

    // v0.69.2: metadane eksperymentalnego połączenia HOTO BLE.
    // Pola opcjonalne zachowują zgodność ze starszymi zapisami JSON.
    var blePeripheralIdentifierV0692: String?
    var bleDecoderProfileRawValueV0692: String?
    var bleLastCharacteristicUUIDV0692: String?
    var bleLastRawPacketHexV0692: String?
    var bleLastMeasurementAtV0692: Date?

    // Ręcznie wpisany kąt skosu (stopnie). Gdy ustawiony, użytkownik
    // może przeliczać punkty profilu bezpośrednio z tej wartości.
    var katRecznyStopniV069: Double?

    var nazwaPomieszczenia = "Skos pomieszczenia"
    var klient = ""
    var adres = ""
    var dataPomiaru = Date()

    var szerokoscScianyMM = 3000.0
    var wysokoscMaksymalnaMM = 2500.0
    var wysokoscSciankiKolankowejMM = 1000.0
    var glebokoscDocelowaMM = 600.0
    var odchyleniePodlogiMM = 0.0
    var odchylenieLewejScianyMM = 0.0
    var odchyleniePrawejScianyMM = 0.0

    var stronaSkosu:
        StronaSkosu = .prawa

    var punktySkosu:
        [PunktPomiarowySkosu] = [
            PunktPomiarowySkosu(
                odlegloscOdLewejMM: 0,
                wysokoscMM: 2500,
                uwagi: "Początek ściany"
            ),
            PunktPomiarowySkosu(
                odlegloscOdLewejMM: 3000,
                wysokoscMM: 1000,
                uwagi: "Ścianka kolankowa"
            )
        ]

    var przeszkody:
        [PrzeszkodaPomiarowa] = []

    var maListwyPrzypodlogowe = true
    var maGniazda = false
    var maGrzejnik = false
    var maOknoDachowe = false
    var maDrzwi = false
    var maBelki = false
    var maNierownaPodloge = false
    var maNierowneSciany = false

    var notatki = ""

    var kierunekProfiluV069:
        KierunekProfiluSkosuV069
    {
        get {
            guard let raw =
                    kierunekProfiluRawValueV069,
                  let value =
                    KierunekProfiluSkosuV069(
                        rawValue: raw
                    )
            else {
                return .wzdluzSciany
            }

            return value
        }
        set {
            kierunekProfiluRawValueV069 =
                newValue.rawValue
        }
    }

    var zrodloPomiaruV069:
        ZrodloPomiaruSkosuV069
    {
        get {
            guard let raw =
                    zrodloPomiaruRawValueV069,
                  let value =
                    ZrodloPomiaruSkosuV069(
                        rawValue: raw
                    )
            else {
                return .reczny
            }

            return value
        }
        set {
            zrodloPomiaruRawValueV069 =
                newValue.rawValue
        }
    }

    var tolerancjaDomyslnaV069:
        Double
    {
        get {
            max(
                tolerancjaDomyslnaMMV069
                ?? 3,
                0
            )
        }
        set {
            tolerancjaDomyslnaMMV069 =
                max(newValue, 0)
        }
    }

    var profilZweryfikowanyV069:
        Bool
    {
        get {
            profilZweryfikowanyRawValueV069
            ?? false
        }
        set {
            profilZweryfikowanyRawValueV069 =
                newValue
            dataWeryfikacjiV069 =
                newValue
                ? Date()
                : nil
        }
    }

    var zastosujDoPomieszczeniaV069:
        Bool
    {
        get {
            zastosujDoPomieszczeniaRawValueV069
            ?? true
        }
        set {
            zastosujDoPomieszczeniaRawValueV069 =
                newValue
        }
    }

    var opisUrzadzeniaV069: String {
        [
            producentUrzadzeniaV069,
            modelUrzadzeniaV069
        ]
        .compactMap { value in
            guard let value,
                  !value.trimmingCharacters(
                    in: .whitespacesAndNewlines
                  ).isEmpty
            else {
                return nil
            }
            return value
        }
        .joined(separator: " ")
    }

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
        if szerokoscScianyMM <= 0
            || wysokoscMaksymalnaMM <= 0
            || punktySkosu.count < 2 {
            return .wymagaUzupełnienia
        }

        if roomID != nil
            && wallIDRawValueV069 == nil {
            return .wymagaUzupełnienia
        }

        if klient.isEmpty
            || nazwaPomieszczenia.isEmpty {
            return .rozpoczęty
        }

        return .kompletny
    }

    var minimalnaWysokoscMM: Double {
        punktySkosu
            .map(\.wysokoscMM)
            .min()
            ?? wysokoscSciankiKolankowejMM
    }

    var maksymalnaWysokoscZMiarMM: Double {
        punktySkosu
            .map(\.wysokoscMM)
            .max()
            ?? wysokoscMaksymalnaMM
    }

    var przyblizonyKatSkosuStopnie: Double? {
        guard punktySkosu.count >= 2 else {
            return nil
        }

        let sorted =
            punktySkosu.sorted {
                $0.odlegloscOdLewejMM
                < $1.odlegloscOdLewejMM
            }

        guard let first = sorted.first,
              let last = sorted.last
        else {
            return nil
        }

        let run =
            abs(
                last.odlegloscOdLewejMM
                - first.odlegloscOdLewejMM
            )

        let rise =
            abs(
                last.wysokoscMM
                - first.wysokoscMM
            )

        guard run > 0 else {
            return nil
        }

        return atan2(rise, run)
            * 180
            / .pi
    }

    var ostrzezeniaPomiarowe:
        [String]
    {
        var result: [String] = []

        if roomID != nil
            && wallIDRawValueV069 == nil {
            result.append(
                "Wybierz ścianę, której dotyczy profil skosu."
            )
        }

        if tolerancjaDomyslnaV069 > 25 {
            result.append(
                "Sprawdź tolerancję pomiaru — wartość przekracza 25 mm."
            )
        }

        let sorted =
            punktySkosu.sorted {
                $0.odlegloscOdLewejMM
                < $1.odlegloscOdLewejMM
            }

        if sorted.count < 2 {
            result.append(
                "Dodaj minimum dwa punkty profilu skosu."
            )
        }

        // Span profilu zależy od kierunku: wzdłuż = szerokość ściany, w głąb = głębokość docelowa
        let spanMM: Double
        let etykietaKrawedzi: String
        let etykietaOstatni: String
        if kierunekProfiluV069 == .wGlabPomieszczenia {
            spanMM = glebokoscDocelowaMM
            etykietaKrawedzi = "Brakuje punktu przy ścianie (głębokość 0 mm)."
            etykietaOstatni  = "Ostatni punkt nie pokrywa się z docelową głębokością szafy."
        } else {
            spanMM = szerokoscScianyMM
            etykietaKrawedzi = "Brakuje punktu przy lewej krawędzi ściany."
            etykietaOstatni  = "Ostatni punkt nie pokrywa się z szerokością ściany."
        }

        if let first = sorted.first,
           first.odlegloscOdLewejMM > 5 {
            result.append(etykietaKrawedzi)
        }

        if let last = sorted.last,
           abs(last.odlegloscOdLewejMM - spanMM) > 5 {
            result.append(etykietaOstatni)
        }

        if sorted.contains(
            where: {
                $0.wysokoscMM <= 0
                || $0.odlegloscOdLewejMM < 0
            }
        ) {
            result.append(
                "Jeden z punktów ma nieprawidłowe wartości."
            )
        }

        let duplicatedDistances =
            Dictionary(
                grouping:
                    sorted.map {
                        Int(
                            $0.odlegloscOdLewejMM
                                .rounded()
                        )
                    },
                by: { $0 }
            )
            .contains {
                $0.value.count > 1
            }

        if duplicatedDistances {
            result.append(
                "Co najmniej dwa punkty mają tę samą odległość od lewej."
            )
        }

        if maOknoDachowe
            && !przeszkody.contains(
                where: {
                    $0.nazwa
                        .lowercased()
                        .contains("okno")
                }
            ) {
            result.append(
                "Zaznacz wymiary i położenie okna dachowego jako przeszkodę."
            )
        }

        if maBelki
            && !przeszkody.contains(
                where: {
                    $0.nazwa
                        .lowercased()
                        .contains("bel")
                }
            ) {
            result.append(
                "Dodaj położenie i przekrój belek."
            )
        }

        return result
    }

    var profilJestKompletny:
        Bool
    {
        ostrzezeniaPomiarowe.isEmpty
    }

    var wymaganaRezerwaMontazowaMM: Double {
        let nierownosci =
            max(
                abs(odchyleniePodlogiMM),
                abs(odchylenieLewejScianyMM),
                abs(odchyleniePrawejScianyMM)
            )

        return max(
            20,
            nierownosci + 10
        )
    }
}
