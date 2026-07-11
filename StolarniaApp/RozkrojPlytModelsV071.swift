import Foundation

struct UstawieniaRozkrojuPlytV071:
    Hashable
{
    var szerokoscArkuszaMM: Double
    var dlugoscArkuszaMM: Double
    var rzazMM: Double
    var marginesMM: Double
    var uwzgledniajKierunekDekoru: Bool

    static let standard = Self(
        szerokoscArkuszaMM: 2_070,
        dlugoscArkuszaMM: 2_800,
        rzazMM: 3.2,
        marginesMM: 10,
        uwzgledniajKierunekDekoru: true
    )

    var poprawne: Bool {
        szerokoscArkuszaMM > 0
            && dlugoscArkuszaMM > 0
            && rzazMM >= 0
            && marginesMM >= 0
            && szerokoscArkuszaMM > marginesMM * 2
            && dlugoscArkuszaMM > marginesMM * 2
            && [
                szerokoscArkuszaMM,
                dlugoscArkuszaMM,
                rzazMM,
                marginesMM
            ]
            .allSatisfy(\.isFinite)
    }

    var powierzchniaArkuszaM2: Double {
        szerokoscArkuszaMM
            * dlugoscArkuszaMM
            / 1_000_000
    }
}

struct KluczGrupyRozkrojuV071:
    Hashable,
    Identifiable
{
    var material: MaterialFormatkiV070
    var gruboscMM: Double

    init(
        material: MaterialFormatkiV070,
        gruboscMM: Double
    ) {
        self.material = material
        self.gruboscMM =
            (gruboscMM * 100).rounded()
            / 100
    }

    var id: String {
        "\(material.id)|\(gruboscMM.rounded(toPlaces: 2))"
    }

    var opis: String {
        "\(material.opis), \(gruboscMM.formatted(.number.precision(.fractionLength(0...1)))) mm"
    }
}

struct PolozenieFormatkiV071:
    Identifiable,
    Hashable
{
    var id: String {
        "\(formatka.id)|\(xMM.rounded(toPlaces: 2))|\(yMM.rounded(toPlaces: 2))"
    }

    var formatka: FormatkaProjektuV070
    var xMM: Double
    var yMM: Double
    var szerokoscNaArkuszuMM: Double
    var dlugoscNaArkuszuMM: Double
    var obrocona: Bool
}

struct ArkuszRozkrojuV071:
    Identifiable,
    Hashable
{
    var id: String
    var numer: Int
    var grupa: KluczGrupyRozkrojuV071
    var szerokoscMM: Double
    var dlugoscMM: Double
    var polozenia: [PolozenieFormatkiV071]

    var powierzchniaArkuszaM2: Double {
        szerokoscMM
            * dlugoscMM
            / 1_000_000
    }

    var powierzchniaFormatekM2: Double {
        polozenia.reduce(0) {
            $0 + $1.formatka.powierzchniaM2
        }
    }

    var wykorzystanieProcent: Double {
        guard powierzchniaArkuszaM2 > 0 else {
            return 0
        }

        return min(
            100,
            powierzchniaFormatekM2
                / powierzchniaArkuszaM2
                * 100
        )
    }

    var odpadM2: Double {
        max(
            0,
            powierzchniaArkuszaM2
                - powierzchniaFormatekM2
        )
    }
}

struct NierozmieszczonaFormatkaV071:
    Identifiable,
    Hashable
{
    var id: String { formatka.id }
    var formatka: FormatkaProjektuV070
    var powod: String
}

struct ZapotrzebowaniePlytyV071:
    Identifiable,
    Hashable
{
    var grupa: KluczGrupyRozkrojuV071
    var liczbaArkuszy: Int
    var formatArkusza: String
    var powierzchniaFormatekM2: Double
    var powierzchniaZakupuM2: Double
    var odpadM2: Double
    var wykorzystanieProcent: Double

    var id: String { grupa.id }
}

struct RaportRozkrojuPlytV071:
    Hashable
{
    var nazwaProjektu: String
    var dataUtworzenia: Date
    var ustawienia: UstawieniaRozkrojuPlytV071
    var arkusze: [ArkuszRozkrojuV071]
    var nierozmieszczone: [NierozmieszczonaFormatkaV071]

    var liczbaArkuszy: Int {
        arkusze.count
    }

    var liczbaRozmieszczonychFormatek: Int {
        arkusze.reduce(0) {
            $0 + $1.polozenia.count
        }
    }

    var powierzchniaFormatekM2: Double {
        arkusze.reduce(0) {
            $0 + $1.powierzchniaFormatekM2
        }
    }

    var powierzchniaArkuszyM2: Double {
        arkusze.reduce(0) {
            $0 + $1.powierzchniaArkuszaM2
        }
    }

    var wykorzystanieProcent: Double {
        guard powierzchniaArkuszyM2 > 0 else {
            return 0
        }

        return min(
            100,
            powierzchniaFormatekM2
                / powierzchniaArkuszyM2
                * 100
        )
    }

    var odpadM2: Double {
        max(
            0,
            powierzchniaArkuszyM2
                - powierzchniaFormatekM2
        )
    }

    var zapotrzebowanie: [ZapotrzebowaniePlytyV071] {
        let grouped = Dictionary(
            grouping: arkusze,
            by: \.grupa
        )

        return grouped.map {
            group,
            sheets in

            let partArea = sheets.reduce(0) {
                $0 + $1.powierzchniaFormatekM2
            }
            let purchaseArea = sheets.reduce(0) {
                $0 + $1.powierzchniaArkuszaM2
            }
            let usage = purchaseArea > 0
                ? partArea / purchaseArea * 100
                : 0

            return ZapotrzebowaniePlytyV071(
                grupa: group,
                liczbaArkuszy: sheets.count,
                formatArkusza:
                    "\(formatMM(ustawienia.dlugoscArkuszaMM)) × \(formatMM(ustawienia.szerokoscArkuszaMM)) mm",
                powierzchniaFormatekM2: partArea,
                powierzchniaZakupuM2: purchaseArea,
                odpadM2: max(
                    0,
                    purchaseArea - partArea
                ),
                wykorzystanieProcent: usage
            )
        }
        .sorted {
            $0.grupa.opis.localizedStandardCompare(
                $1.grupa.opis
            ) == .orderedAscending
        }
    }

    private func formatMM(_ value: Double) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: "pl_PL"))
                .grouping(.never)
                .precision(.fractionLength(0...1))
        )
    }
}

private extension Double {
    func rounded(
        toPlaces places: Int
    ) -> Double {
        let factor = pow(
            10,
            Double(max(0, places))
        )
        return (self * factor).rounded() / factor
    }
}
