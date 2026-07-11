import DomainCore
import Foundation

enum ObrobkiCNCEngineV073 {
    static func build(
        list: ListaFormatekProjektuV070,
        settings: UstawieniaObrobekCNCV073
    ) -> RaportObrobekCNCV073 {
        RaportObrobekCNCV073(
            nazwaProjektu: list.nazwaProjektu,
            dataUtworzenia: Date(),
            ustawienia: settings,
            pozycje: list.formatki.map { formatka in
                PozycjaObrobekCNCV073(
                    formatka: formatka,
                    operacje: generate(for: formatka, settings: settings)
                        .map { validated($0, for: formatka) }
                        .sorted(by: ObrobkiCNCOrderingV073.operacje)
                )
            }
        )
    }

    static func blankOperation(for formatka: FormatkaProjektuV070) -> OperacjaCNCV073 {
        OperacjaCNCV073(
            id: "\(formatka.id)|MANUAL|\(UUID().uuidString)",
            formatkaID: formatka.id,
            typ: .otworNieprzelotowy,
            powierzchnia: .stronaA,
            xMM: min(50, formatka.dlugoscMM / 2),
            yMM: min(50, formatka.szerokoscMM / 2),
            srednicaMM: 5,
            glebokoscMM: min(12, formatka.gruboscMM),
            dlugoscMM: nil,
            szerokoscMM: nil,
            liczbaPowtorzen: 1,
            rozstawMM: nil,
            kierunekPowtorzen: .wzdluzX,
            status: .doWeryfikacji,
            automatyczna: false,
            uwagi: "Operacja dodana ręcznie."
        )
    }

    static func validated(
        _ operation: OperacjaCNCV073,
        for formatka: FormatkaProjektuV070
    ) -> OperacjaCNCV073 {
        var result = operation
        if let message = validationMessage(operation, for: formatka) {
            result.status = .blad
            if result.uwagi.isEmpty {
                result.uwagi = message
            } else if !result.uwagi.contains(message) {
                result.uwagi += " \(message)"
            }
        }
        return result
    }

    static func validationMessage(
        _ operation: OperacjaCNCV073,
        for formatka: FormatkaProjektuV070
    ) -> String? {
        guard operation.xMM.isFinite, operation.yMM.isFinite,
              operation.glebokoscMM.isFinite,
              operation.xMM >= 0, operation.yMM >= 0,
              operation.glebokoscMM >= 0,
              operation.liczbaPowtorzen >= 1 else {
            return "Nieprawidłowe parametry liczbowe."
        }

        if operation.typ.wymagaSrednicy {
            guard let diameter = operation.srednicaMM,
                  diameter.isFinite, diameter > 0 else {
                return "Operacja wymaga dodatniej średnicy."
            }
        }

        if operation.typ.jestLiniowa {
            guard let length = operation.dlugoscMM,
                  let width = operation.szerokoscMM,
                  length.isFinite, width.isFinite,
                  length > 0, width > 0 else {
                return "Operacja liniowa wymaga długości i szerokości."
            }
        }

        if operation.liczbaPowtorzen > 1 {
            guard let pitch = operation.rozstawMM,
                  pitch.isFinite, pitch > 0 else {
                return "Powtórzenia wymagają dodatniego rozstawu."
            }
        }

        let end = endpoint(operation)
        switch operation.powierzchnia {
        case .stronaA, .stronaB:
            guard operation.xMM <= formatka.dlugoscMM,
                  operation.yMM <= formatka.szerokoscMM,
                  end.x <= formatka.dlugoscMM,
                  end.y <= formatka.szerokoscMM else {
                return "Operacja wychodzi poza powierzchnię formatki."
            }
            if operation.glebokoscMM > formatka.gruboscMM {
                return "Głębokość przekracza grubość formatki."
            }
            if operation.typ.jestLiniowa,
               let length = operation.dlugoscMM,
               let width = operation.szerokoscMM,
               operation.xMM + length > formatka.dlugoscMM
                || operation.yMM + width > formatka.szerokoscMM {
                return "Obróbka liniowa wychodzi poza formatkę."
            }
        case .krawedzDlugaA, .krawedzDlugaB:
            if operation.xMM > formatka.dlugoscMM || end.x > formatka.dlugoscMM {
                return "Operacja wychodzi poza długą krawędź."
            }
        case .krawedzKrotkaA, .krawedzKrotkaB:
            if operation.xMM > formatka.szerokoscMM || end.x > formatka.szerokoscMM {
                return "Operacja wychodzi poza krótką krawędź."
            }
        }
        return nil
    }

