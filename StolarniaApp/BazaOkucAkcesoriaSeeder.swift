import Foundation

enum BazaOkucAkcesoriaSeeder {
    static let migrationVersion = 2026062003

    static var okucia: [OkucieMeblowe] {
        KatalogRegulAkcesoriow.profile.compactMap { profile in
            guard let price = profile.cenaRynkowa else {
                return nil
            }

            var item = OkucieMeblowe(
                kod: BazaMaterialowAkcesoriaSeeder.materialCode(profile.id),
                nazwa: "\(profile.producent) \(profile.rodzina) — \(profile.model)",
                producent: profile.producent,
                dostawca: "Rynek PL — średnia",
                typ: fittingType(profile.kategoria),
                jednostka: fittingUnit(price.jednostka),
                cenaNetto: price.cenaSredniaNettoPLN,
                vatProcent: 23,
                rabatProcent: 0,
                iloscWOakowaniu: 1,
                system: profile.rodzina,
                katOtwarciaStopnie: profile.katOtwarciaStopnie ?? 0,
                dlugoscMM: representativeValue(profile.dozwoloneDlugosciMM),
                szerokoscMM: 0,
                wysokoscMM: representativeValue(profile.dozwoloneWysokosciMM),
                nosnoscKG: profile.maksymalneObciazenieKG ?? 0,
                gruboscPlytyOdMM: minimumThickness(profile),
                gruboscPlytyDoMM: maximumThickness(profile),
                poziomWyceny: pricingTier(profile),
                aktywne: true,
                notatki: notes(profile: profile, price: price),
                dataAktualizacji: price.dataResearchu
            )
            item.profilAkcesoriumID = profile.id
            return item
        }
    }

    private static func fittingType(
        _ category: KategoriaAkcesoriumMeblowego
    ) -> TypOkuciaMeblowego {
        switch category {
        case .systemSzuflady:
            return .systemSzuflad
        case .prowadnica:
            return .prowadnica
        case .zawias:
            return .zawias
        case .podnosnikFrontu:
            return .podnosnik
        case .systemNarozny, .cargoIOrganizer:
            return .cargo
        case .nozkaIPodpora:
            return .noga
        case .zawieszkaSzafki:
            return .zawieszka
        case .mechanizmBezuchwytowy:
            return .uchwyt
        case .oswietlenie:
            return .oswietlenieLED
        case .zlaczeKonstrukcyjne:
            return .lacznik
        case .wentylacjaAGD, .inne:
            return .inne
        }
    }

    private static func fittingUnit(
        _ unit: JednostkaCenyRynkowejAkcesorium
    ) -> JednostkaOkucia {
        switch unit {
        case .sztuka:
            return .sztuka
        case .komplet:
            return .komplet
        case .para:
            return .para
        case .zestawDwochMetrow:
            return .komplet
        case .metr:
            return .metr
        case .opakowanie:
            return .opakowanie
        }
    }

    private static func pricingTier(
        _ profile: ProfilAkcesoriumMeblowego
    ) -> PoziomWycenyOkucia {
        let ecoProfileIDs: Set<String> = [
            "gtv.gx2a.h45.eco",
            "gtv.prestige.h45.eco"
        ]
        if ecoProfileIDs.contains(profile.id) {
            return .eco
        }

        let producer = profile.producent.lowercased()
        if producer.contains("blum")
            || producer.contains("hettich")
            || producer.contains("häfele")
            || producer.contains("salice")
        {
            return .premium
        }
        return .standard
    }

    private static func representativeValue(
        _ values: [Double]
    ) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else {
            return 0
        }
        return sorted[sorted.count / 2]
    }

    private static func minimumThickness(
        _ profile: ProfilAkcesoriumMeblowego
    ) -> Double {
        thicknessValues(profile).min() ?? 0
    }

    private static func maximumThickness(
        _ profile: ProfilAkcesoriumMeblowego
    ) -> Double {
        thicknessValues(profile).max() ?? 0
    }

    private static func thicknessValues(
        _ profile: ProfilAkcesoriumMeblowego
    ) -> [Double] {
        let rules = [
            profile.regulaGrubosciDna,
            profile.regulaGrubosciTylu,
            profile.regulaGrubosciBoku
        ]

        return rules.flatMap { rule -> [Double] in
            switch rule.tryb {
            case .stala:
                return [rule.stalaMM].compactMap { $0 }
            case .zakres:
                return [rule.minimumMM, rule.maksimumMM].compactMap { $0 }
            case .wybor:
                return rule.dozwoloneMM
            case .brak, .wymagaPotwierdzenia:
                return []
            }
        }
    }

    private static func notes(
        profile: ProfilAkcesoriumMeblowego,
        price: CenaRynkowaAkcesorium
    ) -> String {
        """
        Profil katalogowy: \(profile.id)
        Kategoria: \(profile.kategoria.nazwa)
        Cena średnia brutto: \(currency(price.cenaSredniaBruttoPLN))
        Zakres brutto: \(currency(price.cenaMinimalnaBruttoPLN))–\(currency(price.cenaMaksymalnaBruttoPLN))
        Jednostka badania: \(price.jednostka.skrot)
        Zakres pozycji: \(price.opisZakresu)
        Cena jest edytowalna i nie jest nadpisywana podczas kolejnej synchronizacji katalogu.
        """
    }

    private static func currency(_ value: Double) -> String {
        value.formatted(.currency(code: "PLN"))
    }
}
