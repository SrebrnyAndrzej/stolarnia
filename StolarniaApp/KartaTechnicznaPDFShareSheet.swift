import SwiftUI
import UIKit

struct KartaTechnicznaPDFShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct KartaTechnicznaPDFShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {
    }
}
