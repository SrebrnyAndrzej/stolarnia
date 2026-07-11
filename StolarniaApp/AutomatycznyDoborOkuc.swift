import Foundation

struct DoborOkuciaWyceny:
    Hashable
{
    var item:
        OkucieMeblowe?
    var typ:
        TypOkuciaMeblowego
    var ilosc: Double
    var fallbackCenaNetto:
        Double
    var opisZastosowania:
        String

    var cenaJednostkowaNetto:
        Double
    {
        item?.cenaNettoPoRabacie
        ?? fallbackCenaNetto
    }

    var nazwaPozycji:
        String
    {
        item?.nazwa
        ?? fallbackName
    }

    var jednostka:
        String
    {
        item?.jednostka.nazwa
        ?? fallbackUnit
    }

    var uwagi:
        String
    {
        var parts:
            [String] = []

        if let item {
            let identity = [
                item.producent,
                item.kod,
                item.system
            ]
            .filter {
                !$0
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
                    .isEmpty
            }
            .joined(
                separator: " • "
            )

            if !identity.isEmpty {
                parts.append(identity)
            }

            parts.append(
                "Cena z bazy okuć."
            )
        } else {
            parts.append(
                "Cena domyślna — brak aktywnej pozycji w bazie okuć."
            )
        }

        parts.append(
            opisZastosowania
        )

        return parts.joined(
            separator: " "
        )
    }

    private var fallbackName:
        String
    {
        switch typ {
        case .zawias:
            return "Zawiasy meblowe"
        case .prowadnica:
            return "Prowadnice"
        case .systemSzuflad:
            return "Systemy szuflad"
        case .podnosnik:
            return "Podnośniki"
        case .cargo:
            return "Systemy cargo"
        case .noga:
            return "Nogi meblowe"
        case .cokół:
            return "Cokoły i mocowania"
        case .zawieszka:
            return "Zawieszki"
        case .uchwyt:
            return "Uchwyty"
        case .profil:
            return "Profile"
        case .oswietlenieLED:
            return "Oświetlenie LED"
        case .lacznik:
            return "Łączniki"
        case .wkręt:
            return "Elementy złączne"
        case .klej:
            return "Kleje i chemia"
        case .inne:
            return "Pozostałe okucia"
        }
    }

    private var fallbackUnit:
        String
    {
        switch typ {
        case .prowadnica:
            return "para"
        case .systemSzuflad,
             .podnosnik,
             .cargo:
            return "kpl."
        default:
            return "szt."
        }
    }
}