    private static func generate(
        for formatka: FormatkaProjektuV070,
        settings: UstawieniaObrobekCNCV073
    ) -> [OperacjaCNCV073] {
        var result: [OperacjaCNCV073] = []
        if settings.generujSystem32 { result += system32(for: formatka, settings: settings) }
        if settings.generujRowekPlecy { result += backGroove(for: formatka, settings: settings) }
        if settings.generujLaczeniaKorpusu { result += joints(for: formatka, settings: settings) }
        if settings.generujPuszkiZawiasow { result += hinges(for: formatka, settings: settings) }
        return result
    }

    private static func system32(
        for formatka: FormatkaProjektuV070,
        settings: UstawieniaObrobekCNCV073
    ) -> [OperacjaCNCV073] {
        guard formatka.rolaKomponentu == .side || formatka.rolaKomponentu == .divider else { return [] }
        let available = formatka.dlugoscMM - 2 * settings.pierwszyOtworMM
        guard available >= 0,
              formatka.szerokoscMM > 2 * settings.odsuniecieSystem32MM else { return [] }
        let count = max(1, Int(floor(available / settings.skokSystem32MM)) + 1)
        return [
            repeatedHole(
                formatka, suffix: "SYS32-F", type: .rzadSystem32, surface: .stronaA,
                x: settings.pierwszyOtworMM, y: settings.odsuniecieSystem32MM,
                diameter: settings.srednicaSystem32MM,
                depth: min(settings.glebokoscSystem32MM, formatka.gruboscMM),
                count: count, pitch: settings.skokSystem32MM,
                status: .gotowa, note: "Rząd przedni System 32."
            ),
            repeatedHole(
                formatka, suffix: "SYS32-T", type: .rzadSystem32, surface: .stronaA,
                x: settings.pierwszyOtworMM,
                y: formatka.szerokoscMM - settings.odsuniecieSystem32MM,
                diameter: settings.srednicaSystem32MM,
                depth: min(settings.glebokoscSystem32MM, formatka.gruboscMM),
                count: count, pitch: settings.skokSystem32MM,
                status: .gotowa, note: "Rząd tylny System 32."
            )
        ]
    }

    private static func backGroove(
        for formatka: FormatkaProjektuV070,
        settings: UstawieniaObrobekCNCV073
    ) -> [OperacjaCNCV073] {
        let roles: Set<FurnitureComponentRole> = [.side, .top, .bottom, .divider]
        guard roles.contains(formatka.rolaKomponentu),
              formatka.szerokoscMM > settings.odsuniecieRowkaMM + settings.szerokoscRowkaMM else { return [] }
        return [
            OperacjaCNCV073(
                id: stableID(formatka, "ROWEK-PLECY"),
                formatkaID: formatka.id,
                typ: .rowek,
                powierzchnia: .stronaA,
                xMM: 0,
                yMM: formatka.szerokoscMM - settings.odsuniecieRowkaMM - settings.szerokoscRowkaMM,
                srednicaMM: nil,
                glebokoscMM: min(settings.glebokoscRowkaMM, formatka.gruboscMM),
                dlugoscMM: formatka.dlugoscMM,
                szerokoscMM: settings.szerokoscRowkaMM,
                liczbaPowtorzen: 1,
                rozstawMM: nil,
                kierunekPowtorzen: .wzdluzX,
                status: .gotowa,
                automatyczna: true,
                uwagi: "Rowek pod plecy."
            )
        ]
    }

    private static func joints(
        for formatka: FormatkaProjektuV070,
        settings: UstawieniaObrobekCNCV073
    ) -> [OperacjaCNCV073] {
        let roles: Set<FurnitureComponentRole> = [.top, .bottom, .reinforcement, .rail]
        guard roles.contains(formatka.rolaKomponentu),
              formatka.szerokoscMM > 2 * settings.odsuniecieLaczeniaMM else { return [] }
        let pitch = formatka.szerokoscMM - 2 * settings.odsuniecieLaczeniaMM
        let note = "Potwierdź zgodność z wybranym systemem łączenia."
        return [
            repeatedHole(
                formatka, suffix: "KOLKI-KA", type: .kolkowanie, surface: .krawedzKrotkaA,
                x: settings.odsuniecieLaczeniaMM, y: 0,
                diameter: settings.srednicaKolkaMM, depth: settings.glebokoscKolkaMM,
                count: 2, pitch: pitch, status: .doWeryfikacji, note: note
            ),
            repeatedHole(
                formatka, suffix: "KOLKI-KB", type: .kolkowanie, surface: .krawedzKrotkaB,
                x: settings.odsuniecieLaczeniaMM, y: 0,
                diameter: settings.srednicaKolkaMM, depth: settings.glebokoscKolkaMM,
                count: 2, pitch: pitch, status: .doWeryfikacji, note: note
            )
        ]
    }

