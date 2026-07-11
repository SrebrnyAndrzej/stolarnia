import Combine
import DomainCore
import Foundation
import Persistence

@MainActor
final class ProjektListaViewModel: ObservableObject {
    @Published private(set) var projects: [WorkshopProject] = []
    @Published var selectedProjectID: ProjectID?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let projectRepository: SwiftDataProjectRepository

    init(
        projectRepository: SwiftDataProjectRepository
    ) {
        self.projectRepository = projectRepository
    }

    func loadProjects() async {
        isLoading = true
        defer { isLoading = false }

        do {
            projects = try await projectRepository.fetchAll()

            if let selectedProjectID,
               !projects.contains(where: { $0.id == selectedProjectID }) {
                self.selectedProjectID = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createProject(
        code: String,
        name: String,
        customerName: String
    ) async -> Bool {
        do {
            let project = try WorkshopProject(
                code: ProjectCode(code),
                name: name,
                customer: Customer(displayName: customerName)
            )

            try await projectRepository.save(project)
            await loadProjects()
            selectedProjectID = project.id
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteProject(
        id: ProjectID
    ) async {
        do {
            try await projectRepository.delete(id: id)

            if selectedProjectID == id {
                selectedProjectID = nil
            }

            await loadProjects()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func project(
        id: ProjectID?
    ) -> WorkshopProject? {
        guard let id else {
            return nil
        }

        return projects.first { $0.id == id }
    }
}
