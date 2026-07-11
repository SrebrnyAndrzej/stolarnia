import Testing
@testable import DomainCore

struct WallProfileTests {
    @Test(arguments: [
        (1.5, ScribeRecommendation.standardGap),
        (3.0, ScribeRecommendation.scribeElementRequired),
        (8.0, ScribeRecommendation.addProductionAllowance),
        (12.0, ScribeRecommendation.measureMultipointProfile),
        (16.0, ScribeRecommendation.requireTemplate)
    ])
    func acceptedThresholdsProduceExpectedRecommendation(
        deviation: Double,
        expected: ScribeRecommendation
    ) throws {
        let profile = try makeProfile(offsets: [0, deviation])
        #expect(profile.recommendation() == expected)
    }

    @Test
    func deviationRangeIncludesOffsetsOnBothSidesOfReference() throws {
        let profile = try makeProfile(offsets: [-7, 0, 8])

        #expect(profile.deviationRange == Millimeters(15))
        #expect(profile.maximumAbsoluteOffset == Millimeters(8))
    }

    @Test
    func profilePointsAreStoredInMeasurementOrder() throws {
        let wallID = WallID()
        let profile = try WallProfileDefinition(
            wallID: wallID,
            name: "Lewa krawędź wnęki",
            direction: .vertical,
            referenceEdge: .wallStart,
            points: [
                try WallProfilePoint(distanceAlongProfile: 1_000, offsetFromReference: 5),
                try WallProfilePoint(distanceAlongProfile: 0, offsetFromReference: 0),
                try WallProfilePoint(distanceAlongProfile: 500, offsetFromReference: 8)
            ]
        )

        #expect(profile.points.map(\.distanceAlongProfile) == [0, 500, 1_000])
    }

    private func makeProfile(offsets: [Double]) throws -> WallProfileDefinition {
        let points = try offsets.enumerated().map { index, offset in
            try WallProfilePoint(
                distanceAlongProfile: Millimeters(Double(index) * 250),
                offsetFromReference: Millimeters(offset)
            )
        }

        return try WallProfileDefinition(
            wallID: WallID(),
            name: "Profil testowy",
            direction: .vertical,
            referenceEdge: .wallStart,
            points: points
        )
    }
}
