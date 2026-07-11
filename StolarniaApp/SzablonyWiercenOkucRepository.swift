import Combine
import Foundation

@MainActor
final class SzablonyWiercenOkucRepository:
    ObservableObject
{
    @Published private(set) var templates:
        [SzablonWierceniaOkucia] = []

    private let defaults:
        UserDefaults
    private let key =
        "stolarnia.szablony.wiercen.okuc.v1"

    init(
        defaults:
            UserDefaults = .standard
    ) {
        self.defaults = defaults
        load()

        if templates.isEmpty {
            seedDefaults()
        }
    }

    func activeTemplates(
        for type:
            TypPunktuWiercenia
    ) -> [SzablonWierceniaOkucia] {
        templates
            .filter {
                $0.aktywny
                && $0.typ == type
            }
            .sorted {
                $0.nazwa
                    .localizedCaseInsensitiveCompare(
                        $1.nazwa
                    )
                == .orderedAscending
            }
    }

    func upsert(
        _ template:
            SzablonWierceniaOkucia
    ) {
        if let index =
            templates.firstIndex(
                where: {
                    $0.id == template.id
                }
            ) {
            templates[index] = template
        } else {
            templates.append(template)
        }

        save()
    }

    func delete(
        id: UUID
    ) {
        templates.removeAll {
            $0.id == id
        }

        save()
    }

    func reload() {
        load()
    }

    private func load() {
        guard let data =
            defaults.data(
                forKey: key
            )
        else {
            templates = []
            return
        }

        do {
            templates =
                try JSONDecoder()
                    .decode(
                        [SzablonWierceniaOkucia].self,
                        from: data
                    )
        } catch {
            templates = []
        }
    }

    private func save() {
        guard let data =
            try? JSONEncoder()
                .encode(templates)
        else {
            return
        }

        defaults.set(
            data,
            forKey: key
        )
    }

    private func seedDefaults() {
        templates = [
            SzablonWierceniaOkucia(
                kodOkucia:
                    "PROWADNICA-37",
                nazwa:
                    "Prowadnica — linia 37 mm",
                producent:
                    "Uniwersalny",
                typ:
                    .prowadnica,
                elementDocelowy:
                    "Bok",
                strona:
                    .wewnetrzna,
                orientacja:
                    .pozioma,
                punktBazowyXMM:
                    37,
                punktBazowyYMM:
                    0,
                punkty: [
                    PunktSzablonuWiercenia(
                        odsunXMM: 0,
                        odsunYMM: 0,
                        srednicaMM: 5,
                        glebokoscMM: 12,
                        opis:
                            "Pierwszy punkt montażowy."
                    ),
                    PunktSzablonuWiercenia(
                        odsunXMM: 96,
                        odsunYMM: 0,
                        srednicaMM: 5,
                        glebokoscMM: 12,
                        opis:
                            "Drugi punkt montażowy."
                    ),
                    PunktSzablonuWiercenia(
                        odsunXMM: 224,
                        odsunYMM: 0,
                        srednicaMM: 5,
                        glebokoscMM: 12,
                        opis:
                            "Trzeci punkt montażowy."
                    )
                ],
                aktywny: true,
                uwagi:
                    "Szablon ogólny. Przed produkcją sprawdź dokumentację konkretnej prowadnicy."
            ),
            SzablonWierceniaOkucia(
                kodOkucia:
                    "ZAWIAS-35",
                nazwa:
                    "Zawias puszkowy Ø35",
                producent:
                    "Uniwersalny",
                typ:
                    .zawias,
                elementDocelowy:
                    "Front",
                strona:
                    .wewnetrzna,
                orientacja:
                    .pionowa,
                punktBazowyXMM:
                    22,
                punktBazowyYMM:
                    100,
                punkty: [
                    PunktSzablonuWiercenia(
                        odsunXMM: 0,
                        odsunYMM: 0,
                        srednicaMM: 35,
                        glebokoscMM: 13,
                        opis:
                            "Puszka zawiasu."
                    )
                ],
                aktywny: true,
                uwagi:
                    "Odsuw puszki od krawędzi należy potwierdzić dla wybranego zawiasu."
            ),
            SzablonWierceniaOkucia(
                kodOkucia:
                    "POLKA-32",
                nazwa:
                    "Podpory półki — system 32",
                producent:
                    "Uniwersalny",
                typ:
                    .podporaPolki,
                elementDocelowy:
                    "Bok",
                strona:
                    .wewnetrzna,
                orientacja:
                    .pionowa,
                punktBazowyXMM:
                    37,
                punktBazowyYMM:
                    96,
                punkty: [
                    PunktSzablonuWiercenia(
                        odsunXMM: 0,
                        odsunYMM: 0,
                        srednicaMM: 5,
                        glebokoscMM: 12,
                        opis:
                            "Pierwszy punkt systemu 32."
                    ),
                    PunktSzablonuWiercenia(
                        odsunXMM: 0,
                        odsunYMM: 32,
                        srednicaMM: 5,
                        glebokoscMM: 12,
                        opis:
                            "Kolejny punkt systemu 32."
                    ),
                    PunktSzablonuWiercenia(
                        odsunXMM: 0,
                        odsunYMM: 64,
                        srednicaMM: 5,
                        glebokoscMM: 12,
                        opis:
                            "Kolejny punkt systemu 32."
                    )
                ],
                aktywny: true,
                uwagi:
                    "Uniwersalny przykład systemu 32."
            )
        ]

        save()
    }
}
