import Foundation

// MARK: - Seria / klasa systemu Bonari

/// Klasy systemów Bonari zgodnie z katalogiem producenta.
///
/// Każda klasa definiuje nośność jednego skrzydła, maksymalne wymiary
/// oraz typ profilu prowadnicy górnej / dolnej.
enum SeriaBonari:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case bl40           // lekki, standard do szaf
    case bl60           // standard plus — najpopularniejszy
    case bl80           // ciężki (lustra, szkła)
    case bl100          // super heavy — szkło hartowane
    case partition40    // ścianka dzieląca lekka
    case partition80    // ścianka dzieląca ciężka (szkło)

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .bl40:         return "Bonari BL-40"
        case .bl60:         return "Bonari BL-60"
        case .bl80:         return "Bonari BL-80"
        case .bl100:        return "Bonari BL-100"
        case .partition40:  return "Bonari Partition 40"
        case .partition80:  return "Bonari Partition 80"
        }
    }

    var opis: String {
        switch self {
        case .bl40:
            return "System lekki, do płyt laminowanych, maks. 40 kg/skrzydło"
        case .bl60:
            return "System standardowy, do płyt i luster, maks. 60 kg/skrzydło"
        case .bl80:
            return "System ciężki, do luster i szkła, maks. 80 kg/skrzydło"
        case .bl100:
            return "System super heavy, szkło hartowane, maks. 100 kg/skrzydło"
        case .partition40:
            return "Ścianka dzieląca na prowadnicach sufitowych, do 40 kg/panel"
        case .partition80:
            return "Ścianka dzieląca szklana, do 80 kg/panel"
        }
    }

    var jestSciankaPodziałowa: Bool {
        self == .partition40 || self == .partition80
    }

    var profil: ProfilBonari {
        ProfilBonari.profil(dla: self)
    }
}

// MARK: - Profil techniczny Bonari

