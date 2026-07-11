import Foundation

enum NormySzafekCatalog {
    static let wszystkie:
        [NormaSzafki] = [
            NormaSzafki(
                kategoria:
                    .dolnaUniwersalna,
                nazwa:
                    "Szafka dolna",
                typoweSzerokosciMM: [
                    300,
                    400,
                    500,
                    600,
                    800,
                    900,
                    1000
                ],
                glebokoscMM:
                    ZakresNormyMM(
                        minimum: 560,
                        maximum: 580
                    ),
                wysokoscKorpusuMM:
                    ZakresNormyMM(
                        minimum: 720,
                        maximum: 750
                    ),
                wysokoscCokoluMM:
                    ZakresNormyMM(
                        minimum: 100,
                        maximum: 150
                    ),
                gruboscBlatuMM:
                    ZakresNormyMM(
                        minimum: 12,
                        maximum: 40
                    ),
                typowaGruboscBlatuMM:
                    38,
                typowaGlebokoscBlatuMM:
                    600,
                odsunPlecyOdTyluMM:
                    ZakresNormyMM(
                        minimum: 50,
                        maximum: 70
                    ),
                uwagi:
                    "Wysokość korpusu bez cokołu i blatu."
            ),
            NormaSzafki(
                kategoria:
                    .dolnaCargo,
                nazwa:
                    "Szafka dolna cargo",
                typoweSzerokosciMM: [
                    150,
                    200
                ],
                glebokoscMM:
                    ZakresNormyMM(
                        minimum: 560,
                        maximum: 580
                    ),
                wysokoscKorpusuMM:
                    ZakresNormyMM(
                        minimum: 720,
                        maximum: 750
                    ),
                wysokoscCokoluMM:
                    ZakresNormyMM(
                        minimum: 100,
                        maximum: 150
                    ),
                gruboscBlatuMM:
                    ZakresNormyMM(
                        minimum: 12,
                        maximum: 40
                    ),
                typowaGruboscBlatuMM:
                    38,
                typowaGlebokoscBlatuMM:
                    600,
                odsunPlecyOdTyluMM:
                    ZakresNormyMM(
                        minimum: 50,
                        maximum: 70
                    ),
                uwagi:
                    "Szerokości nominalne cargo zgodne z typowym typoszeregiem."
            ),
            NormaSzafki(
                kategoria:
                    .wiszaca,
                nazwa:
                    "Szafka wisząca",
                typoweSzerokosciMM: [
                    300,
                    400,
                    500,
                    600,
                    800,
                    900,
                    1000
                ],
                glebokoscMM:
                    ZakresNormyMM(
                        minimum: 280,
                        maximum: 350
                    ),
                wysokoscKorpusuMM:
                    ZakresNormyMM(
                        minimum: 300,
                        maximum: 1200
                    ),
                uwagi:
                    "Zakres wysokości obejmuje moduły niskie i wysokie."
            ),
            NormaSzafki(
                kategoria:
                    .naroznaL,
                nazwa:
                    "Szafka narożna L",
                typoweSzerokosciMM: [
                    800,
                    900
                ],
                glebokoscMM:
                    ZakresNormyMM(
                        minimum: 560,
                        maximum: 580
                    ),
                wysokoscKorpusuMM:
                    ZakresNormyMM(
                        minimum: 720,
                        maximum: 750
                    ),
                wysokoscCokoluMM:
                    ZakresNormyMM(
                        minimum: 100,
                        maximum: 150
                    ),
                uwagi:
                    "Typowe formaty 800×800 i 900×900 mm."
            ),
            NormaSzafki(
                kategoria:
                    .naroznaSlepa,
                nazwa:
                    "Szafka narożna ślepa",
                typoweSzerokosciMM: [
                    1050,
                    1250
                ],
                glebokoscMM:
                    ZakresNormyMM(
                        minimum: 560,
                        maximum: 580
                    ),
                wysokoscKorpusuMM:
                    ZakresNormyMM(
                        minimum: 720,
                        maximum: 750
                    ),
                wysokoscCokoluMM:
                    ZakresNormyMM(
                        minimum: 100,
                        maximum: 150
                    ),
                uwagi:
                    "Szerokość całkowita szafki blind."
            ),
            NormaSzafki(
                kategoria:
                    .slupek,
                nazwa:
                    "Słupek / wysoka zabudowa",
                typoweSzerokosciMM: [
                    600,
                    900
                ],
                glebokoscMM:
                    ZakresNormyMM(
                        minimum: 560,
                        maximum: 580
                    ),
                wysokoscKorpusuMM:
                    ZakresNormyMM(
                        minimum: 1700,
                        maximum: 2100
                    ),
                uwagi:
                    "Zakres dla wysokiej zabudowy."
            )
        ]

    static func norma(
        dla templateName: String,
        code: String,
        categoryName: String
    ) -> NormaSzafki {
        let source =
            (
                templateName
                + " "
                + code
                + " "
                + categoryName
            )
            .folding(
                options: [
                    .diacriticInsensitive,
                    .caseInsensitive
                ],
                locale: .current
            )
            .lowercased()

        if source.contains("cargo") {
            return norma(
                .dolnaCargo
            )
        }

        if source.contains("blind")
            || source.contains("slepa")
            || source.contains("ślepa") {
            return norma(
                .naroznaSlepa
            )
        }

        if source.contains("naroz")
            || source.contains("naroż")
            || source.contains("corner") {
            return norma(
                .naroznaL
            )
        }

        if source.contains("wall")
            || source.contains("wiszac")
            || source.contains("gorna")
            || source.contains("górna") {
            return norma(
                .wiszaca
            )
        }

        if source.contains("tall")
            || source.contains("slupek")
            || source.contains("słupek")
            || source.contains("wysok") {
            return norma(
                .slupek
            )
        }

        return norma(
            .dolnaUniwersalna
        )
    }

    static func norma(
        _ category:
            KategoriaNormySzafki
    ) -> NormaSzafki {
        wszystkie.first {
            $0.kategoria == category
        }
        ?? NormaSzafki(
            kategoria:
                .niestandardowa,
            nazwa:
                "Niestandardowa",
            glebokoscMM:
                ZakresNormyMM(
                    minimum: 1,
                    maximum: 5000
                ),
            wysokoscKorpusuMM:
                ZakresNormyMM(
                    minimum: 1,
                    maximum: 5000
                )
        )
    }
}