    private static func hinges(
        for formatka: FormatkaProjektuV070,
        settings: UstawieniaObrobekCNCV073
    ) -> [OperacjaCNCV073] {
        guard formatka.rolaKomponentu == .front,
              formatka.dlugoscMM >= 2 * settings.puszkaOdKoncaMM,
              formatka.szerokoscMM > settings.osPuszkiOdKrawedziMM else { return [] }

        let count: Int
        switch formatka.dlugoscMM {
        case ..<900: count = 2
        case ..<1500: count = 3
        case ..<2100: count = 4
        default: count = 5
        }

        let edge = inferredHingeEdge(formatka.kodKomponentu)
        let y = edge == .krawedzDlugaB
            ? formatka.szerokoscMM - settings.osPuszkiOdKrawedziMM
            : settings.osPuszkiOdKrawedziMM
        let pitch = count > 1
            ? (formatka.dlugoscMM - 2 * settings.puszkaOdKoncaMM) / Double(count - 1)
            : 0
        let status: StatusOperacjiCNCV073 = edge == nil ? .doWeryfikacji : .gotowa
        let note = edge == nil
            ? "Nie rozpoznano strony zawiasów z kodu frontu."
            : "Strona zawiasów rozpoznana z kodu komponentu."

        return (0..<count).map { index in
            OperacjaCNCV073(
                id: stableID(formatka, "PUSZKA-\(index + 1)"),
                formatkaID: formatka.id,
                typ: .puszkaZawiasu,
                powierzchnia: .stronaA,
                xMM: settings.puszkaOdKoncaMM + Double(index) * pitch,
                yMM: y,
                srednicaMM: settings.srednicaPuszkiMM,
                glebokoscMM: min(settings.glebokoscPuszkiMM, formatka.gruboscMM),
                dlugoscMM: nil,
                szerokoscMM: nil,
                liczbaPowtorzen: 1,
                rozstawMM: nil,
                kierunekPowtorzen: .wzdluzX,
                status: status,
                automatyczna: true,
                uwagi: note
            )
        }
    }

    private static func inferredHingeEdge(_ code: String) -> PowierzchniaObrobkiV073? {
        let tokens = Set(
            code.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "pl_PL"))
                .uppercased()
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
        )
        if !tokens.isDisjoint(with: ["L", "LEWY", "LEWA", "LEFT"]) { return .krawedzDlugaA }
        if !tokens.isDisjoint(with: ["P", "R", "PRAWY", "PRAWA", "RIGHT"]) { return .krawedzDlugaB }
        return nil
    }

    private static func repeatedHole(
        _ formatka: FormatkaProjektuV070,
        suffix: String,
        type: TypOperacjiCNCV073,
        surface: PowierzchniaObrobkiV073,
        x: Double,
        y: Double,
        diameter: Double,
        depth: Double,
        count: Int,
        pitch: Double,
        status: StatusOperacjiCNCV073,
        note: String
    ) -> OperacjaCNCV073 {
        OperacjaCNCV073(
            id: stableID(formatka, suffix),
            formatkaID: formatka.id,
            typ: type,
            powierzchnia: surface,
            xMM: x,
            yMM: y,
            srednicaMM: diameter,
            glebokoscMM: depth,
            dlugoscMM: nil,
            szerokoscMM: nil,
            liczbaPowtorzen: max(1, count),
            rozstawMM: count > 1 ? pitch : nil,
            kierunekPowtorzen: .wzdluzX,
            status: status,
            automatyczna: true,
            uwagi: note
        )
    }

    private static func stableID(_ formatka: FormatkaProjektuV070, _ suffix: String) -> String {
        "\(formatka.id)|CNC|\(suffix)"
    }

    private static func endpoint(_ operation: OperacjaCNCV073) -> (x: Double, y: Double) {
        guard operation.liczbaPowtorzen > 1, let pitch = operation.rozstawMM else {
            return (operation.xMM, operation.yMM)
        }
        let distance = Double(operation.liczbaPowtorzen - 1) * pitch
        return operation.kierunekPowtorzen == .wzdluzX
            ? (operation.xMM + distance, operation.yMM)
            : (operation.xMM, operation.yMM + distance)
    }
}