enum AutomatycznyDoborOkuc {
    static func dobierz(
        projekt:
            ProjektWyceny,
        wariant:
            WariantWyceny,
        baza:
            [OkucieMeblowe]
    ) -> [DoborOkuciaWyceny] {
        let active =
            baza.filter(\.aktywne)

        var result:
            [DoborOkuciaWyceny] = []

        if projekt.liczbaZawiasow > 0 {
            result.append(
                selection(
                    typ: .zawias,
                    quantity:
                        Double(
                            projekt
                                .liczbaZawiasow
                        ),
                    fallback: 24,
                    description:
                        "Liczba wynika z frontów rozwieranych.",
                    variant: wariant,
                    active: active
                )
            )
        }

        if projekt.liczbaSzuflad > 0 {
            let drawerSystem =
                selection(
                    typ:
                        preferredDrawerType(
                            variant:
                                wariant,
                            active:
                                active
                        ),
                    quantity:
                        Double(
                            projekt
                                .liczbaSzuflad
                        ),
                    fallback:
                        wariant == .eco
                        ? 145
                        : wariant == .standard
                        ? 220
                        : wariant == .premium
                        ? 360
                        : 520,
                    description:
                        "Jeden komplet na każdą szufladę.",
                    variant: wariant,
                    active: active
                )

            result.append(
                drawerSystem
            )
        }

        if projekt.liczbaCargo > 0 {
            result.append(
                selection(
                    typ: .cargo,
                    quantity:
                        Double(
                            projekt
                                .liczbaCargo
                        ),
                    fallback:
                        wariant == .eco
                        ? 650
                        : wariant == .standard
                        ? 950
                        : wariant == .premium
                        ? 1_450
                        : 2_100,
                    description:
                        "Jeden komplet na moduł cargo.",
                    variant: wariant,
                    active: active
                )
            )
        }

        // MARK: - Nogi meblowe (4 na każdy moduł dolny)

        if projekt.liczbaModulowDolnych > 0 {
            result.append(
                selection(
                    typ: .noga,
                    quantity:
                        Double(
                            projekt
                                .liczbaModulowDolnych
                                * 4
                        ),
                    fallback: 1.50,
                    description:
                        "4 nogi regulowane na każdy moduł dolny.",
                    variant: wariant,
                    active: active
                )
            )
        }

        // MARK: - Listwy do montażu szafek wiszących

        if projekt.liczbaModulowWiszacych > 0 {
            let listwaMB =
                itemByProfile(
                    id: "listwa.montazowa.szafek",
                    active: active
                )
            let listwa =
                DoborOkuciaWyceny(
                    item: listwaMB,
                    typ: .zawieszka,
                    ilosc:
                        max(
                            ceil(
                                Double(
                                    projekt
                                        .liczbaModulowWiszacych
                                ) * 0.65
                            ),
                            1
                        ),
                    fallbackCenaNetto:
                        9.76,   // 12,00 brutto / 1,23
                    opisZastosowania:
                        "Listwa montażowa szafek wiszących — ~0,65 mb na moduł."
                )
            result.append(listwa)
        }

        // MARK: - Podpory półek (4 szt. / półka regulowana)

        if projekt.liczbaPólekWewnetrznych > 0 {
            let podpora =
                itemByProfile(
                    id: "podpora.polki.5mm",
                    active: active
                )
            result.append(
                DoborOkuciaWyceny(
                    item: podpora,
                    typ: .noga,
                    ilosc:
                        Double(
                            projekt
                                .liczbaPólekWewnetrznych
                                * 4
                        ),
                    fallbackCenaNetto:
                        0.285,  // 0,35 brutto / 1,23
                    opisZastosowania:
                        "Kołki półkowe Ø5 mm — 4 szt. na każdą półkę regulowaną."
                )
            )
        }

        // MARK: - Drążki garderobowe (1 mb na każdy moduł garderobowy)

        if projekt.liczbaModulow > 0 {
            let drazek =
                itemByProfile(
                    id: "drazek.garderobowy.komplet",
                    active: active
                )
            let garderobaCount =
                max(
                    1,
                    Int(
                        ceil(
                            Double(
                                projekt
                                    .liczbaModulow
                            ) * 0.3
                        )
                    )
                )
            result.append(
                DoborOkuciaWyceny(
                    item: drazek,
                    typ: .inne,
                    ilosc:
                        Double(
                            garderobaCount
                        ),
                    fallbackCenaNetto:
                        24.39,  // 30,00 brutto / 1,23
                    opisZastosowania:
                        "Drążek garderobowy Ø25 mm z rozetami — szacunek dla modułów garderobowych."
                )
            )
        }

        // MARK: - Cokół PVC H100 + klipsy

        if projekt.dlugoscCokuluM > 0 {
            let cokol =
                itemByProfile(
                    id: "cokol.pvc.100mm",
                    active: active
                )
            result.append(
                DoborOkuciaWyceny(
                    item: cokol,
                    typ: .inne,
                    ilosc:
                        ceil(
                            projekt
                                .dlugoscCokuluM
                        ),
                    fallbackCenaNetto:
                        6.91,   // 8,50 brutto / 1,23
                    opisZastosowania:
                        "Cokół PVC H100 mm — mb zabudowy dolnej."
                )
            )

            let klips =
                itemByProfile(
                    id: "klips.cokolu",
                    active: active
                )
            result.append(
                DoborOkuciaWyceny(
                    item: klips,
                    typ: .inne,
                    ilosc:
                        ceil(
                            projekt
                                .dlugoscCokuluM
                                * 4
                        ),
                    fallbackCenaNetto:
                        0.447,  // 0,55 brutto / 1,23
                    opisZastosowania:
                        "Klipsy cokołu — 4 szt. na mb."
                )
            )
        }

        // MARK: - Wkręty do zawiasów (2 szt. / zawias)

        if projekt.liczbaZawiasow > 0 {
            let wkretZawias =
                itemByProfile(
                    id: "wkret.zawias.3x16",
                    active: active
                )
            result.append(
                DoborOkuciaWyceny(
                    item: wkretZawias,
                    typ: .wkręt,
                    ilosc:
                        Double(
                            projekt
                                .liczbaZawiasow
                                * 2
                        ),
                    fallbackCenaNetto:
                        0.073,  // 0,09 brutto / 1,23
                    opisZastosowania:
                        "Wkręty 3,5×16 mm do zawiasów — 2 szt. na zawias."
                )
            )
        }

        // MARK: - Wkręty Matrix Pro + łączniki 30 mm (per moduł)

        if projekt.liczbaModulow > 0 {
            let wkretMatrix =
                itemByProfile(
                    id: "wkret.matrix.pro",
                    active: active
                )
            result.append(
                DoborOkuciaWyceny(
                    item: wkretMatrix,
                    typ: .wkręt,
                    ilosc:
                        Double(
                            projekt
                                .liczbaModulow
                                * 4
                        ),
                    fallbackCenaNetto:
                        0.154,  // 0,19 brutto / 1,23
                    opisZastosowania:
                        "Wkręty Matrix Pro 4,2×16 mm — 4 szt. na moduł (prowadnice, listwy, AGD)."
                )
            )

            let wkretLacznik =
                itemByProfile(
                    id: "wkret.lacznik.3x30",
                    active: active
                )
            result.append(
                DoborOkuciaWyceny(
                    item: wkretLacznik,
                    typ: .wkręt,
                    ilosc:
                        Double(
                            projekt
                                .liczbaModulow
                                * 10
                        ),
                    fallbackCenaNetto:
                        0.049,  // 0,06 brutto / 1,23
                    opisZastosowania:
                        "Wkręty łącznikowe 3,5×30 mm — 10 szt. na moduł."
                )
            )

            result.append(
                selection(
                    typ: .klej,
                    quantity:
                        max(
                            1,
                            ceil(
                                Double(
                                    projekt
                                        .liczbaModulow
                                )
                                / 5
                            )
                        ),
                    fallback: 32,
                    description:
                        "Chemia montażowa i kleje.",
                    variant: wariant,
                    active: active
                )
            )
        }

        // MARK: - Oświetlenie LED (taśma + zasilacz)

        if projekt.metryBiezaceZabudowy > 0 {
            let ledMB =
                projekt.metryBiezaceZabudowy
                * 0.6  // szacunek: 60% zabudowy z LED
            if ledMB >= 0.5 {
                let tasmaItem =
                    itemByProfile(
                        id: "tasma.led.neutral",
                        active: active
                    )
                result.append(
                    DoborOkuciaWyceny(
                        item: tasmaItem,
                        typ: .oswietlenieLED,
                        ilosc: ceil(ledMB),
                        fallbackCenaNetto:
                            8.94,  // 11,00 brutto / 1,23
                        opisZastosowania:
                            "Taśma LED neutral white — szacunek 60% metrażu zabudowy."
                    )
                )

                let zasilaczItem =
                    itemByProfile(
                        id: "zasilacz.led.30w",
                        active: active
                    )
                result.append(
                    DoborOkuciaWyceny(
                        item: zasilaczItem,
                        typ: .oswietlenieLED,
                        ilosc:
                            max(
                                1,
                                ceil(
                                    ledMB / 2.5
                                )
                            ),
                        fallbackCenaNetto:
                            32.52,  // 40,00 brutto / 1,23
                        opisZastosowania:
                            "Zasilacz LED 12 V/30 W — 1 szt. na ok. 2,5 mb taśmy."
                    )
                )
            }
        }

        // MARK: - Obrzeże ABS (3,5 mb na 1 m² płyty)

        if projekt.metryKrawedziBanding > 0 {
            let isHighEnd =
                wariant == .premium
                || wariant == .vip
            let profileID =
                isHighEnd
                ? "obrzeze.abs.premium"
                : "obrzeze.abs.standard"
            let obrzezeItem =
                itemByProfile(
                    id: profileID,
                    active: active
                )
            result.append(
                DoborOkuciaWyceny(
                    item: obrzezeItem,
                    typ: .inne,
                    ilosc:
                        ceil(
                            projekt
                                .metryKrawedziBanding
                        ),
                    fallbackCenaNetto:
                        isHighEnd
                        ? 14.63  // 18,00 brutto / 1,23
                        : 2.85,  // 3,50 brutto / 1,23
                    opisZastosowania:
                        "Obrzeże ABS — szacunek 3,5 mb na 1 m² płyty. +10% naddatek wliczony w zaokrąglenie."
                )
            )
        }

        // MARK: - Uchwyty meblowe (1 szt. / front)

        if projekt.liczbaFrontow > 0 {
            let isHighEnd =
                wariant == .premium
                || wariant == .vip
            let profileID =
                isHighEnd
                ? "uchwyt.bar.premium"
                : "uchwyt.bar.standard"
            let uchwytItem =
                itemByProfile(
                    id: profileID,
                    active: active
                )
            result.append(
                DoborOkuciaWyceny(
                    item: uchwytItem,
                    typ: .uchwyt,
                    ilosc:
                        Double(
                            projekt.liczbaFrontow
                        ),
                    fallbackCenaNetto:
                        isHighEnd
                        ? 28.46  // 35,00 brutto / 1,23
                        : 6.50,  // 8,00 brutto / 1,23
                    opisZastosowania:
                        "1 uchwyt na każdy front drzwiczek i szuflad."
                )
            )
        }

        return result
    }

