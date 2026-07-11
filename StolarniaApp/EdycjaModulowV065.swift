import Combine
import DomainCore
import Foundation
import Persistence

struct MigawkaStanuModuluV065 {
    let furnitureID: FurnitureAssemblyID
    let stored: StoredFurnitureAssembly?
    let kartaTechniczna: KartaTechnicznaSzafki?
}

struct StanEdycjiModulowV065 {
    let moduly: [MigawkaStanuModuluV065]
    let ciagi: [FurnitureRun]
}

struct OperacjaStanuModulowV065 {
    let nazwa: String
    let przed: StanEdycjiModulowV065
    let po: StanEdycjiModulowV065
    let zaznaczeniePrzed: FurnitureAssemblyID?
    let zaznaczeniePo: FurnitureAssemblyID?
    let zaznaczeniaPrzedV066: Set<FurnitureAssemblyID>
    let zaznaczeniaPoV066: Set<FurnitureAssemblyID>

    init(
        nazwa: String,
        przed: StanEdycjiModulowV065,
        po: StanEdycjiModulowV065,
        zaznaczeniePrzed: FurnitureAssemblyID?,
        zaznaczeniePo: FurnitureAssemblyID?,
        zaznaczeniaPrzedV066: Set<FurnitureAssemblyID>? = nil,
        zaznaczeniaPoV066: Set<FurnitureAssemblyID>? = nil
    ) {
        self.nazwa = nazwa
        self.przed = przed
        self.po = po
        self.zaznaczeniePrzed = zaznaczeniePrzed
        self.zaznaczeniePo = zaznaczeniePo
        self.zaznaczeniaPrzedV066 =
            zaznaczeniaPrzedV066
            ?? Set(zaznaczeniePrzed.map { [$0] } ?? [])
        self.zaznaczeniaPoV066 =
            zaznaczeniaPoV066
            ?? Set(zaznaczeniePo.map { [$0] } ?? [])
    }
}

struct WynikDuplikowaniaModuluV065 {
    let nowyID: FurnitureAssemblyID
    let operacja: OperacjaStanuModulowV065
}

struct WynikHistoriiModulowV065 {
    let powodzenie: Bool
    let zaznaczenie: FurnitureAssemblyID?
    let zaznaczeniaV066: Set<FurnitureAssemblyID>

    init(
        powodzenie: Bool,
        zaznaczenie: FurnitureAssemblyID?,
        zaznaczeniaV066: Set<FurnitureAssemblyID>? = nil
    ) {
        self.powodzenie = powodzenie
        self.zaznaczenie = zaznaczenie
        self.zaznaczeniaV066 =
            zaznaczeniaV066
            ?? Set(zaznaczenie.map { [$0] } ?? [])
    }

    static let niepowodzenie = WynikHistoriiModulowV065(
        powodzenie: false,
        zaznaczenie: nil,
        zaznaczeniaV066: []
    )
}

private enum OperacjaHistoriiModulowV065 {
    case polozenie(
        OperacjaPolozeniaModulowV064,
        zaznaczenie: FurnitureAssemblyID?
    )
    case grupa(OperacjaPolozeniaGrupyV066)
    case stan(OperacjaStanuModulowV065)

    var nazwa: String {
        switch self {
        case .polozenie(let operation, _):
            return operation.nazwa
        case .grupa(let operation):
            return operation.nazwa
        case .stan(let operation):
            return operation.nazwa
        }
    }

    var zaznaczeniePrzed: FurnitureAssemblyID? {
        switch self {
        case .polozenie(_, let selection):
            return selection
        case .grupa(let operation):
            return operation.zaznaczenieGlownePrzed
        case .stan(let operation):
            return operation.zaznaczeniePrzed
        }
    }

    var zaznaczeniePo: FurnitureAssemblyID? {
        switch self {
        case .polozenie(_, let selection):
            return selection
        case .grupa(let operation):
            return operation.zaznaczenieGlownePo
        case .stan(let operation):
            return operation.zaznaczeniePo
        }
    }

    var zaznaczeniaPrzedV066: Set<FurnitureAssemblyID> {
        switch self {
        case .polozenie(_, let selection):
            return Set(selection.map { [$0] } ?? [])
        case .grupa(let operation):
            return operation.zaznaczeniaPrzed
        case .stan(let operation):
            return operation.zaznaczeniaPrzedV066
        }
    }

    var zaznaczeniaPoV066: Set<FurnitureAssemblyID> {
        switch self {
        case .polozenie(_, let selection):
            return Set(selection.map { [$0] } ?? [])
        case .grupa(let operation):
            return operation.zaznaczeniaPo
        case .stan(let operation):
            return operation.zaznaczeniaPoV066
        }
    }

