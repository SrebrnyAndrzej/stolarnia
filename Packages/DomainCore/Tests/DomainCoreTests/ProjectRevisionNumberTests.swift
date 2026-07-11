import Testing
@testable import DomainCore

struct ProjectRevisionNumberTests {
    @Test
    func revisionCodeUsesStableFormat() throws {
        let revision = try ProjectRevisionNumber(1)
        let nextRevision = try revision.next()

        #expect(revision.code == "R01")
        #expect(nextRevision.code == "R02")
    }

    @Test
    func revisionCannotStartAtZero() {
        #expect(throws: DomainError.self) {
            _ = try ProjectRevisionNumber(0)
        }
    }
}