    // Wyszukiwanie konkretnego akcesorium po ID profilu katalogowego
    private static func itemByProfile(
        id: String,
        active:
            [OkucieMeblowe]
    ) -> OkucieMeblowe? {
        active.first {
            $0.profilAkcesoriumID == id
        }
    }

    private static func preferredDrawerType(
        variant:
            WariantWyceny,
        active:
            [OkucieMeblowe]
    ) -> TypOkuciaMeblowego {
        let desired:
            PoziomWycenyOkucia =
                hardwareTier(
                    variant
                )

        let hasSystem =
            active.contains {
                $0.typ
                    == .systemSzuflad
                && $0.poziomWyceny
                    == desired
            }

        return hasSystem
        ? .systemSzuflad
        : .prowadnica
    }

    private static func selection(
        typ:
            TypOkuciaMeblowego,
        quantity: Double,
        fallback: Double,
        description: String,
        variant:
            WariantWyceny,
        active:
            [OkucieMeblowe]
    ) -> DoborOkuciaWyceny {
        let desiredTier =
            hardwareTier(
                variant
            )

        let candidates =
            active.filter {
                $0.typ == typ
            }

        let exactTier =
            candidates.filter {
                $0.poziomWyceny
                    == desiredTier
            }

        let selected =
            bestItem(
                from:
                    exactTier.isEmpty
                    ? candidates
                    : exactTier
            )

        return DoborOkuciaWyceny(
            item: selected,
            typ: typ,
            ilosc:
                max(
                    quantity,
                    0
                ),
            fallbackCenaNetto:
                fallback,
            opisZastosowania:
                description
        )
    }

    private static func bestItem(
        from items:
            [OkucieMeblowe]
    ) -> OkucieMeblowe? {
        items
            .filter {
                $0.cenaNettoPoRabacie
                    > 0
            }
            .sorted {
                lhs,
                rhs in

                if lhs.cenaNettoPoRabacie
                    == rhs.cenaNettoPoRabacie {
                    return lhs.nazwa
                        .localizedCaseInsensitiveCompare(
                            rhs.nazwa
                        )
                        == .orderedAscending
                }

                return lhs.cenaNettoPoRabacie
                    < rhs.cenaNettoPoRabacie
            }
            .first
    }

    private static func hardwareTier(
        _ variant:
            WariantWyceny
    ) -> PoziomWycenyOkucia {
        switch variant {
        case .eco:
            return .eco
        case .standard:
            return .standard
        case .premium:
            return .premium
        case .vip:
            return .vip
        }
    }
}
