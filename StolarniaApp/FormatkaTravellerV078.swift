import Combine
import Foundation
import os

enum StatusFormatkiV078:
    String,
    CaseIterable,
    Codable,
    Hashable,
    Identifiable
{
    case doCiecia
    case wycieta
    case oklejanie
    case oklejona
    case cnc
    case poCNC
    case wPaczce
    case gotowa
    case defekt
    case recut

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .doCiecia:
            return "Do cięcia"
        case .wycieta:
            return "Wycięta"
        case .oklejanie:
            return "Oklejanie"
        case .oklejona:
            return "Oklejona"
        case .cnc:
            return "CNC"
        case .poCNC:
            return "Po CNC"
        case .wPaczce:
            return "W paczce"
        case .gotowa:
            return "Gotowa"
        case .defekt:
            return "Defekt"
        case .recut:
            return "Recut"
        }
    }

    var symbol: String {
        switch self {
        case .doCiecia:
            return "saw"
        case .wycieta:
            return "checkmark.square"
        case .oklejanie:
            return "rectangle.compress.vertical"
        case .oklejona:
            return "checkmark.seal"
        case .cnc:
            return "gearshape.2"
        case .poCNC:
            return "gearshape.2.fill"
        case .wPaczce:
            return "shippingbox"
        case .gotowa:
            return "checkmark.circle.fill"
        case .defekt:
            return "exclamationmark.triangle.fill"
        case .recut:
            return "arrow.triangle.2.circlepath"
        }
    }

    var opis: String {
        switch self {
        case .doCiecia:
            return "Element czeka na rozkrój."
        case .wycieta:
            return "Element został wycięty z płyty."
        case .oklejanie:
            return "Element jest na etapie okleinowania."
        case .oklejona:
            return "Krawędzie zostały oklejone."
        case .cnc:
            return "Element czeka na obróbki CNC."
        case .poCNC:
            return "Obróbki CNC są zakończone."
        case .wPaczce:
            return "Element trafił do paczki."
        case .gotowa:
            return "Element jest gotowy produkcyjnie."
        case .defekt:
            return "Element wymaga decyzji po wykryciu defektu."
        case .recut:
            return "Element został skierowany do ponownego cięcia."
        }
    }

    var blokujePrzekazanie: Bool {
        switch self {
        case .defekt,
             .recut:
            return true
        default:
            return false
        }
    }

    var gotowaDoPakowaniaV078: Bool {
        switch self {
        case .wycieta,
             .oklejona,
             .poCNC,
             .wPaczce,
             .gotowa:
            return true
        case .doCiecia,
             .oklejanie,
             .cnc,
             .defekt,
             .recut:
            return false
        }
    }

    static let szybkaSciezka: [StatusFormatkiV078] = [
        .doCiecia,
        .wycieta,
        .oklejona,
        .poCNC,
        .wPaczce,
        .gotowa
    ]
}

enum RodzajZdarzeniaFormatkiV078:
    String,
    Codable,
    Hashable
{
    case utworzenie
    case status
    case defekt
    case recut
    case notatka

    var nazwa: String {
        switch self {
        case .utworzenie:
            return "Utworzenie"
        case .status:
            return "Status"
        case .defekt:
            return "Defekt"
        case .recut:
            return "Recut"
        case .notatka:
            return "Notatka"
        }
    }
}

struct ZdarzenieFormatkiV078:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var data = Date()
    var typ: RodzajZdarzeniaFormatkiV078
    var status: StatusFormatkiV078
    var opis: String
}

struct TravellerFormatkiV078:
    Identifiable,
    Codable,
    Hashable
{
    var formatkaID: String
    var identyfikatorProdukcyjny: String
    var etykieta: String
    var nazwaModulu: String
    var kodKomponentu: String
    var materialOpis: String
    var opisWymiaru: String
    var status: StatusFormatkiV078
    var notatka: String
    var opisProblemu: String
    var liczbaRecut: Int
    var dataUtworzenia: Date
    var dataAktualizacji: Date
    var historia: [ZdarzenieFormatkiV078]

    var id: String { formatkaID }

    init(
        formatka: FormatkaProjektuV070
    ) {
        let teraz = Date()

        self.formatkaID = formatka.id
        self.identyfikatorProdukcyjny =
            formatka.identyfikatorProdukcyjnyV078
        self.etykieta = formatka.etykieta
        self.nazwaModulu = formatka.nazwaModulu
        self.kodKomponentu = formatka.kodKomponentu
        self.materialOpis = formatka.material.opis
        self.opisWymiaru = formatka.opisWymiaru
        self.status = .doCiecia
        self.notatka = ""
        self.opisProblemu = ""
        self.liczbaRecut = 0
        self.dataUtworzenia = teraz
        self.dataAktualizacji = teraz
        self.historia = [
            ZdarzenieFormatkiV078(
                data: teraz,
                typ: .utworzenie,
                status: .doCiecia,
                opis: "Utworzono kartę produkcyjną formatki."
            )
        ]
    }

    mutating func odswiezMetadane(
        z formatka:
            FormatkaProjektuV070
    ) -> Bool {
        var changed = false

        func update<Value: Equatable>(
            _ keyPath:
                WritableKeyPath<TravellerFormatkiV078, Value>,
            _ value: Value
        ) {
            if self[keyPath: keyPath] != value {
                self[keyPath: keyPath] = value
                changed = true
            }
        }

        update(
            \.identyfikatorProdukcyjny,
            formatka.identyfikatorProdukcyjnyV078
        )
        update(
            \.etykieta,
            formatka.etykieta
        )
        update(
            \.nazwaModulu,
            formatka.nazwaModulu
        )
        update(
            \.kodKomponentu,
            formatka.kodKomponentu
        )
        update(
            \.materialOpis,
            formatka.material.opis
        )
        update(
            \.opisWymiaru,
            formatka.opisWymiaru
        )

        if changed {
            dataAktualizacji = Date()
        }

        return changed
    }

    mutating func dodajZdarzenie(
        typ: RodzajZdarzeniaFormatkiV078,
        status nowyStatus: StatusFormatkiV078,
        opis: String
    ) {
        status = nowyStatus
        dataAktualizacji = Date()

        historia.insert(
            ZdarzenieFormatkiV078(
                data: dataAktualizacji,
                typ: typ,
                status: nowyStatus,
                opis: opis
            ),
            at: 0
        )
    }
}