struct ProfilBonari:
    Codable,
    Hashable
{
    // Identyfikacja
    var seria: SeriaBonari
    var kodProfilu: String          // np. "BL-60-ALU-S"

    // Wymiary prowadnicy [mm]
    var wysokoscProwadnicyGornejMM: Double
    var wysokoscPrzewodnicyDolnejMM: Double  // 0 jeśli system górnozawieszony
    var szerokoscProwadnicyMM: Double        // szerokość listwy (dla 1 toru)
    var liczbaTorów: Int                     // tory w jednej prowadnicy

    // Limity skrzydła
    var maxNosnosc_kg: Double
    var minSzerokoscSkrzydlaMM: Double
    var maxSzerokoscSkrzydlaMM: Double
    var minWysokoscSkrzydlaMM: Double
    var maxWysokoscSkrzydlaMM: Double

    // Grubości drzwi [mm]
    var gruboscDrzwiDostepne: [Double]      // np. [16, 18, 20, 22, 25]

    // Zachód między skrzydłami [mm]
    var zachodMinMM: Double
    var zachodMaksymalnyMM: Double
    var zachodZalecanyMM: Double

    // Luz montażowy [mm]
    var clearanceMM: Double

    // Materiały wykończenia
    var materialyProfilu: [MaterialProfilu]

    // MARK: Fabryka

    static func profil(dla seria: SeriaBonari) -> ProfilBonari {
        switch seria {
        case .bl40:
            return ProfilBonari(
                seria: .bl40,
                kodProfilu: "BL-40-ALU",
                wysokoscProwadnicyGornejMM: 30,
                wysokoscPrzewodnicyDolnejMM: 10,
                szerokoscProwadnicyMM: 20,
                liczbaTorów: 2,
                maxNosnosc_kg: 40,
                minSzerokoscSkrzydlaMM: 450,
                maxSzerokoscSkrzydlaMM: 900,
                minWysokoscSkrzydlaMM: 1200,
                maxWysokoscSkrzydlaMM: 2600,
                gruboscDrzwiDostepne: [16, 18],
                zachodMinMM: 40,
                zachodMaksymalnyMM: 80,
                zachodZalecanyMM: 55,
                clearanceMM: 3,
                materialyProfilu: MaterialProfilu.standardowe
            )

        case .bl60:
            return ProfilBonari(
                seria: .bl60,
                kodProfilu: "BL-60-ALU",
                wysokoscProwadnicyGornejMM: 35,
                wysokoscPrzewodnicyDolnejMM: 12,
                szerokoscProwadnicyMM: 24,
                liczbaTorów: 2,
                maxNosnosc_kg: 60,
                minSzerokoscSkrzydlaMM: 450,
                maxSzerokoscSkrzydlaMM: 1050,
                minWysokoscSkrzydlaMM: 1200,
                maxWysokoscSkrzydlaMM: 2800,
                gruboscDrzwiDostepne: [16, 18, 20, 22],
                zachodMinMM: 50,
                zachodMaksymalnyMM: 80,
                zachodZalecanyMM: 60,
                clearanceMM: 3,
                materialyProfilu: MaterialProfilu.pelny
            )

        case .bl80:
            return ProfilBonari(
                seria: .bl80,
                kodProfilu: "BL-80-ALU",
                wysokoscProwadnicyGornejMM: 40,
                wysokoscPrzewodnicyDolnejMM: 15,
                szerokoscProwadnicyMM: 28,
                liczbaTorów: 2,
                maxNosnosc_kg: 80,
                minSzerokoscSkrzydlaMM: 450,
                maxSzerokoscSkrzydlaMM: 1150,
                minWysokoscSkrzydlaMM: 1200,
                maxWysokoscSkrzydlaMM: 3000,
                gruboscDrzwiDostepne: [18, 20, 22, 25],
                zachodMinMM: 55,
                zachodMaksymalnyMM: 90,
                zachodZalecanyMM: 65,
                clearanceMM: 3,
                materialyProfilu: MaterialProfilu.pelny
            )

        case .bl100:
            return ProfilBonari(
                seria: .bl100,
                kodProfilu: "BL-100-ALU",
                wysokoscProwadnicyGornejMM: 45,
                wysokoscPrzewodnicyDolnejMM: 18,
                szerokoscProwadnicyMM: 32,
                liczbaTorów: 2,
                maxNosnosc_kg: 100,
                minSzerokoscSkrzydlaMM: 500,
                maxSzerokoscSkrzydlaMM: 1200,
                minWysokoscSkrzydlaMM: 1500,
                maxWysokoscSkrzydlaMM: 3000,
                gruboscDrzwiDostepne: [20, 22, 25],
                zachodMinMM: 60,
                zachodMaksymalnyMM: 100,
                zachodZalecanyMM: 70,
                clearanceMM: 3,
                materialyProfilu: MaterialProfilu.premium
            )

        case .partition40:
            return ProfilBonari(
                seria: .partition40,
                kodProfilu: "BP-40-ALU",
                wysokoscProwadnicyGornejMM: 50,
                wysokoscPrzewodnicyDolnejMM: 0,  // górnozawieszony
                szerokoscProwadnicyMM: 32,
                liczbaTorów: 2,
                maxNosnosc_kg: 40,
                minSzerokoscSkrzydlaMM: 500,
                maxSzerokoscSkrzydlaMM: 1000,
                minWysokoscSkrzydlaMM: 1800,
                maxWysokoscSkrzydlaMM: 2800,
                gruboscDrzwiDostepne: [16, 18, 20],
                zachodMinMM: 50,
                zachodMaksymalnyMM: 80,
                zachodZalecanyMM: 60,
                clearanceMM: 5,
                materialyProfilu: MaterialProfilu.pelny
            )

        case .partition80:
            return ProfilBonari(
                seria: .partition80,
                kodProfilu: "BP-80-ALU",
                wysokoscProwadnicyGornejMM: 60,
                wysokoscPrzewodnicyDolnejMM: 0,  // górnozawieszony
                szerokoscProwadnicyMM: 38,
                liczbaTorów: 2,
                maxNosnosc_kg: 80,
                minSzerokoscSkrzydlaMM: 500,
                maxSzerokoscSkrzydlaMM: 1200,
                minWysokoscSkrzydlaMM: 2000,
                maxWysokoscSkrzydlaMM: 3200,
                gruboscDrzwiDostepne: [20, 22, 25],
                zachodMinMM: 60,
                zachodMaksymalnyMM: 100,
                zachodZalecanyMM: 70,
                clearanceMM: 5,
                materialyProfilu: MaterialProfilu.premium
            )
        }
    }

    // MARK: Walidacja wymiarów

    struct WynikWalidacji {
        var szerokoscOK: Bool
        var wysokoscOK: Bool
        var wagaOK: Bool
        var ostrzezenia: [String]

        var jestOK: Bool {
            szerokoscOK && wysokoscOK && wagaOK
        }
    }

    func waliduj(
        szerokoscSkrzydlaMM: Double,
        wysokoscSkrzydlaMM: Double,
        wagaKg: Double
    ) -> WynikWalidacji {
        var ostrzezenia: [String] = []

        let szerokoscOK = szerokoscSkrzydlaMM >= minSzerokoscSkrzydlaMM
            && szerokoscSkrzydlaMM <= maxSzerokoscSkrzydlaMM
        if !szerokoscOK {
            ostrzezenia.append(
                "Szerokość skrzydła \(Int(szerokoscSkrzydlaMM)) mm poza zakresem \(Int(minSzerokoscSkrzydlaMM))–\(Int(maxSzerokoscSkrzydlaMM)) mm dla \(seria.nazwa)."
            )
        }

        let wysokoscOK = wysokoscSkrzydlaMM >= minWysokoscSkrzydlaMM
            && wysokoscSkrzydlaMM <= maxWysokoscSkrzydlaMM
        if !wysokoscOK {
            ostrzezenia.append(
                "Wysokość skrzydła \(Int(wysokoscSkrzydlaMM)) mm poza zakresem \(Int(minWysokoscSkrzydlaMM))–\(Int(maxWysokoscSkrzydlaMM)) mm dla \(seria.nazwa)."
            )
        }

        let wagaOK = wagaKg <= maxNosnosc_kg
        if !wagaOK {
            ostrzezenia.append(
                "Waga \(String(format: "%.1f", wagaKg)) kg przekracza nośność \(seria.nazwa) (\(Int(maxNosnosc_kg)) kg/skrzydło)."
            )
        }

        return WynikWalidacji(
            szerokoscOK: szerokoscOK,
            wysokoscOK: wysokoscOK,
            wagaOK: wagaOK,
            ostrzezenia: ostrzezenia
        )
    }
}

