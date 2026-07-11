import Persistence

/// Jeden, stały zestaw repozytoriów używany przez moduł meblowy aplikacji.
/// Nie zawiera logiki biznesowej i nie zastępuje modeli z DomainCore.
struct MebleRepositoryContainer {
    let templateRepository: SwiftDataFurnitureTemplateRepository
    let assemblyRepository: SwiftDataFurnitureAssemblyRepository
    let runRepository: SwiftDataFurnitureRunRepository
}