    func zastosujPrzed(
        viewModel: MeblePomieszczeniaViewModel
    ) async -> Bool {
        switch self {
        case .polozenie(let operation, _):
            return await viewModel.przywrocPolozeniaV064(operation.przed)
        case .grupa(let operation):
            return await viewModel.przywrocPolozeniaV064(
                operation.polozenia.przed
            )
        case .stan(let operation):
            return await viewModel.przywrocStanEdycjiV065(operation.przed)
        }
    }

    func zastosujPo(
        viewModel: MeblePomieszczeniaViewModel
    ) async -> Bool {
        switch self {
        case .polozenie(let operation, _):
            return await viewModel.przywrocPolozeniaV064(operation.po)
        case .grupa(let operation):
            return await viewModel.przywrocPolozeniaV064(
                operation.polozenia.po
            )
        case .stan(let operation):
            return await viewModel.przywrocStanEdycjiV065(operation.po)
        }
    }
}

@MainActor
final class HistoriaEdycjiModulowV065: ObservableObject {
    @Published private(set) var moznaCofnac = false
    @Published private(set) var moznaPonowic = false
    @Published private(set) var nazwaCofniecia: String?
    @Published private(set) var nazwaPonowienia: String?

    private var undoStack: [OperacjaHistoriiModulowV065] = []
    private var redoStack: [OperacjaHistoriiModulowV065] = []
    private let limit = 80

    func zarejestruj(_ operation: OperacjaPolozeniaModulowV064) {
        guard !operation.przed.isEmpty, !operation.po.isEmpty else { return }
        zarejestruj(
            .polozenie(
                operation,
                zaznaczenie:
                    operation.po.first?.furnitureID
                    ?? operation.przed.first?.furnitureID
            )
        )
    }

    func zarejestruj(_ operation: OperacjaStanuModulowV065) {
        zarejestruj(.stan(operation))
    }

    func zarejestruj(_ operation: OperacjaPolozeniaGrupyV066) {
        guard !operation.polozenia.przed.isEmpty,
              !operation.polozenia.po.isEmpty else {
            return
        }
        zarejestruj(.grupa(operation))
    }

    func cofnij(
        viewModel: MeblePomieszczeniaViewModel
    ) async -> WynikHistoriiModulowV065 {
        guard let operation = undoStack.popLast() else {
            return .niepowodzenie
        }

        if await operation.zastosujPrzed(viewModel: viewModel) {
            redoStack.append(operation)
            odswiez()
            return WynikHistoriiModulowV065(
                powodzenie: true,
                zaznaczenie: operation.zaznaczeniePrzed,
                zaznaczeniaV066:
                    operation.zaznaczeniaPrzedV066
            )
        }

        undoStack.append(operation)
        odswiez()
        return .niepowodzenie
    }

    func ponow(
        viewModel: MeblePomieszczeniaViewModel
    ) async -> WynikHistoriiModulowV065 {
        guard let operation = redoStack.popLast() else {
            return .niepowodzenie
        }

        if await operation.zastosujPo(viewModel: viewModel) {
            undoStack.append(operation)
            odswiez()
            return WynikHistoriiModulowV065(
                powodzenie: true,
                zaznaczenie: operation.zaznaczeniePo,
                zaznaczeniaV066:
                    operation.zaznaczeniaPoV066
            )
        }

        redoStack.append(operation)
        odswiez()
        return .niepowodzenie
    }

    private func zarejestruj(
        _ operation: OperacjaHistoriiModulowV065
    ) {
        undoStack.append(operation)
        if undoStack.count > limit {
            undoStack.removeFirst(undoStack.count - limit)
        }
        redoStack.removeAll()
        odswiez()
    }

    private func odswiez() {
        moznaCofnac = !undoStack.isEmpty
        moznaPonowic = !redoStack.isEmpty
        nazwaCofniecia = undoStack.last?.nazwa
        nazwaPonowienia = redoStack.last?.nazwa
    }
}