// MARK: - Materiał wykończenia profilu

struct MaterialProfilu:
    Codable,
    Hashable,
    Identifiable
{
    var id: String
    var nazwa: String
    var kolorHEX: String
    var opis: String

    static let standardowe: [MaterialProfilu] = [
        MaterialProfilu(id: "ALU-SILVER", nazwa: "Aluminium srebrne", kolorHEX: "#C0C0C0", opis: "Anodowane, standardowe"),
        MaterialProfilu(id: "ALU-BLACK", nazwa: "Czarne matowe", kolorHEX: "#1A1A1A", opis: "Malowane proszkowo RAL 9005"),
        MaterialProfilu(id: "ALU-WHITE", nazwa: "Białe matowe", kolorHEX: "#F5F5F5", opis: "Malowane proszkowo RAL 9003"),
    ]

    static let pelny: [MaterialProfilu] = standardowe + [
        MaterialProfilu(id: "ALU-GOLD", nazwa: "Złote", kolorHEX: "#D4A843", opis: "Anodowane złoto szampańskie"),
        MaterialProfilu(id: "ALU-GRAPHITE", nazwa: "Grafitowe", kolorHEX: "#3C3C3C", opis: "Malowane proszkowo RAL 9011"),
        MaterialProfilu(id: "ALU-INOX", nazwa: "Inox (szczotkowane)", kolorHEX: "#9E9E9E", opis: "Szczotkowane, efekt stali"),
    ]

    static let premium: [MaterialProfilu] = pelny + [
        MaterialProfilu(id: "ALU-BRASS", nazwa: "Mosiądz szczotkowany", kolorHEX: "#B5892A", opis: "Efekt mosiądzu"),
        MaterialProfilu(id: "ALU-BRONZE", nazwa: "Brąz szczotkowany", kolorHEX: "#8B6914", opis: "Efekt brązu"),
        MaterialProfilu(id: "ALU-ROSE", nazwa: "Rose gold", kolorHEX: "#C9796A", opis: "Rose gold anodowane"),
    ]
}

