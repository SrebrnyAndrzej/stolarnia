import DomainCore
import Foundation
import Persistence

enum KategoriaFormatkiV070:
    String,
    CaseIterable,
    Codable,
    Hashable,
    Identifiable
{
    case korpus
    case front
    case plecy
    case blat
    case cokół
    case maskownice
    case pozostale

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .korpus:
            return "Korpus"
        case .front:
            return "Front"
        case .plecy:
            return "Plecy"
        case .blat:
            return "Blat"
        case .cokół:
            return "Cokół"
        case .maskownice:
            return "Maskownice"
        case .pozostale:
            return "Pozostałe"
        }
    }

    var systemImage: String {
        switch self {
        case .korpus:
            return "square.stack.3d.up"
        case .front:
            return "rectangle.split.2x1"
        case .plecy:
            return "rectangle.portrait"
        case .blat:
            return "rectangle"
        case .cokół:
            return "rectangle.bottomhalf.filled"
        case .maskownice:
            return "rectangle.compress.vertical"
        case .pozostale:
            return "square.dashed"
        }
    }
}

enum KierunekDekoruV070:
    String,
    Codable,
    Hashable
{
    case dowolny
    case wzdluzDlugosci

    var nazwa: String {
        switch self {
        case .dowolny:
            return "Dowolny"
        case .wzdluzDlugosci:
            return "Wzdłuż długości"
        }
    }
}

struct MaterialFormatkiV070:
    Codable,
    Hashable,
    Identifiable
{
    var kod: String
    var nazwa: String
    var producent: String
    var kolorHEX: String

    var id: String {
        [
            producent,
            kod,
            nazwa
        ]
        .map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }
        .joined(separator: "|")
    }

    var opis: String {
        let producent = producent.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let kod = kod.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if producent.isEmpty {
            return kod.isEmpty ? nazwa : "\(kod) — \(nazwa)"
        }

        return kod.isEmpty
            ? "\(producent) — \(nazwa)"
            : "\(producent) \(kod) — \(nazwa)"
    }
}

struct FormatkaProjektuV070:
    Identifiable,
    Hashable
{
    var id: String
    var etykieta: String
    var indeksModulu: Int
    var nazwaModulu: String
    var kodKomponentu: String
    var rolaKomponentu: FurnitureComponentRole
    var kategoria: KategoriaFormatkiV070
    var material: MaterialFormatkiV070
    var dlugoscMM: Double
    var szerokoscMM: Double
    var gruboscMM: Double
    var kierunekDekoru: KierunekDekoruV070
    var wspoldzielona: Bool

    var powierzchniaM2: Double {
        dlugoscMM * szerokoscMM / 1_000_000
    }

    var opisWymiaru: String {
        "\(formatMM(dlugoscMM)) × \(formatMM(szerokoscMM)) × \(formatMM(gruboscMM)) mm"
    }

    var identyfikatorProdukcyjnyV078:
        String
    {
        let normalized =
            id
            .uppercased()
            .filter {
                $0.isLetter
                    || $0.isNumber
            }
        let suffix =
            String(
                normalized
                    .suffix(10)
            )

        return [
            etykieta,
            suffix.isEmpty
                ? "PART"
                : suffix
        ]
        .joined(separator: "-")
    }

    var qrPayloadV078:
        String
    {
        let fields = [
            "v=1",
            "type=formatka",
            "id=\(encodedV078(id))",
            "pid=\(encodedV078(identyfikatorProdukcyjnyV078))",
            "label=\(encodedV078(etykieta))",
            "module=\(encodedV078(nazwaModulu))",
            "component=\(encodedV078(kodKomponentu))",
            "material=\(encodedV078(material.opis))",
            "size=\(encodedV078(opisWymiaru))"
        ]

        return "stolarnia://production/part?"
            + fields.joined(
                separator: "&"
            )
    }

    private func formatMM(_ value: Double) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: "pl_PL"))
                .grouping(.never)
                .precision(.fractionLength(0...1))
        )
    }

    private func encodedV078(
        _ value: String
    ) -> String {
        value
            .addingPercentEncoding(
                withAllowedCharacters:
                    .urlQueryAllowed
            )
        ?? value
    }
}

