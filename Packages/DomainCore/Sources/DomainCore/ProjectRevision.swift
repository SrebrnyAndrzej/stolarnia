import Foundation

/// Znaczenie konkretnej rewizji projektu.
public enum ProjectRevisionStage: String, Codable, CaseIterable, Sendable {
    case initial
    case measurement
    case design
    case customerChange
    case accepted
    case frozenForProduction
    case installationCorrection
    case serviceCorrection
    case custom
}

/// Niezmienny wpis historii rewizji. Po zapisaniu nie jest modyfikowany.
public struct ProjectRevision: Identifiable, Codable, Hashable, Sendable {
    public let id: RevisionID
    public let number: ProjectRevisionNumber
    public let stage: ProjectRevisionStage
    public let summary: String
    public let createdAt: Date

    public init(
        id: RevisionID = RevisionID(),
        number: ProjectRevisionNumber,
        stage: ProjectRevisionStage,
        summary: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.number = number
        self.stage = stage
        self.summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
    }

    public var isFrozenForProduction: Bool {
        stage == .frozenForProduction
    }
}