// MARK: - Katalog wypełnień drzwi Bonari

struct WypelnienieDrzwiBonari:
    Codable,
    Hashable,
    Identifiable
{
    var id: String
    var nazwa: String
    var konstrukcja: KonstrukcjaDrzwiPrzesuwnychV075
    var gruboscMM: Double
    var wagaKgM2: Double
    var maxSzerokoscMM: Double      // ograniczenie materiałowe (np. tafla szkła)
    var maxWysokoscMM: Double
    var kodKoloru: String?
    var kolorHEX: String
    var opis: String
}

enum BonariKatalog {

    // MARK: Zalecane systemy do szaf

    /// Dobiera optymalną serię Bonari dla podanych wymiarów i konstrukcji drzwi.
    static func rekomendowanaSeria(
        szerokoscSkrzydlaMM: Double,
        wysokoscSkrzydlaMM: Double,
        konstrukcja: KonstrukcjaDrzwiPrzesuwnychV075
    ) -> SeriaBonari {
        let waga = szerokoscSkrzydlaMM / 1000
            * wysokoscSkrzydlaMM / 1000
            * konstrukcja.wagaKgM2

        switch (waga, wysokoscSkrzydlaMM) {
        case (_, _) where waga > 80 || szerokoscSkrzydlaMM > 1150:
            return .bl100
        case (_, _) where waga > 60 || szerokoscSkrzydlaMM > 1050:
            return .bl80
        case (_, _) where waga > 40 || wysokoscSkrzydlaMM > 2600:
            return .bl60
        default:
            return .bl40
        }
    }

    // MARK: Najpopularniejsze szerokości skrzydeł w Polsce

    /// Lista standardowych szerokości skrzydeł stosowanych przez polskich stolarzy.
    /// Posortowana od najczęściej używanych.
    static let standardoweSzerokosci: [(szerokoscMM: Double, popularnosc: String)] = [
        (800, "★★★★★"),   // najpopularniejsza
        (750, "★★★★☆"),   // bardzo popularna
        (700, "★★★★☆"),
        (900, "★★★☆☆"),
        (850, "★★★☆☆"),
        (600, "★★☆☆☆"),   // małe szafy
        (950, "★★☆☆☆"),
        (1000, "★★☆☆☆"),
        (650, "★★☆☆☆"),
        (1050, "★☆☆☆☆"),  // rzadka
        (1100, "★☆☆☆☆"),
        (1200, "★☆☆☆☆"),
    ]

    /// Optymalna strefa szerokości skrzydła [mm] — gdzie skrzydło wygląda proporcjonalnie.
    static let strefaOptymalnaMM: ClosedRange<Double> = 700...950

    /// Strefa akceptowalna (funkcjonalna, ale może być zbyt wąska lub szeroka).
    static let strefaAkceptowalnaMM: ClosedRange<Double> = 500...1100

    // MARK: Auto-dobór liczby drzwi

    struct WynikAutoDoboruDrzwi {
        var liczbaDrzwi: Int
        var szerokoscSkrzydlaMM: Double
        var zachodMM: Double
        var seria: SeriaBonari
        var ocena: String           // "optimal", "acceptable", "warning"
        var komunikat: String
    }

