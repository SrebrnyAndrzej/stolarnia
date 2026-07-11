import Combine
@preconcurrency import CoreBluetooth
import Foundation

enum TrybWykrywaniaDalmierzaV0692:
    String,
    CaseIterable,
    Identifiable
{
    case tylkoHOTO
    case wszystkieBLE

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .tylkoHOTO:
            return "Tylko HOTO"
        case .wszystkieBLE:
            return "Wszystkie urządzenia BLE"
        }
    }
}

enum ProfilDekoderaDalmierzaV0692:
    String,
    Codable,
    CaseIterable,
    Identifiable
{
    case automatyczny
    case tekst
    case float32LEMetry
    case uint32LEMilimetry
    case uint16LEMilimetry

    var id: String { rawValue }

    var nazwa: String {
        switch self {
        case .automatyczny:
            return "Automatyczny"
        case .tekst:
            return "Tekst ASCII / UTF-8"
        case .float32LEMetry:
            return "Float32 LE w metrach"
        case .uint32LEMilimetry:
            return "UInt32 LE w milimetrach"
        case .uint16LEMilimetry:
            return "UInt16 LE w milimetrach"
        }
    }
}

enum StanDalmierzaBLEV0692:
    Equatable
{
    case wylaczony
    case oczekiwanieNaBluetooth
    case gotowy
    case skanowanie
    case laczenie(String)
    case polaczony(String)
    case rozlaczanie
    case blad(String)

    var opis: String {
        switch self {
        case .wylaczony:
            return "Bluetooth jest wyłączony."
        case .oczekiwanieNaBluetooth:
            return "Oczekiwanie na dostęp do Bluetooth…"
        case .gotowy:
            return "Gotowy do wyszukiwania."
        case .skanowanie:
            return "Wyszukiwanie dalmierza HOTO…"
        case .laczenie(let name):
            return "Łączenie z \(name)…"
        case .polaczony(let name):
            return "Połączono z \(name)."
        case .rozlaczanie:
            return "Rozłączanie…"
        case .blad(let message):
            return message
        }
    }

    var systemImage: String {
        switch self {
        case .polaczony:
            return "dot.radiowaves.left.and.right"
        case .skanowanie, .laczenie:
            return "antenna.radiowaves.left.and.right"
        case .blad, .wylaczony:
            return "exclamationmark.triangle"
        default:
            return "bolt.horizontal.circle"
        }
    }
}

struct UrzadzenieDalmierzaV0692:
    Identifiable,
    Hashable
{
    let id: UUID
    let name: String
    let rssi: Int
    let manufacturerDataHex: String?
    let isLikelyHOTO: Bool

    var strengthDescription: String {
        if rssi >= -55 {
            return "Bardzo dobry"
        }

        if rssi >= -70 {
            return "Dobry"
        }

        if rssi >= -85 {
            return "Słaby"
        }

        return "Bardzo słaby"
    }
}

struct KandydatPomiaruDalmierzaV0692:
    Identifiable,
    Hashable
{
    let id = UUID()
    let wartoscMM: Double
    let profil: ProfilDekoderaDalmierzaV0692
    let characteristicUUID: String
    let rawHex: String
    let timestamp: Date
    let confidence: Double

    var wartoscZaokraglonaMM: Double {
        (wartoscMM * 10).rounded() / 10
    }
}

struct PakietDiagnostycznyBLEV0692:
    Identifiable,
    Hashable
{
    let id = UUID()
    let timestamp: Date
    let serviceUUID: String?
    let characteristicUUID: String
    let properties: String
    let rawHex: String
    let textPreview: String?
}

protocol AdapterDalmierzaBLEV0692:
    AnyObject
{
    var stan: StanDalmierzaBLEV0692 { get }
    var urzadzenia: [UrzadzenieDalmierzaV0692] { get }
    var ostatniPomiar: KandydatPomiaruDalmierzaV0692? { get }
    var pakietyDiagnostyczne: [PakietDiagnostycznyBLEV0692] { get }

    func rozpocznijSkanowanie()
    func zatrzymajSkanowanie()
    func polacz(z id: UUID)
    func rozlacz()
}