enum KlonowanieModuluV065 {
    static func wykonaj(
        source: StoredFurnitureAssembly,
        nowaNazwa: String
    ) throws -> StoredFurnitureAssembly {
        let sourceAssembly = source.assembly
        let newAssemblyID = FurnitureAssemblyID()

        let componentIDMap = Dictionary(
            uniqueKeysWithValues: sourceAssembly.components.map {
                ($0.id, ComponentID())
            }
        )
        let subassemblyIDMap = Dictionary(
            uniqueKeysWithValues: sourceAssembly.subassemblies.map {
                ($0.id, SubassemblyID())
            }
        )

        let components = try sourceAssembly.components.map { component in
            guard let newComponentID = componentIDMap[component.id] else {
                throw DomainError.invariantViolation(
                    "Nie udało się odwzorować identyfikatora komponentu."
                )
            }

            return try FurnitureComponent(
                id: newComponentID,
                code: component.code,
                role: component.role,
                size: component.size,
                localPosition: component.localPosition,
                rotationDegrees: component.rotationDegrees,
                isShared: component.isShared
            )
        }

        let subassemblies = try sourceAssembly.subassemblies.map { subassembly in
            guard let newSubassemblyID = subassemblyIDMap[subassembly.id] else {
                throw DomainError.invariantViolation(
                    "Nie udało się odwzorować identyfikatora podzespołu."
                )
            }

            let newComponentIDs = try subassembly.componentIDs.map {
                try requireComponentID($0, in: componentIDMap)
            }

            return try FurnitureSubassembly(
                id: newSubassemblyID,
                name: subassembly.name,
                componentIDs: newComponentIDs
            )
        }

        let constraints = try sourceAssembly.constraints.map {
            try mapConstraint(
                $0,
                componentIDs: componentIDMap,
                subassemblyIDs: subassemblyIDMap
            )
        }

        let placement: FurniturePlacement?
        if let sourcePlacement = sourceAssembly.placement {
            placement = try FurniturePlacement(
                roomID: sourcePlacement.roomID,
                wallID: sourcePlacement.wallID,
                assemblyID: newAssemblyID,
                offsetAlongWall: sourcePlacement.offsetAlongWall,
                offsetFromWall: sourcePlacement.offsetFromWall,
                bottomOffset: sourcePlacement.bottomOffset,
                rotationDegrees: sourcePlacement.rotationDegrees,
                anchoringMode: sourcePlacement.anchoringMode
            )
        } else {
            placement = nil
        }

        let assembly = try FurnitureAssembly(
            id: newAssemblyID,
            templateID: sourceAssembly.templateID,
            name: nowaNazwa,
            kind: sourceAssembly.kind,
            size: sourceAssembly.size,
            components: components,
            subassemblies: subassemblies,
            constraints: constraints,
            placement: placement
        )

        return StoredFurnitureAssembly(
            roomID: source.roomID,
            assembly: assembly,
            parameters: source.parameters
        )
    }

    private static func requireComponentID(
        _ id: ComponentID,
        in map: [ComponentID: ComponentID]
    ) throws -> ComponentID {
        guard let mapped = map[id] else {
            throw DomainError.invariantViolation(
                "Ograniczenie odwołuje się do nieznanego komponentu."
            )
        }
        return mapped
    }

    private static func mapConstraint(
        _ constraint: FurnitureConstraint,
        componentIDs: [ComponentID: ComponentID],
        subassemblyIDs: [SubassemblyID: SubassemblyID]
    ) throws -> FurnitureConstraint {
        func component(_ id: ComponentID) throws -> ComponentID {
            try requireComponentID(id, in: componentIDs)
        }

        func subassembly(_ id: SubassemblyID) throws -> SubassemblyID {
            guard let mapped = subassemblyIDs[id] else {
                throw DomainError.invariantViolation(
                    "Ograniczenie odwołuje się do nieznanego podzespołu."
                )
            }
            return mapped
        }

        switch constraint {
        case .alignLeft(let id, let reference):
            return .alignLeft(
                componentID: try component(id),
                referenceID: try component(reference)
            )
        case .alignRight(let id, let reference):
            return .alignRight(
                componentID: try component(id),
                referenceID: try component(reference)
            )
        case .alignTop(let id, let reference):
            return .alignTop(
                componentID: try component(id),
                referenceID: try component(reference)
            )
        case .alignBottom(let id, let reference):
            return .alignBottom(
                componentID: try component(id),
                referenceID: try component(reference)
            )
        case .centerHorizontal(let id, let reference):
            return .centerHorizontal(
                componentID: try component(id),
                referenceID: try component(reference)
            )
        case .centerVertical(let id, let reference):
            return .centerVertical(
                componentID: try component(id),
                referenceID: try component(reference)
            )
        case .equalSpacing(let ids):
            return .equalSpacing(componentIDs: try ids.map { try component($0) })
        case .equalWidth(let ids):
            return .equalWidth(componentIDs: try ids.map { try component($0) })
        case .equalHeight(let ids):
            return .equalHeight(componentIDs: try ids.map { try component($0) })
        case .fixedGap(let first, let second, let value):
            return .fixedGap(
                firstID: try component(first),
                secondID: try component(second),
                value: value
            )
        case .offset(let id, let reference, let value):
            return .offset(
                componentID: try component(id),
                referenceID: try component(reference),
                value: value
            )
        case .sharedPartition(let id, let subassemblyIDsValue):
            return .sharedPartition(
                componentID: try component(id),
                subassemblyIDs: try subassemblyIDsValue.map { try subassembly($0) }
            )
        }
    }
}
