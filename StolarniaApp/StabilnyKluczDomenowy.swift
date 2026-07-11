import Foundation

/// Tworzy stabilny klucz dla identyfikatorów domenowych bez uzależniania
/// warstwy aplikacji od wewnętrznej implementacji typów z `DomainCore`.
///
/// Dla identyfikatorów opartych na UUID zachowywany jest rzeczywisty UUID.
/// W pozostałych przypadkach używany jest deterministyczny skrót FNV-1a.
enum StabilnyKluczDomenowy {
    static func utworz<T>(
        dla value: T,
        prefiks: String
    ) -> String {
        if let uuid = pierwszeUUID(w: value, glebokosc: 0) {
            return "\(prefiks):\(uuid.uuidString.lowercased())"
        }

        if let string = pierwszyString(w: value, glebokosc: 0),
           !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return "\(prefiks):\(skrotFNV1a(string))"
        }

        return "\(prefiks):\(skrotFNV1a(String(reflecting: value)))"
    }

    private static func pierwszeUUID(
        w value: Any,
        glebokosc: Int
    ) -> UUID? {
        guard glebokosc < 8 else {
            return nil
        }

        if let uuid = value as? UUID {
            return uuid
        }

        let mirror = Mirror(reflecting: value)
        for child in mirror.children {
            if let uuid = pierwszeUUID(
                w: child.value,
                glebokosc: glebokosc + 1
            ) {
                return uuid
            }
        }

        return nil
    }

    private static func pierwszyString(
        w value: Any,
        glebokosc: Int
    ) -> String? {
        guard glebokosc < 8 else {
            return nil
        }

        if let string = value as? String {
            return string
        }

        let mirror = Mirror(reflecting: value)
        for child in mirror.children {
            if let string = pierwszyString(
                w: child.value,
                glebokosc: glebokosc + 1
            ) {
                return string
            }
        }

        return nil
    }

    private static func skrotFNV1a(
        _ value: String
    ) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        let prime: UInt64 = 1_099_511_628_211

        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }

        return String(hash, radix: 16)
    }
}
