import Foundation

enum BazaMaterialowAkcesoriaSeeder {
    static let migrationVersion =
        2026062002

    static var materialy:
        [MaterialStolarski]
    {
        KatalogRegulAkcesoriow
            .profile
            .compactMap {
                profile in

                guard let price =
                    profile.cenaRynkowa
                else {
                    return nil
                }

                var material = MaterialStolarski(
                    kod:
                        materialCode(
                            profile.id
                        ),
                    nazwa:
                        "\(profile.producent) \(profile.rodzina) — \(profile.model)",
                    producent:
                        profile.producent,
                    dostawca:
                        "Rynek PL — średnia",
                    typ:
                        materialType(
                            profile.kategoria
                        ),
                    dekor:
                        profile.kategoria.nazwa,
                    gruboscMM:
                        defaultThickness(
                            profile
                        ),
                    szerokoscArkuszaMM:
                        0,
                    wysokoscArkuszaMM:
                        0,
                    jednostka:
                        materialUnit(
                            price.jednostka
                        ),
                    cenaNetto:
                        price
                            .cenaSredniaNettoPLN,
                    vatProcent:
                        23,
                    rabatProcent:
                        0,
                    aktywny:
                        true,
                    kierunekDekoru:
                        false,
                    kolorHEX:
                        colorHEX(
                            profile.kategoria
                        ),
                    notatki:
                        notes(
                            profile: profile,
                            price: price
                        ),
                    dataAktualizacji:
                        price.dataResearchu
                )
                material.profilAkcesoriumID =
                    profile.id
                return material
            }
    }

    static func materialCode(
        _ profileID: String
    ) -> String {
        "OK-"
        + profileID
            .uppercased()
            .replacingOccurrences(
                of: ".",
                with: "-"
            )
    }

    private static func materialType(
        _ category:
            KategoriaAkcesoriumMeblowego
    ) -> TypMaterialuStolarskiego {
        switch category {
        case .systemSzuflady,
             .prowadnica:
            return .systemSzuflady

        case .zawias,
             .podnosnikFrontu,
             .zlaczeKonstrukcyjne,
             .nozkaIPodpora,
             .mechanizmBezuchwytowy,
             .zawieszkaSzafki:
            return .okucie

        case .systemNarozny,
             .cargoIOrganizer,
             .wentylacjaAGD,
             .oswietlenie,
             .inne:
            return .akcesoriumMeblowe
        }
    }

    private static func materialUnit(
        _ unit:
            JednostkaCenyRynkowejAkcesorium
    ) -> JednostkaCenyMaterialu {
        switch unit {
        case .sztuka:
            return .sztuka
        case .komplet:
            return .komplet
        case .para:
            return .para
        case .zestawDwochMetrow:
            return .zestawDwochMetrow
        case .metr:
            return .metrBiezacy
        case .opakowanie:
            return .komplet
        }
    }

    private static func defaultThickness(
        _ profile:
            ProfilAkcesoriumMeblowego
    ) -> Double {
        [
            profile
                .regulaGrubosciDna
                .stalaMM,
            profile
                .regulaGrubosciTylu
                .stalaMM,
            profile
                .regulaGrubosciBoku
                .stalaMM
        ]
        .compactMap {
            $0
        }
        .first
        ?? 0
    }

    private static func colorHEX(
        _ category:
            KategoriaAkcesoriumMeblowego
    ) -> String {
        switch category {
        case .systemSzuflady:
            return "#4A5568"
        case .prowadnica:
            return "#64748B"
        case .zawias:
            return "#71717A"
        case .podnosnikFrontu:
            return "#475569"
        case .zlaczeKonstrukcyjne:
            return "#78716C"
        case .nozkaIPodpora:
            return "#57534E"
        case .systemNarozny:
            return "#0F766E"
        case .cargoIOrganizer:
            return "#0369A1"
        case .wentylacjaAGD:
            return "#0284C7"
        case .mechanizmBezuchwytowy:
            return "#7C3AED"
        case .zawieszkaSzafki:
            return "#52525B"
        case .oswietlenie:
            return "#D97706"
        case .inne:
            return "#6B7280"
        }
    }

    private static func notes(
        profile:
            ProfilAkcesoriumMeblowego,
        price:
            CenaRynkowaAkcesorium
    ) -> String {
        let sources =
            price.zrodla
                .joined(
                    separator: " | "
                )

        return """
        Profil: \(profile.id)
        Kategoria: \(profile.kategoria.nazwa)
        Cena średnia brutto: \(currency(price.cenaSredniaBruttoPLN))
        Zakres brutto: \(currency(price.cenaMinimalnaBruttoPLN))–\(currency(price.cenaMaksymalnaBruttoPLN))
        Próbek: \(price.liczbaProbek)
        Jednostka: \(price.jednostka.skrot)
        Research: \(price.dataResearchu.formatted(date: .numeric, time: .omitted))
        Zakres pozycji: \(price.opisZakresu)
        Źródła: \(sources)
        Cena jest punktem startowym. Przed ofertą należy ją zaktualizować u właściwego dostawcy.
        """
    }

    private static func currency(
        _ value: Double
    ) -> String {
        value.formatted(
            .currency(
                code: "PLN"
            )
        )
    }
}
