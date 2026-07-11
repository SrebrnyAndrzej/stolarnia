import SwiftUI

/// Wspólne pole ręcznego wpisywania wymiarów w milimetrach.
/// Od tej wersji używamy go dla ścian, a później również dla mebli,
/// formatek, wnęk, okien, drzwi i profili nierówności.
struct PolePomiaroweMM: View {
    let title: String
    @Binding var text: String
    let helpText: String?
    let autoFocus: Bool

    @FocusState private var isFocused: Bool

    init(
        _ title: String,
        text: Binding<String>,
        helpText: String? = nil,
        autoFocus: Bool = false
    ) {
        self.title = title
        self._text = text
        self.helpText = helpText
        self.autoFocus = autoFocus
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)

                Spacer()

                TextField("0", text: $text)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .font(.body.monospacedDigit())
                    .frame(minWidth: 110, idealWidth: 130, maxWidth: 150)
                    .focused($isFocused)

                Text("mm")
                    .foregroundStyle(.secondary)
            }

            if let helpText {
                Text(helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: autoFocus) {
            guard autoFocus else { return }
            await Task.yield()
            isFocused = true
        }
    }
}
