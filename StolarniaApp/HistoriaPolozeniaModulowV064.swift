import Combine
import Foundation

@MainActor
final class HistoriaPolozeniaModulowV064: ObservableObject {
    @Published private(set) var moznaCofnac = false
    @Published private(set) var moznaPonowic = false

    private var undoStack: [OperacjaPolozeniaModulowV064] = []
    private var redoStack: [OperacjaPolozeniaModulowV064] = []
    private let limit = 80

    func zarejestruj(_ operation: OperacjaPolozeniaModulowV064) {
        guard !operation.przed.isEmpty, !operation.po.isEmpty else { return }
        undoStack.append(operation)
        if undoStack.count > limit {
            undoStack.removeFirst(undoStack.count - limit)
        }
        redoStack.removeAll()
        odswiez()
    }

    func cofnij(
        viewModel: MeblePomieszczeniaViewModel
    ) async {
        guard let operation = undoStack.popLast() else { return }
        if await viewModel.przywrocPolozeniaV064(operation.przed) {
            redoStack.append(operation)
        } else {
            undoStack.append(operation)
        }
        odswiez()
    }

    func ponow(
        viewModel: MeblePomieszczeniaViewModel
    ) async {
        guard let operation = redoStack.popLast() else { return }
        if await viewModel.przywrocPolozeniaV064(operation.po) {
            undoStack.append(operation)
        } else {
            redoStack.append(operation)
        }
        odswiez()
    }

    private func odswiez() {
        moznaCofnac = !undoStack.isEmpty
        moznaPonowic = !redoStack.isEmpty
    }
}
