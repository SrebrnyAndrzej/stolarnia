import SwiftUI

struct NowyProjektView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var name = ""
    @State private var customerName = ""
    @State private var isSaving = false

    let onCreate: (
        _ code: String,
        _ name: String,
        _ customerName: String
    ) async -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Projekt") {
                    TextField("Kod projektu, np. PRJ-2026-0001", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    TextField("Nazwa projektu", text: $name)
                }

                Section("Klient") {
                    TextField("Nazwa klienta", text: $customerName)
                }

                Section {
                    Text("Nowy projekt otrzyma prywatną politykę ochrony i stabilne ID.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Nowy projekt")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSaving)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Utwórz") {
                        isSaving = true

                        Task {
                            await onCreate(code, name, customerName)
                            isSaving = false
                        }
                    }
                    .disabled(!isFormValid || isSaving)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .help("Utwórz projekt (⌘Return)")
                }
            }
            .overlay {
                if isSaving {
                    ProgressView("Zapisywanie…")
                        .padding()
                        .stolarniaMaterial(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var isFormValid: Bool {
        !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
