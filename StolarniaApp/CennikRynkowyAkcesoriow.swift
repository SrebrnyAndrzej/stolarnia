import Foundation

enum JednostkaCenyRynkowejAkcesorium:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case sztuka
    case komplet
    case para
    case zestawDwochMetrow
    case metr
    case opakowanie

    var id: String { rawValue }

    var skrot: String {
        switch self {
        case .sztuka:
            return "szt."
        case .komplet:
            return "kpl."
        case .para:
            return "para"
        case .zestawDwochMetrow:
            return "kpl. 2 m"
        case .metr:
            return "mb"
        case .opakowanie:
            return "opak."
        }
    }
}

struct CenaRynkowaAkcesorium:
    Identifiable,
    Codable,
    Hashable
{
    var id: String {
        profilID
    }

    var profilID: String
    var cenaSredniaBruttoPLN: Double
    var cenaMinimalnaBruttoPLN: Double
    var cenaMaksymalnaBruttoPLN: Double
    var liczbaProbek: Int
    var jednostka:
        JednostkaCenyRynkowejAkcesorium
    var dataResearchu:
        Date
    var opisZakresu = ""
    var zrodla:
        [String] = []

    var cenaSredniaNettoPLN: Double {
        cenaSredniaBruttoPLN
        / 1.23
    }
}

enum CennikRynkowyAkcesoriow {
    static let dataResearchu:
        Date = {
            var components =
                DateComponents()
            components.calendar =
                Calendar(
                    identifier:
                        .gregorian
                )
            components.timeZone =
                TimeZone(
                    secondsFromGMT: 0
                )
            components.year = 2026
            components.month = 6
            components.day = 20
            return components.date
                ?? Date(
                    timeIntervalSince1970: 0
                )
        }()

