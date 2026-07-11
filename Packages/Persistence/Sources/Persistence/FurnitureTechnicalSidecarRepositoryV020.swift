import DomainCore
import Foundation

public actor FurnitureTechnicalSidecarRepositoryV020 {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        fileManager: FileManager = .default
    ) throws {
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let directory = support.appendingPathComponent(
            "StolarniaApp",
            isDirectory: true
        )

        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        self.fileURL = directory.appendingPathComponent(
            "FurnitureTechnicalSpecificationsV020.json"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    public func fetchAll()
        throws -> [FurnitureTechnicalSpecificationV020]
    {
        guard FileManager.default.fileExists(
            atPath: fileURL.path
        ) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(
            [FurnitureTechnicalSpecificationV020].self,
            from: data
        )
    }

    public func fetch(
        templateID: FurnitureTemplateID
    ) throws -> FurnitureTechnicalSpecificationV020? {
        try fetchAll().first {
            $0.templateID == templateID
        }
    }

    public func save(
        _ specification:
            FurnitureTechnicalSpecificationV020
    ) throws {
        var values = try fetchAll()
        values.removeAll {
            $0.templateID == specification.templateID
        }
        values.append(specification)

        let data = try encoder.encode(values)
        try data.write(
            to: fileURL,
            options: [.atomic]
        )
    }

    public func delete(
        templateID: FurnitureTemplateID
    ) throws {
        var values = try fetchAll()
        values.removeAll {
            $0.templateID == templateID
        }

        let data = try encoder.encode(values)
        try data.write(
            to: fileURL,
            options: [.atomic]
        )
    }
}
