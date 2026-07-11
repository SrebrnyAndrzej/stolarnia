import Foundation

/// Kanoniczny model projektu. Ten sam identyfikator projektu zasila później
/// pomiary, geometrię, wycenę, dokumentację techniczną i montaż.
public struct WorkshopProject: Identifiable, Codable, Hashable, Sendable {
    public let id: ProjectID
    public let code: ProjectCode
    public let createdAt: Date

    public var name: String
    public var customer: Customer
    public var site: ProjectSite
    public var status: ProjectStatus
    public var selectedPricingTier: PricingTier
    public var protectionPolicy: ProjectProtectionPolicy
    public private(set) var revisionHistory: [ProjectRevision]
    public private(set) var roomIDs: [RoomID]
    public private(set) var updatedAt: Date

    public init(
        id: ProjectID = ProjectID(),
        code: ProjectCode,
        name: String,
        customer: Customer,
        site: ProjectSite = ProjectSite(),
        status: ProjectStatus = .inquiry,
        selectedPricingTier: PricingTier = .standard,
        protectionPolicy: ProjectProtectionPolicy = .privateProject,
        createdAt: Date = Date()
    ) throws {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedName.isEmpty else {
            throw DomainError.invariantViolation("Nazwa projektu nie może być pusta.")
        }

        let initialRevision = ProjectRevision(
            number: try ProjectRevisionNumber(1),
            stage: .initial,
            summary: "Utworzenie projektu",
            createdAt: createdAt
        )

        self.id = id
        self.code = code
        self.createdAt = createdAt
        self.name = normalizedName
        self.customer = customer
        self.site = site
        self.status = status
        self.selectedPricingTier = selectedPricingTier
        self.protectionPolicy = protectionPolicy
        self.revisionHistory = [initialRevision]
        self.roomIDs = []
        self.updatedAt = createdAt
    }

    public var currentRevision: ProjectRevision {
        revisionHistory[revisionHistory.count - 1]
    }

    public var isFrozenForProduction: Bool {
        currentRevision.isFrozenForProduction
    }

    public mutating func updateStatus(
        _ newStatus: ProjectStatus,
        at date: Date = Date()
    ) {
        status = newStatus
        updatedAt = date
    }

    public mutating func addRoom(
        id roomID: RoomID,
        at date: Date = Date()
    ) {
        guard !roomIDs.contains(roomID) else {
            return
        }

        roomIDs.append(roomID)
        updatedAt = date
    }

    public mutating func removeRoom(
        id roomID: RoomID,
        at date: Date = Date()
    ) {
        roomIDs.removeAll { $0 == roomID }
        updatedAt = date
    }

    @discardableResult
    public mutating func createRevision(
        stage: ProjectRevisionStage,
        summary: String,
        at date: Date = Date()
    ) throws -> ProjectRevision {
        let nextNumber = try currentRevision.number.next()
        let revision = ProjectRevision(
            number: nextNumber,
            stage: stage,
            summary: summary,
            createdAt: date
        )

        revisionHistory.append(revision)
        updatedAt = date
        return revision
    }

    @discardableResult
    public mutating func freezeForProduction(
        summary: String = "Zamrożenie projektu do produkcji",
        at date: Date = Date()
    ) throws -> ProjectRevision {
        let revision = try createRevision(
            stage: .frozenForProduction,
            summary: summary,
            at: date
        )

        status = .readyForProduction
        return revision
    }
}
