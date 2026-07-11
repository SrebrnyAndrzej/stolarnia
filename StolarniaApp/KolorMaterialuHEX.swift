import SwiftUI
import UIKit

enum KolorMaterialuHEX {
    static func rgba(
        _ value: String
    ) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") {
            text.removeFirst()
        }

        guard text.count == 6 || text.count == 8,
              let number = UInt64(text, radix: 16)
        else {
            return nil
        }

        if text.count == 6 {
            return (
                red: CGFloat((number >> 16) & 0xFF) / 255,
                green: CGFloat((number >> 8) & 0xFF) / 255,
                blue: CGFloat(number & 0xFF) / 255,
                alpha: 1
            )
        }

        return (
            red: CGFloat((number >> 24) & 0xFF) / 255,
            green: CGFloat((number >> 16) & 0xFF) / 255,
            blue: CGFloat((number >> 8) & 0xFF) / 255,
            alpha: CGFloat(number & 0xFF) / 255
        )
    }

    static func normalized(
        _ value: String,
        fallback: String = "#CCCCCC"
    ) -> String {
        guard rgba(value) != nil else {
            return fallback
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("#")
            ? trimmed.uppercased()
            : "#\(trimmed.uppercased())"
    }
}

extension Color {
    init(
        stolarniaHEX value: String,
        fallback: Color = .gray
    ) {
        guard let rgba = KolorMaterialuHEX.rgba(value) else {
            self = fallback
            return
        }

        self.init(
            red: Double(rgba.red),
            green: Double(rgba.green),
            blue: Double(rgba.blue),
            opacity: Double(rgba.alpha)
        )
    }
}

extension UIColor {
    convenience init?(
        stolarniaHEX value: String
    ) {
        guard let rgba = KolorMaterialuHEX.rgba(value) else {
            return nil
        }
        self.init(
            red: rgba.red,
            green: rgba.green,
            blue: rgba.blue,
            alpha: rgba.alpha
        )
    }
}
