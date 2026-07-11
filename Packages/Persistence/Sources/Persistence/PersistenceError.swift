import Foundation

public enum PersistenceError: Error, Equatable, Sendable {
    case projectNotFound(String)
    case roomNotFound(String)
    case furnitureTemplateNotFound(String)
    case furnitureAssemblyNotFound(String)
    case furnitureRunNotFound(String)

    case corruptedProjectPayload(String)
    case corruptedRoomPayload(String)
    case corruptedFurnitureTemplatePayload(String)
    case corruptedFurnitureAssemblyPayload(String)
    case corruptedFurnitureRunPayload(String)

    case duplicateProjectCode(String)
    case duplicateFurnitureTemplateCode(String)

    case roomProjectMismatch(roomID: String, projectID: String)
    case furnitureRoomMismatch(assemblyID: String, roomID: String)
    case furnitureWallMismatch(assemblyID: String, wallID: String)
    case furnitureRunRoomMismatch(runID: String, roomID: String)
    case furnitureRunWallMismatch(runID: String, wallID: String)
    case furnitureRunMissingModule(runID: String, assemblyID: String)
}

extension PersistenceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .projectNotFound(let identifier):
            return "Nie znaleziono projektu o ID: \(identifier)."

        case .roomNotFound(let identifier):
            return "Nie znaleziono pomieszczenia o ID: \(identifier)."

        case .furnitureTemplateNotFound(let identifier):
            return "Nie znaleziono szablonu mebla o ID: \(identifier)."

        case .furnitureAssemblyNotFound(let identifier):
            return "Nie znaleziono modułu meblowego o ID: \(identifier)."

        case .furnitureRunNotFound(let identifier):
            return "Nie znaleziono ciągu meblowego o ID: \(identifier)."

        case .corruptedProjectPayload(let identifier):
            return "Zapis projektu \(identifier) jest uszkodzony albo niezgodny ze schematem."

        case .corruptedRoomPayload(let identifier):
            return "Zapis pomieszczenia \(identifier) jest uszkodzony albo niezgodny ze schematem."

        case .corruptedFurnitureTemplatePayload(let identifier):
            return "Zapis szablonu mebla \(identifier) jest uszkodzony albo niezgodny ze schematem."

        case .corruptedFurnitureAssemblyPayload(let identifier):
            return "Zapis modułu meblowego \(identifier) jest uszkodzony albo niezgodny ze schematem."

        case .corruptedFurnitureRunPayload(let identifier):
            return "Zapis ciągu meblowego \(identifier) jest uszkodzony albo niezgodny ze schematem."

        case .duplicateProjectCode(let code):
            return "Projekt o kodzie \(code) już istnieje."

        case .duplicateFurnitureTemplateCode(let code):
            return "Szablon mebla o kodzie \(code) już istnieje."

        case .roomProjectMismatch(let roomID, let projectID):
            return "Pomieszczenie \(roomID) nie należy do projektu \(projectID)."

        case .furnitureRoomMismatch(let assemblyID, let roomID):
            return "Moduł meblowy \(assemblyID) nie należy do pomieszczenia \(roomID)."

        case .furnitureWallMismatch(let assemblyID, let wallID):
            return "Moduł meblowy \(assemblyID) wskazuje nieistniejącą ścianę \(wallID)."

        case .furnitureRunRoomMismatch(let runID, let roomID):
            return "Ciąg meblowy \(runID) nie należy do pomieszczenia \(roomID)."

        case .furnitureRunWallMismatch(let runID, let wallID):
            return "Ciąg meblowy \(runID) wskazuje nieistniejącą ścianę \(wallID)."

        case .furnitureRunMissingModule(let runID, let assemblyID):
            return "Ciąg meblowy \(runID) wskazuje nieistniejący moduł \(assemblyID)."
        }
    }
}