    /// Dobiera optymalną liczbę drzwi dla podanej szerokości szafy/ścianki.
    ///
    /// Logika:
    /// 1. Przetestuj N = 2, 3, 4
    /// 2. Oblicz szerokość skrzydła dla każdego N
    /// 3. Wybierz N, dla którego skrzydło leży najbliżej środka strefy optymalnej (750-850mm)
    /// 4. Jeśli remis → mniej drzwi
    static func autoDoborDrzwi(
        szerokoscCalkowitaMM: Double,
        wysokoscCalkowitaMM: Double,
        konstrukcja: KonstrukcjaDrzwiPrzesuwnychV075,
        preferowanaStrefa: ClosedRange<Double> = strefaOptymalnaMM
    ) -> WynikAutoDoboruDrzwi {

        let kandydaci: [Int] = [2, 3, 4]
        let target = (preferowanaStrefa.lowerBound + preferowanaStrefa.upperBound) / 2

        var najlepszy: (n: Int, szerokosc: Double, odleglosc: Double, zachod: Double)?

        for n in kandydaci {
            // Szacowany zachód: zależy od liczby drzwi i docelowej serii
            let szacSeria = SeriaBonari.bl60  // estimate
            let zachod = szacSeria.profil.zachodZalecanyMM

            let szerokosc = (szerokoscCalkowitaMM + Double(n - 1) * zachod) / Double(n)
            let odlegloscOdTargetu = abs(szerokosc - target)

            if let current = najlepszy {
                // Wybierz kandydata bliższego środkowi strefy
                // Przy równej odległości: mniej drzwi (prostsze)
                if odlegloscOdTargetu < current.odleglosc {
                    najlepszy = (n, szerokosc, odlegloscOdTargetu, zachod)
                }
            } else {
                najlepszy = (n, szerokosc, odlegloscOdTargetu, zachod)
            }
        }

        let wynik = najlepszy ?? (2, szerokoscCalkowitaMM / 2, 0, 60)
        // Estymata BL-60 do wyliczenia wysokości skrzydła (dokładna seria nieznana w tej chwili)
        let estGorna = SeriaBonari.bl60.profil.wysokoscProwadnicyGornejMM
        let estDolna = SeriaBonari.bl60.profil.wysokoscPrzewodnicyDolnejMM
        let seria = rekomendowanaSeria(
            szerokoscSkrzydlaMM: wynik.szerokosc,
            wysokoscSkrzydlaMM: wysokoscCalkowitaMM - estGorna - estDolna,
            konstrukcja: konstrukcja
        )

        let ocena: String
        let komunikat: String

        if preferowanaStrefa.contains(wynik.szerokosc) {
            ocena = "optimal"
            komunikat = "\(wynik.n) drzwi × \(Int(wynik.szerokosc.rounded())) mm — strefa optymalna"
        } else if strefaAkceptowalnaMM.contains(wynik.szerokosc) {
            ocena = "acceptable"
            komunikat = "\(wynik.n) drzwi × \(Int(wynik.szerokosc.rounded())) mm — akceptowalne, ale poza strefą optymalną"
        } else {
            ocena = "warning"
            komunikat = "\(wynik.n) drzwi × \(Int(wynik.szerokosc.rounded())) mm — skrzydło poza dopuszczalnymi granicami, zmień liczbę drzwi ręcznie"
        }

        return WynikAutoDoboruDrzwi(
            liczbaDrzwi: wynik.n,
            szerokoscSkrzydlaMM: wynik.szerokosc,
            zachodMM: wynik.zachod,
            seria: seria,
            ocena: ocena,
            komunikat: komunikat
        )
    }

    // MARK: Wypełnienia drzwi

