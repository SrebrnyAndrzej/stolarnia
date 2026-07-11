import Foundation
import UniformTypeIdentifiers

enum ProductionExportFormatV027:
    String,
    CaseIterable,
    Identifiable
{
    case pdf
    case csv

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pdf:
            return "PDF"
        case .csv:
            return "CSV"
        }
    }

    var systemImage: String {
        switch self {
        case .pdf:
            return "doc.richtext"
        case .csv:
            return "tablecells"
        }
    }

    var contentType: UTType {
        switch self {
        case .pdf:
            return .pdf
        case .csv:
            return .commaSeparatedText
        }
    }

    var fileExtension: String {
        switch self {
        case .pdf:
            return "pdf"
        case .csv:
            return "csv"
        }
    }
}

struct ProductionExportResultV027 {
    let url: URL
    let format:
        ProductionExportFormatV027
    let generatedAt: Date
}
