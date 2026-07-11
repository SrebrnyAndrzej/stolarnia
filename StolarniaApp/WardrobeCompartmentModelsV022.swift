import Foundation

struct WardrobeCompartmentV022:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var order: Int
    var widthMM: Double
    var shelfCount: Int
    var hangingRailEnabled: Bool
    var drawerCount: Int
    var drawerZoneHeightMM: Double
    var topShelfEnabled: Bool

    init(
        id: UUID = UUID(),
        order: Int,
        widthMM: Double,
        shelfCount: Int = 3,
        hangingRailEnabled: Bool = true,
        drawerCount: Int = 0,
        drawerZoneHeightMM: Double = 420,
        topShelfEnabled: Bool = true
    ) {
        self.id = id
        self.order = order
        self.widthMM = widthMM
        self.shelfCount = shelfCount
        self.hangingRailEnabled = hangingRailEnabled
        self.drawerCount = drawerCount
        self.drawerZoneHeightMM = drawerZoneHeightMM
        self.topShelfEnabled = topShelfEnabled
    }
}

struct WardrobeCompartmentLayoutV022:
    Identifiable,
    Codable,
    Hashable
{
    var id = UUID()
    var draftID: UUID
    var cabinetWidthMM: Double
    var dividerThicknessMM: Double
    var compartments: [WardrobeCompartmentV022]

    init(
        id: UUID = UUID(),
        draftID: UUID,
        cabinetWidthMM: Double,
        dividerThicknessMM: Double = 18,
        compartments: [WardrobeCompartmentV022]
    ) {
        self.id = id
        self.draftID = draftID
        self.cabinetWidthMM = cabinetWidthMM
        self.dividerThicknessMM = dividerThicknessMM
        self.compartments = compartments
        normalizeOrders()
    }

    static func defaultLayout(
        draftID: UUID,
        widthMM: Double,
        bayCount: Int
    ) -> WardrobeCompartmentLayoutV022 {
        let count = min(max(bayCount, 1), 4)
        let dividerWidth =
            Double(max(count - 1, 0)) * 18
        let usable = max(widthMM - dividerWidth, 100)
        let width = usable / Double(count)

        return WardrobeCompartmentLayoutV022(
            draftID: draftID,
            cabinetWidthMM: widthMM,
            compartments: (0..<count).map {
                WardrobeCompartmentV022(
                    order: $0,
                    widthMM: width
                )
            }
        )
    }

    mutating func normalizeOrders() {
        compartments.sort {
            $0.order < $1.order
        }

        for index in compartments.indices {
            compartments[index].order = index
        }
    }

    mutating func resizeToCabinet(
        widthMM: Double
    ) {
        cabinetWidthMM = widthMM

        guard !compartments.isEmpty else {
            compartments = [
                WardrobeCompartmentV022(
                    order: 0,
                    widthMM: max(widthMM, 100)
                )
            ]
            return
        }

        let current = max(
            compartments.reduce(0) {
                $0 + $1.widthMM
            },
            1
        )

        let usable = max(
            availableCompartmentWidthMM,
            100
        )
        let factor = usable / current

        for index in compartments.indices {
            compartments[index].widthMM =
                max(
                    compartments[index].widthMM
                    * factor,
                    100
                )
        }
    }

    mutating func setCompartmentCount(
        _ requestedCount: Int
    ) {
        let count = min(max(requestedCount, 1), 4)

        while compartments.count < count {
            compartments.append(
                WardrobeCompartmentV022(
                    order: compartments.count,
                    widthMM: 300
                )
            )
        }

        if compartments.count > count {
            compartments = Array(
                compartments.prefix(count)
            )
        }

        normalizeOrders()
        distributeEvenly()
    }

    mutating func distributeEvenly() {
        guard !compartments.isEmpty else {
            return
        }

        let width = max(
            availableCompartmentWidthMM
            / Double(compartments.count),
            100
        )

        for index in compartments.indices {
            compartments[index].widthMM = width
        }
    }

    var totalCompartmentWidthMM: Double {
        compartments.reduce(0) {
            $0 + $1.widthMM
        }
    }

    var dividerCount: Int {
        max(compartments.count - 1, 0)
    }

    var totalDividerWidthMM: Double {
        Double(dividerCount)
        * dividerThicknessMM
    }

    var availableCompartmentWidthMM: Double {
        max(
            cabinetWidthMM - totalDividerWidthMM,
            0
        )
    }

    var widthDifferenceMM: Double {
        availableCompartmentWidthMM
        - totalCompartmentWidthMM
    }

    var isWidthValid: Bool {
        abs(widthDifferenceMM) <= 1
    }

    var validationMessages: [String] {
        var messages: [String] = []

        if compartments.isEmpty {
            messages.append(
                "Szafa musi mieć co najmniej jedną komorę."
            )
        }

        if !isWidthValid {
            messages.append(
                "Suma szerokości komór różni się od dostępnej szerokości o \(Int(widthDifferenceMM.rounded())) mm."
            )
        }

        for (index, compartment) in compartments.enumerated() {
            if compartment.widthMM < 100 {
                messages.append(
                    "Komora \(index + 1) jest zbyt wąska."
                )
            }

            if compartment.drawerCount > 0,
               compartment.drawerZoneHeightMM < 180 {
                messages.append(
                    "Strefa szuflad w komorze \(index + 1) jest zbyt niska."
                )
            }
        }

        return messages
    }
}

enum WardrobeCompartmentStoreV022 {
    private static let key =
        "WardrobeCompartmentLayoutsV022"

    static func save(
        _ layout: WardrobeCompartmentLayoutV022
    ) {
        var all = loadAll()
        all.removeAll {
            $0.draftID == layout.draftID
        }
        all.append(layout)

        guard let data = try? JSONEncoder().encode(
            all
        ) else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: key
        )
    }

    static func load(
        draftID: UUID
    ) -> WardrobeCompartmentLayoutV022? {
        loadAll().first {
            $0.draftID == draftID
        }
    }

    static func loadAll()
        -> [WardrobeCompartmentLayoutV022]
    {
        guard
            let data = UserDefaults.standard.data(
                forKey: key
            ),
            let layouts = try? JSONDecoder().decode(
                [WardrobeCompartmentLayoutV022].self,
                from: data
            )
        else {
            return []
        }

        return layouts
    }
}