    static let wypelnienia: [WypelnienieDrzwiBonari] = [
        // Płyty
        WypelnienieDrzwiBonari(
            id: "PLYTA-WHITE-MATT", nazwa: "Płyta biała mat",
            konstrukcja: .plytaLaminowana, gruboscMM: 18, wagaKgM2: 8.5,
            maxSzerokoscMM: 1200, maxWysokoscMM: 3000,
            kodKoloru: "W980 ST2", kolorHEX: "#F0EEE9", opis: "Egger W980 ST2 Biały laminat mat"
        ),
        WypelnienieDrzwiBonari(
            id: "PLYTA-WHITE-GLOSS", nazwa: "Płyta biała połysk",
            konstrukcja: .plytaLaminowana, gruboscMM: 18, wagaKgM2: 8.5,
            maxSzerokoscMM: 1200, maxWysokoscMM: 3000,
            kodKoloru: "W1000 ST9", kolorHEX: "#FAFAFA", opis: "Egger W1000 ST9 Biały połysk"
        ),
        WypelnienieDrzwiBonari(
            id: "PLYTA-CASHMERE", nazwa: "Płyta kaszmir",
            konstrukcja: .plytaLaminowana, gruboscMM: 18, wagaKgM2: 8.5,
            maxSzerokoscMM: 1200, maxWysokoscMM: 3000,
            kodKoloru: "W1000 ST9", kolorHEX: "#C4B89A", opis: "Kaszmir mat laminowany"
        ),
        WypelnienieDrzwiBonari(
            id: "PLYTA-ANTHRACITE", nazwa: "Płyta antracyt",
            konstrukcja: .plytaLaminowana, gruboscMM: 18, wagaKgM2: 8.5,
            maxSzerokoscMM: 1200, maxWysokoscMM: 3000,
            kodKoloru: "U961 ST2", kolorHEX: "#383839", opis: "Egger U961 Antracyt mat"
        ),
        WypelnienieDrzwiBonari(
            id: "PLYTA-OAK", nazwa: "Płyta dąb naturalny",
            konstrukcja: .plytaLaminowana, gruboscMM: 18, wagaKgM2: 8.5,
            maxSzerokoscMM: 1200, maxWysokoscMM: 3000,
            kodKoloru: "H3331 ST10", kolorHEX: "#A07D4A", opis: "Egger H3331 Dąb naturalny"
        ),
        // Lustra
        WypelnienieDrzwiBonari(
            id: "LUSTRO-CLEAR", nazwa: "Lustro srebrne",
            konstrukcja: .lustro, gruboscMM: 4, wagaKgM2: 10.0,
            maxSzerokoscMM: 1100, maxWysokoscMM: 2800,
            kodKoloru: nil, kolorHEX: "#D8D8E8", opis: "Lustro float 4mm, srebrne"
        ),
        WypelnienieDrzwiBonari(
            id: "LUSTRO-BRONZE", nazwa: "Lustro brązowe",
            konstrukcja: .lustro, gruboscMM: 4, wagaKgM2: 10.0,
            maxSzerokoscMM: 1100, maxWysokoscMM: 2800,
            kodKoloru: nil, kolorHEX: "#9B7D5A", opis: "Lustro brązowe 4mm"
        ),
        WypelnienieDrzwiBonari(
            id: "LUSTRO-SMOKED", nazwa: "Lustro dymne",
            konstrukcja: .lustro, gruboscMM: 4, wagaKgM2: 10.0,
            maxSzerokoscMM: 1100, maxWysokoscMM: 2800,
            kodKoloru: nil, kolorHEX: "#4A4A4A", opis: "Lustro dymne 4mm"
        ),
        // Szkło i Lacobel
        WypelnienieDrzwiBonari(
            id: "LACOBEL-WHITE", nazwa: "Lacobel biały",
            konstrukcja: .lacobel, gruboscMM: 6, wagaKgM2: 15.0,
            maxSzerokoscMM: 1000, maxWysokoscMM: 2600,
            kodKoloru: "9003", kolorHEX: "#F5F5F5", opis: "Szkło lakierowane białe 6mm"
        ),
        WypelnienieDrzwiBonari(
            id: "LACOBEL-BLACK", nazwa: "Lacobel czarny",
            konstrukcja: .lacobel, gruboscMM: 6, wagaKgM2: 15.0,
            maxSzerokoscMM: 1000, maxWysokoscMM: 2600,
            kodKoloru: "9005", kolorHEX: "#0D0D0D", opis: "Szkło lakierowane czarne 6mm"
        ),
        WypelnienieDrzwiBonari(
            id: "SZKLO-SATYNA", nazwa: "Szkło satynowe",
            konstrukcja: .szklo, gruboscMM: 8, wagaKgM2: 20.0,
            maxSzerokoscMM: 1100, maxWysokoscMM: 2800,
            kodKoloru: nil, kolorHEX: "#E8E8EC", opis: "Szkło piaskowane satynowe 8mm"
        ),
        WypelnienieDrzwiBonari(
            id: "SZKLO-CLEAR", nazwa: "Szkło bezbarwne hartowane",
            konstrukcja: .szklo, gruboscMM: 8, wagaKgM2: 20.0,
            maxSzerokoscMM: 1200, maxWysokoscMM: 3000,
            kodKoloru: nil, kolorHEX: "#C8D4DC", opis: "Szkło hartowane bezbarwne 8mm (ścianka dzieląca)"
        ),
    ]

    static func wypelnienia(dla konstrukcja: KonstrukcjaDrzwiPrzesuwnychV075) -> [WypelnienieDrzwiBonari] {
        wypelnienia.filter { $0.konstrukcja == konstrukcja }
    }
}

// isBonari i seriaBonari są zdefiniowane w SilnikSzafyPrzesuwanejV075.swift (główna definicja enum).