struct ListaFormatekProjektuV070:
    Hashable
{
    var nazwaProjektu: String
    var dataUtworzenia: Date
    var formatki: [FormatkaProjektuV070]

    var liczbaFormatek: Int {
        formatki.count
    }

    var powierzchniaM2: Double {
        formatki.reduce(0) {
            $0 + $1.powierzchniaM2
        }
    }

    var materialy: [MaterialFormatkiV070] {
        Array(Set(formatki.map(\.material)))
            .sorted {
                $0.opis.localizedStandardCompare($1.opis)
                    == .orderedAscending
            }
    }
}

enum ListaFormatekProjektuBuilderV070 {
    static func build(
        projectName: String,
        assemblies: [StoredFurnitureAssembly],
        globalneMaterialy: GlobalneMaterialyPomieszczenia
    ) -> ListaFormatekProjektuV070 {
        let sortedAssemblies = assemblies.sorted(
            by: porzadekModulow
        )

        var result: [FormatkaProjektuV070] = []

        for (moduleOffset, stored) in sortedAssemblies.enumerated() {
            let moduleIndex = moduleOffset + 1
            let components =
                GeometriaSzuflad3DV068
                    .uzupelnioneKomponenty(
                        assembly:
                            stored
                            .assembly,
                        bazowe:
                            stored
                            .assembly
                            .components
                    )
                    .filter {
                        !(
                            $0.role == .rail
                            && GeometriaSzuflad3DV068
                                .jestElementemWygenerowanym(
                                    $0
                                )
                        )
                    }
                    .sorted {
                        if $0.role.rawValue == $1.role.rawValue {
                            if $0.code == $1.code {
                                return $0.id.description
                                    < $1.id.description
                            }
                            return $0.code.localizedStandardCompare($1.code)
                                == .orderedAscending
                        }

                        return $0.role.rawValue < $1.role.rawValue
                    }

            for (componentOffset, component) in components.enumerated() {
                guard let dimensions = dimensions(
                    for: component
                ) else {
                    continue
                }

                let category = category(
                    for: component.role
                )
                let material = material(
                    for: component.role,
                    globalneMaterialy: globalneMaterialy
                )
                let label = label(
                    moduleIndex: moduleIndex,
                    componentIndex: componentOffset + 1,
                    role: component.role
                )

                result.append(
                    FormatkaProjektuV070(
                        id: [
                            stored.id.description,
                            component.id.description
                        ]
                        .joined(separator: "|"),
                        etykieta: label,
                        indeksModulu: moduleIndex,
                        nazwaModulu: stored.assembly.name,
                        kodKomponentu: component.code,
                        rolaKomponentu: component.role,
                        kategoria: category,
                        material: material,
                        dlugoscMM: dimensions.length,
                        szerokoscMM: dimensions.width,
                        gruboscMM: dimensions.thickness,
                        kierunekDekoru: grain(
                            for: component.role
                        ),
                        wspoldzielona: component.isShared
                    )
                )
            }
        }

        return ListaFormatekProjektuV070(
            nazwaProjektu: projectName,
            dataUtworzenia: Date(),
            formatki: result
        )
    }

    private static func porzadekModulow(
        _ lhs: StoredFurnitureAssembly,
        _ rhs: StoredFurnitureAssembly
    ) -> Bool {
        let lhsWall =
            lhs.assembly.placement?.wallID?.description
            ?? ""
        let rhsWall =
            rhs.assembly.placement?.wallID?.description
            ?? ""

        if lhsWall != rhsWall {
            return lhsWall < rhsWall
        }

        let lhsOffset =
            lhs.assembly.placement?
                .offsetAlongWall
                .rawValue
            ?? 0
        let rhsOffset =
            rhs.assembly.placement?
                .offsetAlongWall
                .rawValue
            ?? 0

        if lhsOffset != rhsOffset {
            return lhsOffset < rhsOffset
        }

        if lhs.assembly.name != rhs.assembly.name {
            return lhs.assembly.name.localizedStandardCompare(
                rhs.assembly.name
            ) == .orderedAscending
        }

        return lhs.id.description < rhs.id.description
    }

    private struct PanelDimensions {
        var length: Double
        var width: Double
        var thickness: Double
    }

