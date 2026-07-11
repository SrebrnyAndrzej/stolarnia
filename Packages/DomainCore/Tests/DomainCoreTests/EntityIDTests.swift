import Foundation
import Testing
@testable import DomainCore

struct EntityIDTests {
    @Test
    func identifierRoundTripsThroughJSON() throws {
        let original = ProjectID()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProjectID.self, from: data)

        #expect(decoded == original)
        #expect(decoded.description == original.description)
    }

    @Test
    func invalidIdentifierStringIsRejected() {
        let identifier = ProjectID("to-nie-jest-uuid")
        #expect(identifier == nil)
    }
}