@MainActor
final class FormatkaTravellerRepositoryV078:
    ObservableObject
{
    @Published private(set) var travellers:
        [String: TravellerFormatkiV078] = [:]
    @Published private(set) var komunikatIntegralnosci:
        String?

    private let defaults: UserDefaults
    private let key =
        "stolarnia.formatki.traveller.v078"
    private let backupKey =
        "stolarnia.formatki.traveller.v078.backup"

    init(
        defaults:
            UserDefaults = .standard
    ) {
        self.defaults = defaults

        let result =
            BezpiecznyMagazynJSON.wczytaj(
                [String: TravellerFormatkiV078].self,
                defaults: defaults,
                key: key,
                backupKey: backupKey,
                wartoscDomyslna: [:]
            )

        self.travellers = result.wartosc
        self.komunikatIntegralnosci =
            result.komunikat
    }

    func podglad(
        dla formatka:
            FormatkaProjektuV070
    ) -> TravellerFormatkiV078 {
        guard var traveller =
                travellers[formatkiID(formatka)]
        else {
            return TravellerFormatkiV078(
                formatka: formatka
            )
        }

        _ = traveller.odswiezMetadane(
            z: formatka
        )
        return traveller
    }

    func ustawStatus(
        _ status: StatusFormatkiV078,
        dla formatka: FormatkaProjektuV070,
        opis: String? = nil
    ) {
        var traveller =
            podglad(dla: formatka)

        let trimmed =
            opis?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            ?? ""
        let eventDescription =
            trimmed.isEmpty
            ? status.opis
            : trimmed

        traveller.dodajZdarzenie(
            typ: RodzajZdarzeniaFormatkiV078
                .status,
            status: status,
            opis: eventDescription
        )

        zapisz(
            traveller
        )
    }

    func zglosDefekt(
        dla formatka:
            FormatkaProjektuV070,
        opis: String
    ) {
        var traveller =
            podglad(dla: formatka)
        let trimmed =
            opis.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        let description =
            trimmed.isEmpty
            ? "Zgłoszono defekt do decyzji technologicznej."
            : trimmed

        traveller.opisProblemu =
            description
        traveller.dodajZdarzenie(
            typ: .defekt,
            status: .defekt,
            opis: description
        )

        zapisz(
            traveller
        )
    }

    func zlecRecut(
        dla formatka:
            FormatkaProjektuV070,
        opis: String
    ) {
        var traveller =
            podglad(dla: formatka)
        let trimmed =
            opis.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        let description =
            trimmed.isEmpty
            ? "Skierowano formatkę do ponownego cięcia."
            : trimmed

        traveller.liczbaRecut += 1
        traveller.opisProblemu =
            description
        traveller.dodajZdarzenie(
            typ: .recut,
            status: .recut,
            opis: description
        )

        zapisz(
            traveller
        )
    }

    func zapiszNotatke(
        dla formatka:
            FormatkaProjektuV070,
        notatka: String
    ) {
        var traveller =
            podglad(dla: formatka)
        let trimmed =
            notatka.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        traveller.notatka = trimmed
        traveller.dodajZdarzenie(
            typ: .notatka,
            status: traveller.status,
            opis: trimmed.isEmpty
                ? "Wyczyszczono notatkę operatora."
                : trimmed
        )

        zapisz(
            traveller
        )
    }

    func liczbaStatusow(
        _ status:
            StatusFormatkiV078,
        w formatkach:
            [FormatkaProjektuV070]
    ) -> Int {
        formatkach.reduce(
            0
        ) {
            partial,
            formatka in

            partial
                + (
                    podglad(dla: formatka).status
                        == status
                    ? 1
                    : 0
                )
        }
    }

    private func zapisz(
        _ traveller:
            TravellerFormatkiV078
    ) {
        travellers[traveller.formatkaID] =
            traveller
        persist()
    }

    private func persist() {
        do {
            try BezpiecznyMagazynJSON.zapisz(
                travellers,
                defaults: defaults,
                key: key,
                backupKey: backupKey
            )
        } catch {
            StolarniaLogger.zapis.error(
                "Nie udało się zapisać statusów formatek: \(error.localizedDescription)"
            )
        }
    }

    private func formatkiID(
        _ formatka:
            FormatkaProjektuV070
    ) -> String {
        formatka.id
    }
}