    private static func dimensions(
        for component: FurnitureComponent
    ) -> PanelDimensions? {
        let width = component.size.width.rawValue
        let height = component.size.height.rawValue
        let depth = component.size.depth.rawValue

        guard width > 0,
              height > 0,
              depth > 0,
              width.isFinite,
              height.isFinite,
              depth.isFinite else {
            return nil
        }

        let values: PanelDimensions

        switch component.role {
        case .side, .divider:
            values = PanelDimensions(
                length: height,
                width: depth,
                thickness: width
            )

        case .top,
             .bottom,
             .shelf,
             .worktop,
             .reinforcement,
             .rail:
            values = PanelDimensions(
                length: width,
                width: depth,
                thickness: height
            )

        case .back,
             .front,
             .plinth,
             .filler,
             .maskingPanel:
            values = PanelDimensions(
                length: height,
                width: width,
                thickness: depth
            )

        case .decorativeSide:
            // Wieniec boczny: długość=wysokość, szerokość=głębokość szafki, grubość=grubość panelu
            values = PanelDimensions(
                length: height,
                width: depth,
                thickness: width
            )

        case .leg, .custom:
            let sorted = [width, height, depth].sorted()
            values = PanelDimensions(
                length: sorted[2],
                width: sorted[1],
                thickness: sorted[0]
            )
        }

        guard values.length > 0,
              values.width > 0,
              values.thickness > 0 else {
            return nil
        }

        return values
    }

    private static func category(
        for role: FurnitureComponentRole
    ) -> KategoriaFormatkiV070 {
        switch role {
        case .side,
             .top,
             .bottom,
             .shelf,
             .divider,
             .reinforcement,
             .rail:
            return .korpus
        case .front:
            return .front
        case .back:
            return .plecy
        case .worktop:
            return .blat
        case .plinth:
            return .cokół
        case .filler,
             .maskingPanel,
             .decorativeSide:
            return .maskownice
        case .leg,
             .custom:
            return .pozostale
        }
    }

    private static func material(
        for role: FurnitureComponentRole,
        globalneMaterialy: GlobalneMaterialyPomieszczenia
    ) -> MaterialFormatkiV070 {
        switch role {
        case .front,
             .filler,
             .maskingPanel,
             .decorativeSide:
            return MaterialFormatkiV070(
                kod: globalneMaterialy.front.kod,
                nazwa: globalneMaterialy.front.nazwa,
                producent: globalneMaterialy.front.producent,
                kolorHEX: globalneMaterialy.front.kolorHEX
            )

        case .back:
            return MaterialFormatkiV070(
                kod: "HDF-PLECY",
                nazwa: "Płyta na plecy",
                producent: "Stolarnia",
                kolorHEX: "#B8B0A2"
            )

        case .worktop:
            return MaterialFormatkiV070(
                kod: "BLAT-PROJEKT",
                nazwa: "Blat projektu",
                producent: "Stolarnia",
                kolorHEX: "#9B8062"
            )

        default:
            return MaterialFormatkiV070(
                kod: globalneMaterialy.korpus.kod,
                nazwa: globalneMaterialy.korpus.nazwa,
                producent: globalneMaterialy.korpus.producent,
                kolorHEX: globalneMaterialy.korpus.kolorHEX
            )
        }
    }

    private static func grain(
        for role: FurnitureComponentRole
    ) -> KierunekDekoruV070 {
        switch role {
        case .back,
             .reinforcement,
             .rail,
             .leg,
             .custom:
            return .dowolny

        case .side,
             .top,
             .bottom,
             .shelf,
             .divider,
             .front,
             .worktop,
             .plinth,
             .filler,
             .maskingPanel,
             .decorativeSide:
            return .wzdluzDlugosci
        }
    }

    private static func label(
        moduleIndex: Int,
        componentIndex: Int,
        role: FurnitureComponentRole
    ) -> String {
        String(
            format: "%02d-%02d-%@",
            moduleIndex,
            componentIndex,
            abbreviation(for: role)
        )
    }

    private static func abbreviation(
        for role: FurnitureComponentRole
    ) -> String {
        switch role {
        case .side:
            return "BOK"
        case .top:
            return "GORA"
        case .bottom:
            return "DOL"
        case .shelf:
            return "POLKA"
        case .divider:
            return "DZIAL"
        case .back:
            return "PLECY"
        case .front:
            return "FRONT"
        case .worktop:
            return "BLAT"
        case .plinth:
            return "COKOL"
        case .filler:
            return "BLENDA"
        case .maskingPanel:
            return "MASK"
        case .decorativeSide:
            return "DEKOR"
        case .reinforcement:
            return "WZM"
        case .rail:
            return "LISTWA"
        case .leg:
            return "NOGA"
        case .custom:
            return "INNE"
        }
    }
}