final class UniwersalnyAdapterDalmierzaBLEV0692:
    NSObject,
    ObservableObject,
    AdapterDalmierzaBLEV0692
{
    @Published private(set) var stan:
        StanDalmierzaBLEV0692 =
            .oczekiwanieNaBluetooth

    @Published private(set) var urzadzenia:
        [UrzadzenieDalmierzaV0692] = []

    @Published private(set) var ostatniPomiar:
        KandydatPomiaruDalmierzaV0692?

    @Published private(set) var pakietyDiagnostyczne:
        [PakietDiagnostycznyBLEV0692] = []

    @Published var trybWykrywania:
        TrybWykrywaniaDalmierzaV0692 =
            .tylkoHOTO

    @Published var profilDekodera:
        ProfilDekoderaDalmierzaV0692 =
            .automatyczny {
        didSet {
            defaults.set(
                profilDekodera.rawValue,
                forKey:
                    Self.decoderDefaultsKey
            )
        }
    }

    @Published private(set) var connectedPeripheralID:
        UUID?

    @Published private(set) var connectedPeripheralName:
        String?

    @Published private(set) var ostatniaCharacteristicUUID:
        String?

    private var central:
        CBCentralManager!

    private var peripherals:
        [UUID: CBPeripheral] = [:]

    private var advertisementNames:
        [UUID: String] = [:]

    private let defaults:
        UserDefaults

    private static let decoderDefaultsKey =
        "StolarniaApp.BLE.Dalmierz.V0692.Decoder"

    private static let savedPeripheralDefaultsKey =
        "StolarniaApp.BLE.Dalmierz.V0692.LastPeripheral"

    init(
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        super.init()

        if let raw =
                defaults.string(
                    forKey:
                        Self.decoderDefaultsKey
                ),
           let profile =
                ProfilDekoderaDalmierzaV0692(
                    rawValue: raw
                ) {
            profilDekodera = profile
        }

        central =
            CBCentralManager(
                delegate: self,
                queue: nil,
                options: [
                    CBCentralManagerOptionShowPowerAlertKey:
                        true
                ]
            )
    }

    func rozpocznijSkanowanie() {
        guard central.state == .poweredOn else {
            stan =
                stanDlaCentralState(
                    central.state
                )
            return
        }

        urzadzenia = []
        peripherals = [:]
        advertisementNames = [:]

        central.scanForPeripherals(
            withServices: nil,
            options: [
                CBCentralManagerScanOptionAllowDuplicatesKey:
                    true
            ]
        )

        stan = .skanowanie
    }

    func zatrzymajSkanowanie() {
        central.stopScan()

        if connectedPeripheralID == nil {
            stan = .gotowy
        }
    }

    func polacz(z id: UUID) {
        guard let peripheral =
                peripherals[id]
        else {
            stan =
                .blad(
                    "Wybrane urządzenie nie jest już dostępne. Uruchom wyszukiwanie ponownie."
                )
            return
        }

        central.stopScan()

        if let currentID =
                connectedPeripheralID,
           currentID != id,
           let current =
                peripherals[currentID] {
            central.cancelPeripheralConnection(
                current
            )
        }

        let name =
            nazwa(
                peripheral: peripheral,
                fallback:
                    advertisementNames[id]
            )

        stan =
            .laczenie(name)

        peripheral.delegate = self
        central.connect(
            peripheral,
            options: [
                CBConnectPeripheralOptionNotifyOnDisconnectionKey:
                    true
            ]
        )
    }

    func rozlacz() {
        guard let id =
                connectedPeripheralID,
              let peripheral =
                peripherals[id]
        else {
            connectedPeripheralID = nil
            connectedPeripheralName = nil
            stan = .gotowy
            return
        }

        stan = .rozlaczanie
        central.cancelPeripheralConnection(
            peripheral
        )
    }

    func wyczyscDiagnostyke() {
        pakietyDiagnostyczne = []
        ostatniPomiar = nil
        ostatniaCharacteristicUUID = nil
    }

    var diagnostykaTekstowa: String {
        var lines: [String] = [
            "StolarniaApp — diagnostyka HOTO BLE v0.69.2",
            "Data: \(Date().formatted(date: .numeric, time: .standard))",
            "Stan: \(stan.opis)",
            "Urządzenie: \(connectedPeripheralName ?? "brak")",
            "Peripheral UUID: \(connectedPeripheralID?.uuidString ?? "brak")",
            "Dekoder: \(profilDekodera.rawValue)",
            "Pakiety: \(pakietyDiagnostyczne.count)",
            ""
        ]

        for packet in pakietyDiagnostyczne {
            lines.append(
                "[\(packet.timestamp.formatted(date: .omitted, time: .standard))] "
                + "\(packet.serviceUUID ?? "?") / "
                + "\(packet.characteristicUUID) "
                + "\(packet.properties) "
                + packet.rawHex
            )

            if let text = packet.textPreview {
                lines.append("TEXT: \(text)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func stanDlaCentralState(
        _ state: CBManagerState
    ) -> StanDalmierzaBLEV0692 {
        switch state {
        case .poweredOn:
            return .gotowy
        case .poweredOff:
            return .wylaczony
        case .unauthorized:
            return .blad(
                "Brak dostępu do Bluetooth. Włącz uprawnienie dla StolarniaApp w Ustawieniach iPadOS."
            )
        case .unsupported:
            return .blad(
                "To urządzenie nie obsługuje Bluetooth Low Energy."
            )
        case .resetting:
            return .oczekiwanieNaBluetooth
        case .unknown:
            fallthrough
        @unknown default:
            return .oczekiwanieNaBluetooth
        }
    }

    private func nazwa(
        peripheral: CBPeripheral,
        fallback: String?
    ) -> String {
        let candidates =
            [
                peripheral.name,
                fallback
            ]
            .compactMap { value in
                value?
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
            }
            .filter {
                !$0.isEmpty
            }

        return candidates.first
            ?? "Urządzenie BLE"
    }

    private static let hotoServiceUUIDs: Set<String> = [
        "FD50", "0000FD50-0000-1000-8000-00805F9B34FB",
        "FFE0", "0000FFE0-0000-1000-8000-00805F9B34FB",
    ]

    private func jestPrawdopodobnieHOTO(
        name: String,
        manufacturerData: Data?,
        serviceUUIDs: [CBUUID] = []
    ) -> Bool {
        if serviceUUIDs.contains(where: {
            Self.hotoServiceUUIDs.contains($0.uuidString.uppercased())
        }) {
            return true
        }
        let normalized =
            name
                .lowercased()
                .replacingOccurrences(
                    of: "-",
                    with: ""
                )
                .replacingOccurrences(
                    of: "_",
                    with: ""
                )
                .replacingOccurrences(
                    of: " ",
                    with: ""
                )

        let knownTokens = [
            "hoto",
            "qwcjy",
            "hd50",
            "hte0002",
            "hte0025",
            "lasermeasure",
            "smartlaser",
            "2azb9",
            "smartlasermeasurepro",
            "lasermeasurepro",
            "ty"
        ]

        if knownTokens.contains(
            where: {
                normalized.contains($0)
            }
        ) {
            return true
        }

        guard let manufacturerData else {
            return false
        }

        let ascii =
            String(
                data: manufacturerData,
                encoding: .utf8
            )?
            .lowercased()
            ?? ""

        return ascii.contains("hoto")
            || ascii.contains("qwcjy")
    }

    private func dodajPakiet(
        data: Data,
        characteristic:
            CBCharacteristic
    ) {
        let rawHex =
            data
                .map {
                    String(
                        format: "%02X",
                        $0
                    )
                }
                .joined(separator: " ")

        let readableText =
            String(
                data: data,
                encoding: .utf8
            )
            .map {
                $0
                    .replacingOccurrences(
                        of: "\0",
                        with: ""
                    )
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )
            }
            .flatMap {
                $0.isEmpty
                ? nil
                : $0
            }

        let packet =
            PakietDiagnostycznyBLEV0692(
                timestamp: Date(),
                serviceUUID:
                    characteristic
                        .service?
                        .uuid
                        .uuidString,
                characteristicUUID:
                    characteristic
                        .uuid
                        .uuidString,
                properties:
                    opisWlasciwosci(
                        characteristic
                            .properties
                    ),
                rawHex: rawHex,
                textPreview:
                    readableText
            )

        pakietyDiagnostyczne
            .append(packet)

        if pakietyDiagnostyczne.count > 80 {
            pakietyDiagnostyczne
                .removeFirst(
                    pakietyDiagnostyczne.count
                    - 80
                )
        }

        let candidates =
            dekoduj(
                data: data,
                characteristicUUID:
                    characteristic
                        .uuid
                        .uuidString,
                rawHex: rawHex
            )

        guard let best =
                candidates.max(
                    by: {
                        $0.confidence
                        < $1.confidence
                    }
                )
        else {
            return
        }

        ostatniPomiar = best
        ostatniaCharacteristicUUID =
            characteristic
                .uuid
                .uuidString
    }

    private func dekoduj(
        data: Data,
        characteristicUUID: String,
        rawHex: String
    ) -> [KandydatPomiaruDalmierzaV0692] {
        switch profilDekodera {
        case .automatyczny:
            return [
                dekodujTekst(
                    data: data,
                    characteristicUUID:
                        characteristicUUID,
                    rawHex: rawHex
                ),
                dekodujFloat32LE(
                    data: data,
                    characteristicUUID:
                        characteristicUUID,
                    rawHex: rawHex
                ),
                dekodujUInt32LE(
                    data: data,
                    characteristicUUID:
                        characteristicUUID,
                    rawHex: rawHex
                ),
                dekodujUInt16LE(
                    data: data,
                    characteristicUUID:
                        characteristicUUID,
                    rawHex: rawHex
                )
            ]
            .flatMap { $0 }

        case .tekst:
            return dekodujTekst(
                data: data,
                characteristicUUID:
                    characteristicUUID,
                rawHex: rawHex
            )

        case .float32LEMetry:
            return dekodujFloat32LE(
                data: data,
                characteristicUUID:
                    characteristicUUID,
                rawHex: rawHex
            )

        case .uint32LEMilimetry:
            return dekodujUInt32LE(
                data: data,
                characteristicUUID:
                    characteristicUUID,
                rawHex: rawHex
            )

        case .uint16LEMilimetry:
            return dekodujUInt16LE(
                data: data,
                characteristicUUID:
                    characteristicUUID,
                rawHex: rawHex
            )
        }
    }

    private func dekodujTekst(
        data: Data,
        characteristicUUID: String,
        rawHex: String
    ) -> [KandydatPomiaruDalmierzaV0692] {
        guard var text =
                String(
                    data: data,
                    encoding: .utf8
                )
        else {
            return []
        }

        text =
            text
                .replacingOccurrences(
                    of: "\0",
                    with: ""
                )
                .replacingOccurrences(
                    of: ",",
                    with: "."
                )

        let pattern =
            #"(?i)(\d+(?:\.\d+)?)\s*(mm|cm|m|meter|metre|ft|in)?\b"#

        guard let regex =
                try? NSRegularExpression(
                    pattern: pattern
                )
        else {
            return []
        }

        let range =
            NSRange(
                text.startIndex...,
                in: text
            )

        return regex
            .matches(
                in: text,
                range: range
            )
            .compactMap { match in
                guard let numberRange =
                        Range(
                            match.range(at: 1),
                            in: text
                        ),
                      let number =
                        Double(
                            text[numberRange]
                        )
                else {
                    return nil
                }

                var unit: String?
                if match.range(at: 2).location
                    != NSNotFound,
                   let unitRange =
                        Range(
                            match.range(at: 2),
                            in: text
                        ) {
                    unit =
                        String(
                            text[unitRange]
                        )
                        .lowercased()
                }

                let millimeters:
                    Double

                switch unit {
                case "mm":
                    millimeters = number
                case "cm":
                    millimeters = number * 10
                case "ft":
                    millimeters = number * 304.8
                case "in":
                    millimeters = number * 25.4
                case "m", "meter", "metre":
                    millimeters = number * 1000
                default:
                    // Dalmierze zwykle przekazują wartości tekstowe
                    // w metrach. Bez jednostki wymagamy ręcznego
                    // potwierdzenia i obniżamy pewność.
                    millimeters =
                        number <= 100
                        ? number * 1000
                        : number
                }

                guard jestPrawdopodobnaOdleglosc(
                    millimeters
                )
                else {
                    return nil
                }

                return KandydatPomiaruDalmierzaV0692(
                    wartoscMM: millimeters,
                    profil: .tekst,
                    characteristicUUID:
                        characteristicUUID,
                    rawHex: rawHex,
                    timestamp: Date(),
                    confidence:
                        unit == nil
                        ? 0.72
                        : 0.98
                )
            }
    }

    private func dekodujFloat32LE(
        data: Data,
        characteristicUUID: String,
        rawHex: String
    ) -> [KandydatPomiaruDalmierzaV0692] {
        guard data.count >= 4 else {
            return []
        }

        var result:
            [KandydatPomiaruDalmierzaV0692] = []

        let bytes = [UInt8](data)

        for offset in 0...(bytes.count - 4) {
            let bits =
                UInt32(bytes[offset])
                | UInt32(bytes[offset + 1]) << 8
                | UInt32(bytes[offset + 2]) << 16
                | UInt32(bytes[offset + 3]) << 24

            let meters =
                Double(
                    Float(
                        bitPattern: bits
                    )
                )

            let millimeters =
                meters * 1000

            guard meters.isFinite,
                  jestPrawdopodobnaOdleglosc(
                    millimeters
                  )
            else {
                continue
            }

            result.append(
                KandydatPomiaruDalmierzaV0692(
                    wartoscMM:
                        millimeters,
                    profil:
                        .float32LEMetry,
                    characteristicUUID:
                        characteristicUUID,
                    rawHex: rawHex,
                    timestamp: Date(),
                    confidence:
                        offset == 0
                        ? 0.82
                        : 0.62
                )
            )
        }

        return result
    }

    private func dekodujUInt32LE(
        data: Data,
        characteristicUUID: String,
        rawHex: String
    ) -> [KandydatPomiaruDalmierzaV0692] {
        guard data.count >= 4 else {
            return []
        }

        let bytes = [UInt8](data)
        var result:
            [KandydatPomiaruDalmierzaV0692] = []

        for offset in 0...(bytes.count - 4) {
            let value =
                UInt32(bytes[offset])
                | UInt32(bytes[offset + 1]) << 8
                | UInt32(bytes[offset + 2]) << 16
                | UInt32(bytes[offset + 3]) << 24

            let millimeters =
                Double(value)

            guard jestPrawdopodobnaOdleglosc(
                millimeters
            )
            else {
                continue
            }

            result.append(
                KandydatPomiaruDalmierzaV0692(
                    wartoscMM:
                        millimeters,
                    profil:
                        .uint32LEMilimetry,
                    characteristicUUID:
                        characteristicUUID,
                    rawHex: rawHex,
                    timestamp: Date(),
                    confidence:
                        offset == 0
                        ? 0.76
                        : 0.56
                )
            )
        }

        return result
    }

    private func dekodujUInt16LE(
        data: Data,
        characteristicUUID: String,
        rawHex: String
    ) -> [KandydatPomiaruDalmierzaV0692] {
        guard data.count >= 2 else {
            return []
        }

        let bytes = [UInt8](data)
        var result:
            [KandydatPomiaruDalmierzaV0692] = []

        for offset in 0...(bytes.count - 2) {
            let value =
                UInt16(bytes[offset])
                | UInt16(bytes[offset + 1]) << 8

            let millimeters =
                Double(value)

            guard jestPrawdopodobnaOdleglosc(
                millimeters
            )
            else {
                continue
            }

            result.append(
                KandydatPomiaruDalmierzaV0692(
                    wartoscMM:
                        millimeters,
                    profil:
                        .uint16LEMilimetry,
                    characteristicUUID:
                        characteristicUUID,
                    rawHex: rawHex,
                    timestamp: Date(),
                    confidence:
                        offset == 0
                        ? 0.68
                        : 0.48
                )
            )
        }

        return result
    }

    private func jestPrawdopodobnaOdleglosc(
        _ millimeters: Double
    ) -> Bool {
        millimeters.isFinite
        && millimeters >= 20
        && millimeters <= 100_000
    }

    private func opisWlasciwosci(
        _ properties:
            CBCharacteristicProperties
    ) -> String {
        var names: [String] = []

        if properties.contains(.read) {
            names.append("R")
        }
        if properties.contains(.write) {
            names.append("W")
        }
        if properties.contains(.writeWithoutResponse) {
            names.append("WNR")
        }
        if properties.contains(.notify) {
            names.append("N")
        }
        if properties.contains(.indicate) {
            names.append("I")
        }

        return names.joined(separator: ",")
    }
}

extension UniwersalnyAdapterDalmierzaBLEV0692:
    CBCentralManagerDelegate
{
    func centralManagerDidUpdateState(
        _ central: CBCentralManager
    ) {
        stan =
            stanDlaCentralState(
                central.state
            )
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData:
            [String: Any],
        rssi RSSI: NSNumber
    ) {
        let advertisedName =
            advertisementData[
                CBAdvertisementDataLocalNameKey
            ] as? String

        let name =
            nazwa(
                peripheral: peripheral,
                fallback:
                    advertisedName
            )

        let manufacturerData =
            advertisementData[
                CBAdvertisementDataManufacturerDataKey
            ] as? Data

        let advertisedServiceUUIDs =
            (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])
            ?? []

        let likelyHOTO =
            jestPrawdopodobnieHOTO(
                name: name,
                manufacturerData: manufacturerData,
                serviceUUIDs: advertisedServiceUUIDs
            )

        peripherals[
            peripheral.identifier
        ] = peripheral

        advertisementNames[
            peripheral.identifier
        ] = name

        let device =
            UrzadzenieDalmierzaV0692(
                id:
                    peripheral.identifier,
                name: name,
                rssi:
                    RSSI.intValue,
                manufacturerDataHex:
                    manufacturerData?
                        .map {
                            String(
                                format: "%02X",
                                $0
                            )
                        }
                        .joined(
                            separator: " "
                        ),
                isLikelyHOTO:
                    likelyHOTO
            )

        if let index =
                urzadzenia.firstIndex(
                    where: {
                        $0.id
                            == device.id
                    }
                ) {
            urzadzenia[index] =
                device
        } else {
            urzadzenia.append(device)
        }

        urzadzenia.sort {
            if $0.isLikelyHOTO
                != $1.isLikelyHOTO {
                return $0.isLikelyHOTO
            }

            return $0.rssi
                > $1.rssi
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        connectedPeripheralID =
            peripheral.identifier

        connectedPeripheralName =
            nazwa(
                peripheral: peripheral,
                fallback:
                    advertisementNames[
                        peripheral.identifier
                    ]
            )

        defaults.set(
            peripheral
                .identifier
                .uuidString,
            forKey:
                Self
                    .savedPeripheralDefaultsKey
        )

        stan =
            .polaczony(
                connectedPeripheralName
                ?? "HOTO"
            )

        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral:
            CBPeripheral,
        error: Error?
    ) {
        connectedPeripheralID = nil
        connectedPeripheralName = nil

        stan =
            .blad(
                "Nie udało się połączyć z \(peripheral.name ?? "HOTO"): \(error?.localizedDescription ?? "nieznany błąd")."
            )
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral:
            CBPeripheral,
        error: Error?
    ) {
        if connectedPeripheralID
            == peripheral.identifier {
            connectedPeripheralID = nil
            connectedPeripheralName = nil
        }

        if let error {
            stan =
                .blad(
                    "Połączenie zostało przerwane: \(error.localizedDescription)"
                )
        } else {
            stan = .gotowy
        }
    }
}

extension UniwersalnyAdapterDalmierzaBLEV0692:
    CBPeripheralDelegate
{
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        if let error {
            stan =
                .blad(
                    "Nie udało się odczytać usług BLE: \(error.localizedDescription)"
                )
            return
        }

        for service in
            peripheral.services ?? [] {
            peripheral
                .discoverCharacteristics(
                    nil,
                    for: service
                )
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service:
            CBService,
        error: Error?
    ) {
        if let error {
            stan =
                .blad(
                    "Nie udało się odczytać charakterystyk \(service.uuid.uuidString): \(error.localizedDescription)"
                )
            return
        }

        for characteristic in
            service.characteristics ?? [] {
            let properties =
                characteristic.properties

            if properties.contains(.notify)
                || properties.contains(.indicate) {
                peripheral.setNotifyValue(
                    true,
                    for:
                        characteristic
                )
            }

            if properties.contains(.read) {
                peripheral.readValue(
                    for:
                        characteristic
                )
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic:
            CBCharacteristic,
        error: Error?
    ) {
        if let error {
            let packet =
                PakietDiagnostycznyBLEV0692(
                    timestamp: Date(),
                    serviceUUID:
                        characteristic
                            .service?
                            .uuid
                            .uuidString,
                    characteristicUUID:
                        characteristic
                            .uuid
                            .uuidString,
                    properties:
                        "ERROR",
                    rawHex:
                        error
                            .localizedDescription,
                    textPreview: nil
                )

            pakietyDiagnostyczne
                .append(packet)
            return
        }

        guard let value =
                characteristic.value,
              !value.isEmpty
        else {
            return
        }

        dodajPakiet(
            data: value,
            characteristic:
                characteristic
        )
    }
}