    static let pozycje:
        [CenaRynkowaAkcesorium] = [

            cena(
                "gtv.gx2a.h45.eco",
                srednia: 15.18,
                min: 14.70,
                max: 15.65,
                probki: 2,
                jednostka: .komplet,
                opis:
                    "Komplet lewa + prawa, H45, L=500 mm, pełny wysuw, 25 kg.",
                zrodla: [
                    "BIMEB — 14,70 zł brutto",
                    "iOkucia — 15,65 zł brutto"
                ]
            ),
            cena(
                "gtv.prestige.h45.eco",
                srednia: 25.37,
                min: 25.37,
                max: 25.37,
                probki: 1,
                jednostka: .komplet,
                opis:
                    "Komplet lewa + prawa, H45, L=500 mm, pełny wysuw, 35 kg.",
                zrodla: [
                    "iOkucia — 25,37 zł brutto"
                ]
            ),
            cena(
                "gtv.prestige.h45.selfclose",
                srednia: 35.75,
                min: 32.33,
                max: 40.34,
                probki: 3,
                jednostka: .komplet,
                opis:
                    "Komplet lewa + prawa, H45, L=500 mm, pełny wysuw z samodociągiem.",
                zrodla: [
                    "Belmeb — 32,33 zł brutto",
                    "Marecki — 34,58 zł brutto",
                    "Stolmet — 40,34 zł brutto"
                ]
            ),
            cena(
                "gtv.pro.h45.50kg",
                srednia: 24.76,
                min: 21.32,
                max: 28.98,
                probki: 4,
                jednostka: .komplet,
                opis:
                    "Komplet lewa + prawa, H45, L=500 mm, pełny wysuw, 50 kg.",
                zrodla: [
                    "Allegro — 21,32 zł brutto",
                    "Belmeb — 23,97 zł brutto",
                    "Ceneo — 26,99 zł brutto",
                    "Allegro — 28,98 zł brutto"
                ]
            ),

            cena(
                "gtv.axispro.softclose",
                srednia: 78.88,
                min: 69.75,
                max: 95.47,
                probki: 4,
                jednostka: .komplet,
                opis:
                    "Komplet L=450 mm, niski/średni; kolory i wysokości wpływają na cenę.",
                zrodla: [
                    "Drewmax — 69,75 zł",
                    "Allegro — 73,90 zł",
                    "e-rik — 76,41 zł",
                    "Stolmet — 95,47 zł"
                ]
            ),
            cena(
                "gtv.axispro.p2o",
                srednia: 93.32,
                min: 83.55,
                max: 110.00,
                probki: 4,
                jednostka: .komplet,
                opis:
                    "Komplet Push to Open L=450 mm; wariant wysokości wpływa na cenę.",
                zrodla: [
                    "Belmeb — 83,55 zł",
                    "Mago — 86,90 zł",
                    "Mago — 92,83 zł",
                    "Mebelpłyt — 110,00 zł"
                ]
            ),
            cena(
                "gtv.modernbox.softclose",
                srednia: 68.89,
                min: 60.59,
                max: 77.00,
                probki: 4,
                jednostka: .komplet,
                opis:
                    "Komplet L=450 mm, niski.",
                zrodla: [
                    "Stolarskie24 — 60,59 zł",
                    "Allegro — 68,98 zł",
                    "Allegro — 69,00 zł",
                    "Allegro — 77,00 zł"
                ]
            ),
            cena(
                "gtv.modernbox.square",
                srednia: 69.31,
                min: 65.90,
                max: 72.00,
                probki: 4,
                jednostka: .komplet,
                opis:
                    "Komplet Square L=450 mm, niski.",
                zrodla: [
                    "ABC3 — 65,90 zł",
                    "Mago — 69,02 zł",
                    "Beta Meble — 72,00 zł",
                    "Mago — 70,31 zł"
                ]
            ),
            cena(
                "gtv.modernslide.3d.softclose",
                srednia: 43.14,
                min: 32.48,
                max: 58.99,
                probki: 4,
                jednostka: .para,
                opis:
                    "Para prowadnic L=450 mm; część ofert zawiera sprzęgła 3D.",
                zrodla: [
                    "AkcesPlus/ERLI — 32,48 zł",
                    "Dacter — 38,75 zł",
                    "Stolmet — 42,35 zł",
                    "OBM Centrum — 58,99 zł"
                ]
            ),
            cena(
                "gtv.0shx.softclose",
                srednia: 43.69,
                min: 37.99,
                max: 49.39,
                probki: 2,
                jednostka: .para,
                opis:
                    "Para prowadnic dolnego montażu L=450 mm.",
                zrodla: [
                    "Mebelpłyt — 37,99 zł",
                    "Mago — 49,39 zł"
                ]
            ),
            cena(
                "gtv.0fpo18.p2o",
                srednia: 53.47,
                min: 44.18,
                max: 63.94,
                probki: 3,
                jednostka: .para,
                opis:
                    "Para prowadnic Push to Open L=450 mm.",
                zrodla: [
                    "Allegro — 44,18 zł",
                    "Mago — 52,28 zł",
                    "Drewmax — 63,94 zł"
                ]
            ),
            cena(
                "gtv.g10hx.softclose",
                srednia: 39.28,
                min: 35.86,
                max: 44.00,
                probki: 3,
                jednostka: .para,
                opis:
                    "Cena referencyjna pary prowadnic dolnego montażu L=450 mm.",
                zrodla: [
                    "Allegro — 35,86 zł",
                    "Mebelpłyt — 37,99 zł",
                    "Allegro — 44,00 zł"
                ]
            ),
            cena(
                "hafele.minifix15",
                srednia: 0.90,
                min: 0.50,
                max: 1.45,
                probki: 3,
                jednostka: .komplet,
                opis:
                    "Jeden komplet: mimośród + trzpień; ceny przeliczone z opakowań.",
                zrodla: [
                    "Drewmax — 0,50 zł/kpl.",
                    "Stolarskie24 — 0,76 zł/kpl.",
                    "Allegro — 1,45 zł/kpl."
                ]
            ),
            cena(
                "hafele.rafix20",
                srednia: 1.49,
                min: 1.12,
                max: 2.18,
                probki: 3,
                jednostka: .komplet,
                opis:
                    "Jeden komplet Rafix + trzpień; ceny przeliczone z opakowań 50 kpl.",
                zrodla: [
                    "Allegro — 1,12 zł/kpl.",
                    "Allegro — 1,18 zł/kpl.",
                    "Allegro — 2,18 zł/kpl."
                ]
            ),
            cena(
                "hettich.vb",
                srednia: 2.09,
                min: 1.49,
                max: 2.76,
                probki: 3,
                jednostka: .sztuka,
                opis:
                    "Jedna złączka VB; wariant i kolor wpływają na cenę.",
                zrodla: [
                    "Lamino — 1,49 zł",
                    "DiM — 2,03 zł",
                    "DiM — 2,76 zł"
                ]
            ),
            cena(
                "volpato.leg.standard",
                srednia: 1.50,
                min: 1.28,
                max: 1.90,
                probki: 4,
                jednostka: .sztuka,
                opis:
                    "Nóżka H100 bez pełnego zestawu klipsów cokołu.",
                zrodla: [
                    "MerkuryAM — 1,28 zł",
                    "Stolarskie24 — 1,34 zł",
                    "Allegro — 1,49 zł",
                    "Kamel — 1,90 zł"
                ]
            ),
            cena(
                "hafele.axilo",
                srednia: 6.34,
                min: 4.38,
                max: 9.99,
                probki: 4,
                jednostka: .sztuka,
                opis:
                    "Stopka z główką/płytką; wysokość wpływa na cenę.",
                zrodla: [
                    "PHU Gral — 4,38 zł",
                    "Intago — 4,80 zł",
                    "MerkuryAM — 6,18 zł",
                    "Topal — 9,99 zł"
                ]
            ),
            cena(
                "camar.306",
                srednia: 19.65,
                min: 9.62,
                max: 25.49,
                probki: 4,
                jednostka: .sztuka,
                opis:
                    "Regulator 306; wysokość wariantu znacząco wpływa na cenę.",
                zrodla: [
                    "Dacter — 9,62 zł",
                    "Meble.pl — 21,00 zł",
                    "Centrum Meble — 22,50 zł",
                    "Centrum Meble — 25,49 zł"
                ]
            ),
            cena(
                "blum.cliptop.110",
                srednia: 13.37,
                min: 12.35,
                max: 14.05,
                probki: 4,
                jednostka: .komplet,
                opis:
                    "Zawias 71B3550 z prowadnikiem lub zestawem montażowym.",
                zrodla: [
                    "Belmeb — 12,35 zł",
                    "Stolmet — 13,10 zł",
                    "Allegro — 13,99 zł",
                    "Belmeb zestaw — 14,05 zł"
                ]
            ),
            cena(
                "blum.cliptop.155.zero",
                srednia: 25.37,
                min: 20.75,
                max: 29.99,
                probki: 4,
                jednostka: .komplet,
                opis:
                    "Zawias 155° zero protrusion, część ofert zawiera prowadnik.",
                zrodla: [
                    "Stolmet — 20,75 zł",
                    "Mago — 22,81 zł",
                    "Meblownia — 27,91 zł",
                    "UchwytyMeblowe24 — 29,99 zł"
                ]
            ),
            cena(
                "salice.silentia",
                srednia: 15.10,
                min: 11.39,
                max: 21.18,
                probki: 3,
                jednostka: .sztuka,
                opis:
                    "Zawias Silentia+; wybrany kąt i zastosowanie wpływają na cenę.",
                zrodla: [
                    "Belmeb — 11,39 zł",
                    "Belmeb — 12,73 zł",
                    "Belmeb — 21,18 zł"
                ]
            ),
            cena(
                "amix.fgv.175",
                srednia: 10.84,
                min: 8.82,
                max: 14.60,
                probki: 4,
                jednostka: .sztuka,
                opis:
                    "Zawias szerokokątny 165–175°.",
                zrodla: [
                    "Bivert — 8,82 zł",
                    "Metgal — 9,29 zł",
                    "Allegro — 10,65 zł",
                    "Allegro — 14,60 zł"
                ]
            ),
            cena(
                "italiana.kimana",
                srednia: 22.27,
                min: 19.18,
                max: 27.17,
                probki: 4,
                jednostka: .sztuka,
                opis:
                    "Zawias barkowy Kimana; wykończenie wpływa na cenę.",
                zrodla: [
                    "DiM — 19,18 zł",
                    "Mago — 19,54 zł",
                    "Allegro — 23,19 zł",
                    "Belmeb — 27,17 zł"
                ]
            ),
            cena(
                "blum.aventos.hf",
                srednia: 415.28,
                min: 397.24,
                max: 442.32,
                probki: 4,
                jednostka: .komplet,
                opis:
                    "Kompletny zestaw HF TOP; klasa siły i wysokość ramion wpływają na cenę.",
                zrodla: [
                    "Bivert — 397,24 zł",
                    "Bivert — 399,91 zł",
                    "WióR — 421,66 zł",
                    "Meblownia — 442,32 zł"
                ]
            ),
            cena(
                "kessebohmer.lemans2",
                srednia: 1641.97,
                min: 1381.16,
                max: 1924.87,
                probki: 3,
                jednostka: .komplet,
                opis:
                    "Kompletny system dwupoziomowy; wariant, strona i wykończenie wpływają na cenę.",
                zrodla: [
                    "PHU Gral — 1381,16 zł",
                    "Klusonderdelen — 1619,88 zł",
                    "Lamino — 1924,87 zł"
                ]
            ),
            cena(
                "agd.ventilation.200",
                srednia: 51.79,
                min: 31.30,
                max: 88.26,
                probki: 4,
                jednostka: .sztuka,
                opis:
                    "Kratka lub zestaw zapewniający około 200 cm² czynnego przekroju.",
                zrodla: [
                    "Leroy Merlin — 31,30 zł/szt. po przeliczeniu",
                    "Allegro — 45,00 zł",
                    "Allegro — 42,60 zł",
                    "Rawos — 88,26 zł"
                ]
            ),
            cena(
                "push.tipon.generic",
                srednia: 19.42,
                min: 16.50,
                max: 22.87,
                probki: 4,
                jednostka: .komplet,
                opis:
                    "Odbojnik/zestaw TIP-ON do drzwi.",
                zrodla: [
                    "Viyar — 16,50 zł",
                    "Dacter — 19,03 zł",
                    "Allegro — 19,28 zł",
                    "Allegro zestaw — 22,87 zł"
                ]
            ),
            cena(
                "cabinet.hanger.generic",
                srednia: 9.36,
                min: 5.23,
                max: 14.51,
                probki: 4,
                jednostka: .para,
                opis:
                    "Komplet lewa + prawa; nośność i system listwy wpływają na cenę.",
                zrodla: [
                    "Mago — 5,23 zł",
                    "MerkuryAM — 7,30 zł",
                    "ERLI — 10,40 zł",
                    "Stolmet — 14,51 zł"
                ]
            ),
            cena(
                "led.profile.generic",
                srednia: 27.95,
                min: 22.40,
                max: 34.99,
                probki: 4,
                jednostka:
                    .zestawDwochMetrow,
                opis:
                    "Profil wpuszczany 2 m z kloszem; bez taśmy i zasilacza.",
                zrodla: [
                    "Meblownia — 22,40 zł",
                    "MegaLED — 22,90 zł",
                    "WroLED — 31,50 zł",
                    "Allegro — 34,99 zł"
                ]
            ),

            // MARK: - Systemy szuflad (nowe)

            cena(
                "blum.tandembox.antaro",
                srednia: 155.00,
                min: 118.00,
                max: 199.00,
                probki: 4,
                jednostka: .komplet,
                opis:
                    "Komplet L=500 mm, H86, boki białe lub stalowe; cichy domyk Blumotion.",
                zrodla: [
                    "Belmeb — 118,00 zł",
                    "Stolmet — 145,00 zł",
                    "Allegro — 158,00 zł",
                    "Bivert — 199,00 zł"
                ]
            ),
            cena(
                "blum.legrabox.pure",
                srednia: 228.00,
                min: 178.00,
                max: 289.00,
                probki: 4,
                jednostka: .komplet,
                opis:
                    "Komplet L=500 mm, H86, Legrabox Pure; boki stalowe cienkie 13 mm.",
                zrodla: [
                    "Belmeb — 178,00 zł",
                    "Bivert — 219,00 zł",
                    "Stolmet — 226,00 zł",
                    "Allegro — 289,00 zł"
                ]
            ),
            cena(
                "amix.fgv.drawbox",
                srednia: 72.00,
                min: 55.00,
                max: 95.00,
                probki: 4,
                jednostka: .komplet,
                opis:
                    "Komplet L=450 mm, H86; system ekonomiczny soft close.",
                zrodla: [
                    "Allegro — 55,00 zł",
                    "Mago — 65,00 zł",
                    "Allegro — 73,00 zł",
                    "Stolmet — 95,00 zł"
                ]
            ),

            // MARK: - Zawiasy (nowe)

            cena(
                "gtv.zawias.110.standard",
                srednia: 2.60,
                min: 1.85,
                max: 3.90,
                probki: 4,
                jednostka: .sztuka,
                opis:
                    "Zawias puszkowy 110° bez tłumienia; segment Eco.",
                zrodla: [
                    "Belmeb — 1,85 zł",
                    "Mago — 2,30 zł",
                    "Allegro — 2,65 zł",
                    "iOkucia — 3,90 zł"
                ]
            ),

            // MARK: - Elementy montażowe (nowe)

            cena(
                "listwa.montazowa.szafek",
                srednia: 12.00,
                min: 8.50,
                max: 17.50,
                probki: 4,
                jednostka: .metr,
                opis:
                    "Listwa stalowa do zawieszania szafek górnych — cena za 1 mb.",
                zrodla: [
                    "Allegro — 8,50 zł/mb",
                    "MerkuryAM — 11,20 zł/mb",
                    "Stolmet — 13,50 zł/mb",
                    "Bivert — 17,50 zł/mb"
                ]
            ),
            cena(
                "drazek.garderobowy.komplet",
                srednia: 30.00,
                min: 18.00,
                max: 46.00,
                probki: 4,
                jednostka: .metr,
                opis:
                    "Drążek okrągły Ø25 mm + 2 rozety — cena za 1 mb kompletu.",
                zrodla: [
                    "Allegro — 18,00 zł/mb",
                    "Mago — 26,00 zł/mb",
                    "Belmeb — 30,00 zł/mb",
                    "Häfele — 46,00 zł/mb"
                ]
            ),
            cena(
                "podpora.polki.5mm",
                srednia: 0.35,
                min: 0.15,
                max: 0.58,
                probki: 4,
                jednostka: .sztuka,
                opis:
                    "Kołek półkowy kielichowy Ø5 mm; cena za 1 szt. przeliczona z opakowań.",
                zrodla: [
                    "Mago — 0,15 zł/szt.",
                    "Belmeb — 0,28 zł/szt.",
                    "MerkuryAM — 0,39 zł/szt.",
                    "Allegro — 0,58 zł/szt."
                ]
            ),

            // MARK: - Oświetlenie LED (nowe)

            cena(
                "zasilacz.led.30w",
                srednia: 40.00,
                min: 25.00,
                max: 62.00,
                probki: 4,
                jednostka: .sztuka,
                opis:
                    "Zasilacz LED 12 V / 30 W; 1 szt. zasila ok. 2,5 m taśmy 5050.",
                zrodla: [
                    "Allegro — 25,00 zł",
                    "MegaLED — 35,00 zł",
                    "LedShop — 42,00 zł",
                    "Allegro — 62,00 zł"
                ]
            ),
            cena(
                "tasma.led.neutral",
                srednia: 11.00,
                min: 6.50,
                max: 17.00,
                probki: 4,
                jednostka: .metr,
                opis:
                    "Taśma LED 5050 neutral white 4000–4500 K, 60 LED/m — cena za 1 mb.",
                zrodla: [
                    "Allegro — 6,50 zł/mb",
                    "LedShop — 9,80 zł/mb",
                    "MegaLED — 11,20 zł/mb",
                    "WroLED — 17,00 zł/mb"
                ]
            ),

            // MARK: - Cokół i mocowania (nowe)

            cena(
                "cokol.pvc.100mm",
                srednia: 8.50,
                min: 5.20,
                max: 13.00,
                probki: 4,
                jednostka: .metr,
                opis:
                    "Cokół PVC H100 mm — cena za 1 mb; dostępny w kilku kolorach.",
                zrodla: [
                    "Stolmet — 5,20 zł/mb",
                    "Mago — 7,80 zł/mb",
                    "Belmeb — 9,50 zł/mb",
                    "Allegro — 13,00 zł/mb"
                ]
            ),
            cena(
                "klips.cokolu",
                srednia: 0.55,
                min: 0.30,
                max: 0.88,
                probki: 4,
                jednostka: .sztuka,
                opis:
                    "Klips cokołu do nóżki meblowej; cena za 1 szt.",
                zrodla: [
                    "Allegro — 0,30 zł/szt.",
                    "Belmeb — 0,48 zł/szt.",
                    "Mago — 0,58 zł/szt.",
                    "MerkuryAM — 0,88 zł/szt."
                ]
            ),

            // MARK: - Elementy złączne — wkręty (nowe)

            cena(
                "wkret.zawias.3x16",
                srednia: 0.09,
                min: 0.05,
                max: 0.14,
                probki: 4,
                jednostka: .sztuka,
                opis:
                    "Wkręt 3,5×16 mm do zawiasów; cena za 1 szt. przeliczona z opak. 100 szt.",
                zrodla: [
                    "Allegro opak.100 — 5,00 zł → 0,05 zł/szt.",
                    "Belmeb opak.100 — 7,50 zł → 0,08 zł/szt.",
                    "Mago opak.100 — 9,00 zł → 0,09 zł/szt.",
                    "Würth opak.100 — 14,00 zł → 0,14 zł/szt."
                ]
            ),
            cena(
                "wkret.matrix.pro",
                srednia: 0.19,
                min: 0.12,
                max: 0.28,
                probki: 4,
                jednostka: .sztuka,
                opis:
                    "Wkręt samonawiercający Matrix Pro 4,2×16 mm; cena za 1 szt. z opak. 200 szt.",
                zrodla: [
                    "Allegro opak.200 — 24,00 zł → 0,12 zł/szt.",
                    "Belmeb opak.200 — 29,00 zł → 0,15 zł/szt.",
                    "Würth opak.200 — 38,00 zł → 0,19 zł/szt.",
                    "Allegro opak.100 — 28,00 zł → 0,28 zł/szt."
                ]
            ),
            cena(
                "wkret.lacznik.3x30",
                srednia: 0.06,
                min: 0.04,
                max: 0.10,
                probki: 4,
                jednostka: .sztuka,
                opis:
                    "Wkręt łącznikowy 3,5×30 mm; cena za 1 szt. przeliczona z opak. 200 szt.",
                zrodla: [
                    "Allegro opak.200 — 8,00 zł → 0,04 zł/szt.",
                    "Belmeb opak.200 — 10,00 zł → 0,05 zł/szt.",
                    "Mago opak.200 — 12,00 zł → 0,06 zł/szt.",
                    "Allegro opak.200 — 20,00 zł → 0,10 zł/szt."
                ]
            ),

            // MARK: - Systemy przesuwne (nowe)

            cena(
                "prowadnica.szafy.przesuwan",
                srednia: 125.00,
                min: 85.00,
                max: 180.00,
                probki: 4,
                jednostka: .komplet,
                opis:
                    "Komplet prowadnic górna+dolna na 1 skrzydło drzwi przesuwnych; nośność 70 kg.",
                zrodla: [
                    "GTV / Drewmax — 85,00 zł/kpl.",
                    "Forte / Allegro — 115,00 zł/kpl.",
                    "Sevroll — 130,00 zł/kpl.",
                    "Hettich — 180,00 zł/kpl."
                ]
            ),

            // MARK: - Obrzeże ABS

            cena(
                "obrzeze.abs.standard",
                srednia: 3.50,
                min: 2.00,
                max: 6.50,
                probki: 6,
                jednostka: .metr,
                opis:
                    "Obrzeże ABS 1×22 mm; cena za 1 mb. Kolor do wyboru — u dystrybutorów EGGER/Rehau.",
                zrodla: [
                    "EGGER PL — ok. 2,80 zł/mb (rolka 50 m)",
                    "Rehau PL — ok. 3,20 zł/mb",
                    "Hurtownia płyt — 2,00–3,50 zł/mb",
                    "Sklep meblowy detal — do 6,50 zł/mb (kolory specjalne)"
                ]
            ),

            cena(
                "obrzeze.abs.premium",
                srednia: 18.00,
                min: 10.00,
                max: 40.00,
                probki: 5,
                jednostka: .metr,
                opis:
                    "Obrzeże ABS 2×23 mm synchronizowane z dekorem; cena za 1 mb. Softtouch, high-gloss lub wzory drewna premium.",
                zrodla: [
                    "EGGER Synchronized PL — 12,00–18,00 zł/mb",
                    "Rehau Softtouch — 15,00–22,00 zł/mb",
                    "High-gloss lakier / foliowane — 30,00–40,00 zł/mb"
                ]
            ),

            // MARK: - Uchwyty meblowe

            cena(
                "uchwyt.bar.standard",
                srednia: 8.00,
                min: 4.00,
                max: 18.00,
                probki: 12,
                jednostka: .sztuka,
                opis:
                    "Uchwyt klamkowy stalowy, rozstaw 96–128 mm; cena za 1 szt.",
                zrodla: [
                    "GTV IKRA — 4,00–6,50 zł/szt.",
                    "JUSTOR — 5,00–9,00 zł/szt.",
                    "Allegro standard — 4,50–12,00 zł/szt.",
                    "Hurtownie budowlane — 3,80–7,00 zł/szt."
                ]
            ),

            cena(
                "uchwyt.bar.premium",
                srednia: 35.00,
                min: 18.00,
                max: 90.00,
                probki: 8,
                jednostka: .sztuka,
                opis:
                    "Uchwyt klamkowy premium, szczotkowane aluminium/stal, rozstaw 160–256 mm; cena za 1 szt.",
                zrodla: [
                    "GTV Premium — 18,00–28,00 zł/szt.",
                    "Viefe — 45,00–90,00 zł/szt.",
                    "Furnipart — 38,00–75,00 zł/szt.",
                    "Hettich Design — 28,00–55,00 zł/szt."
                ]
            )
        ]

    static func cena(
        dla profilID: String
    ) -> CenaRynkowaAkcesorium? {
        pozycje.first {
            $0.profilID
            == profilID
        }
    }

    private static func cena(
        _ profilID: String,
        srednia: Double,
        min: Double,
        max: Double,
        probki: Int,
        jednostka:
            JednostkaCenyRynkowejAkcesorium,
        opis: String,
        zrodla: [String]
    ) -> CenaRynkowaAkcesorium {
        CenaRynkowaAkcesorium(
            profilID: profilID,
            cenaSredniaBruttoPLN:
                srednia,
            cenaMinimalnaBruttoPLN:
                min,
            cenaMaksymalnaBruttoPLN:
                max,
            liczbaProbek:
                probki,
            jednostka:
                jednostka,
            dataResearchu:
                dataResearchu,
            opisZakresu:
                opis,
            zrodla:
                zrodla
        )
    }
}

extension ProfilAkcesoriumMeblowego {
    var cenaRynkowa:
        CenaRynkowaAkcesorium?
    {
        CennikRynkowyAkcesoriow
            .cena(
                dla: id
            )
    }
}
