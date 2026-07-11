import DomainCore
import Foundation
import Persistence

enum RodzajOperacjiGrupowejV066: String, CaseIterable, Identifiable, Sendable {
    case wyrownajDol
    case wyrownajGore
    case domknijOdstepy
    case rozlozRownomiernie
    case rozlozRownaSzerokosc

    var id: String { rawValue }

    var tytul: String {
        switch self {
        case .wyrownajDol:
            return "Wyrównaj dół"
        case .wyrownajGore:
            return "Wyrównaj górę"
        case .domknijOdstepy:
            return "Domknij odstępy"
        case .rozlozRownomiernie:
            return "Rozłóż równo"
        case .rozlozRownaSzerokosc:
            return "Równa szerokość"
        }
    }

    var symbol: String {
        switch self {
        case .wyrownajDol:
            return "arrow.down.to.line"
        case .wyrownajGore:
            return "arrow.up.to.line"
        case .domknijOdstepy:
            return "arrow.right.to.line"
        case .rozlozRownomiernie:
            return "arrow.left.and.right"
        case .rozlozRownaSzerokosc:
            return "rectangle.split.3x1"
        }
    }

    var minimalnaLiczbaModulow: Int {
        switch self {
        case .wyrownajDol, .wyrownajGore, .domknijOdstepy:
            return 2
        case .rozlozRownomiernie, .rozlozRownaSzerokosc:
            return 2
        }
    }

    /// `true` gdy operacja zmienia rozmiar modułów (przebudowa), a nie tylko ich pozycje.
    /// Takie operacje mają osobną ścieżkę zapisu i cofania (stan V065, nie pozycje V064).
    var przebudowujeModuly: Bool {
        self == .rozlozRownaSzerokosc
    }
}

struct OperacjaPolozeniaGrupyV066 {
    let nazwa: String
    let polozenia: OperacjaPolozeniaModulowV064
    let zaznaczeniaPrzed: Set<FurnitureAssemblyID>
    let zaznaczeniaPo: Set<FurnitureAssemblyID>
    let zaznaczenieGlownePrzed: FurnitureAssemblyID?
    let zaznaczenieGlownePo: FurnitureAssemblyID?
}

struct WynikOperacjiGrupowejV066 {
    let operacja: OperacjaPolozeniaGrupyV066
    let zaznaczoneID: Set<FurnitureAssemblyID>
    let glowneID: FurnitureAssemblyID?
}

struct PodsumowanieZaznaczeniaV066 {
    let ids: Set<FurnitureAssemblyID>
    let liczba: Int
    let wspolnaScianaID: WallID?
    let maWspolnaSciane: Bool
    let maWspolnyPas: Bool

    static func utworz(
        ids: Set<FurnitureAssemblyID>,
        storedAssemblies: [StoredFurnitureAssembly]
    ) -> PodsumowanieZaznaczeniaV066 {
        let selected = storedAssemblies.filter { ids.contains($0.id) }
        let wallIDs = Set(selected.compactMap {
            $0.assembly.placement?.wallID
        })
        let allHaveWall = selected.allSatisfy {
            $0.assembly.placement?.wallID != nil
        }
        let commonWall = allHaveWall && wallIDs.count == 1
            ? wallIDs.first
            : nil

        let first = selected.first
        let commonLane: Bool
        if let first,
           let firstPlacement = first.assembly.placement {
            let firstLayer = MebelPlan2DGeometry.layer(
                for: first.assembly
            )
            commonLane = selected.allSatisfy { item in
                guard let placement = item.assembly.placement else {
                    return false
                }
                return placement.wallID == firstPlacement.wallID
                    && MebelPlan2DGeometry.layer(
                        for: item.assembly
                    ) == firstLayer
                    && abs(
                        placement.offsetFromWall.rawValue
                            - firstPlacement.offsetFromWall.rawValue
                    ) <= 1
                    && abs(
                        placement.bottomOffset.rawValue
                            - firstPlacement.bottomOffset.rawValue
                    ) <= 1
            }
        } else {
            commonLane = false
        }

        return PodsumowanieZaznaczeniaV066(
            ids: ids,
            liczba: selected.count,
            wspolnaScianaID: commonWall,
            maWspolnaSciane: commonWall != nil,
            maWspolnyPas: commonLane
        )
    }

    func moznaWykonac(
        _ operation: RodzajOperacjiGrupowejV066
    ) -> Bool {
        guard liczba >= operation.minimalnaLiczbaModulow,
              maWspolnaSciane else {
            return false
        }

        switch operation {
        case .wyrownajDol, .wyrownajGore:
            return true
        case .domknijOdstepy, .rozlozRownomiernie, .rozlozRownaSzerokosc:
            return maWspolnyPas
        }
    }
}
