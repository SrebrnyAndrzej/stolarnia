import Foundation

/// Parametryczny model kabinetu wg standardu StolarzPro (System 32).
/// Wczytywany z bundle-owego `stolarzpro_parametric_model.json`.
///
/// Model traktujemy jako **domyślne standardy stolarni** — wartości mogą być
/// nadpisywane per projekt/moduł. Wczytanie jest jednorazowe (cache statyczny).
struct StolarzProParametricModel: Codable, Hashable {
    let cabinetParametricModel: CabinetParametricModel

    enum CodingKeys: String, CodingKey {
        case cabinetParametricModel = "cabinet_parametric_model"
    }
}

// MARK: - Wczytywanie

extension StolarzProParametricModel {
    enum LoadError: LocalizedError {
        case brakZasobu
        case bladDekodowania(Error)

        var errorDescription: String? {
            switch self {
            case .brakZasobu:
                return "Nie znaleziono zasobu stolarzpro_parametric_model.json w bundle."
            case .bladDekodowania(let error):
                return "Nie udało się zdekodować modelu parametrycznego: \(error.localizedDescription)"
            }
        }
    }

    /// Wczytany raz i przechowywany w pamięci — statyczna baza danych stolarni.
    /// Zwraca `nil` gdy zasób jest niedostępny (np. w testach bez bundle).
    static let wspoldzielony: StolarzProParametricModel? = {
        try? wczytaj()
    }()

    static func wczytaj(bundle: Bundle = .main) throws -> StolarzProParametricModel {
        guard let url = bundle.url(
            forResource: "stolarzpro_parametric_model",
            withExtension: "json"
        ) else {
            throw LoadError.brakZasobu
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(
                StolarzProParametricModel.self,
                from: data
            )
        } catch let decodingError {
            throw LoadError.bladDekodowania(decodingError)
        }
    }
}

// MARK: - Sekcje

struct CabinetParametricModel: Codable, Hashable {
    let moduleConfig: ModuleConfig
    let inputData: InputData
    let dimensionsMm: Dimensions
    let materials: Materials
    let constructionElements: ConstructionElements
    let hardwareAndSystems: HardwareAndSystems
    let viewsAndDrawings: ViewsAndDrawings
    let financialsAndPricing: FinancialsAndPricing

    enum CodingKeys: String, CodingKey {
        case moduleConfig = "module_config"
        case inputData = "input_data"
        case dimensionsMm = "dimensions_mm"
        case materials
        case constructionElements = "construction_elements"
        case hardwareAndSystems = "hardware_and_systems"
        case viewsAndDrawings = "views_and_drawings"
        case financialsAndPricing = "financials_and_pricing"
    }
}

struct ModuleConfig: Codable, Hashable {
    let version: String
    let systemStandard: String
    let architecture: Architecture

    enum CodingKeys: String, CodingKey {
        case version
        case systemStandard = "system_standard"
        case architecture
    }
}

struct Architecture: Codable, Hashable {
    let logicLayer: String
    let viewLayer: String

    enum CodingKeys: String, CodingKey {
        case logicLayer = "logic_layer"
        case viewLayer = "view_layer"
    }
}

struct InputData: Codable, Hashable {
    let measurementDevices: [String]
    let roomDimensionsMm: RoomDimensions

    enum CodingKeys: String, CodingKey {
        case measurementDevices = "measurement_devices"
        case roomDimensionsMm = "room_dimensions_mm"
    }
}

struct RoomDimensions: Codable, Hashable {
    let width: Double
    let height: Double
    let depth: Double
}

struct Dimensions: Codable, Hashable {
    let global: GlobalDimensions
    let clearances: Clearances
}

struct GlobalDimensions: Codable, Hashable {
    let width: Double
    let height: Double
    let depth: Double
}

struct Clearances: Codable, Hashable {
    let frontGap: Double
    let sideGap: Double
    let backVentilation: Double
    let wallOffset: Double

    enum CodingKeys: String, CodingKey {
        case frontGap = "front_gap"
        case sideGap = "side_gap"
        case backVentilation = "back_ventilation"
        case wallOffset = "wall_offset"
    }
}

// MARK: - Materials

struct Materials: Codable, Hashable {
    let carcass: CarcassMaterial
    let backPanel: BackPanelMaterial
    let worktops: WorktopsMaterial

    enum CodingKeys: String, CodingKey {
        case carcass
        case backPanel = "back_panel"
        case worktops
    }
}

struct CarcassMaterial: Codable, Hashable {
    let boardThicknessMm: [Double]
    let defaultThicknessMm: Double
    let edgeBandingMm: [Double]
    let edgeBandingTechnology: EdgeBandingTechnology

    enum CodingKeys: String, CodingKey {
        case boardThicknessMm = "board_thickness_mm"
        case defaultThicknessMm = "default_thickness_mm"
        case edgeBandingMm = "edge_banding_mm"
        case edgeBandingTechnology = "edge_banding_technology"
    }
}

struct EdgeBandingTechnology: Codable, Hashable {
    let standard: String
    let waterResistant: String

    enum CodingKeys: String, CodingKey {
        case standard
        case waterResistant = "water_resistant"
    }
}

struct BackPanelMaterial: Codable, Hashable {
    let material: String
    let thicknessMm: Double
    let mountingStyle: String
    let grooveOffsetMm: Double
    let grooveDepthMm: Double

    enum CodingKeys: String, CodingKey {
        case material
        case thicknessMm = "thickness_mm"
        case mountingStyle = "mounting_style"
        case grooveOffsetMm = "groove_offset_mm"
        case grooveDepthMm = "groove_depth_mm"
    }
}

struct WorktopsMaterial: Codable, Hashable {
    let types: [String]
    let standardDepthsMm: [Double]
    let overhangFrontMm: Double

    enum CodingKeys: String, CodingKey {
        case types
        case standardDepthsMm = "standard_depths_mm"
        case overhangFrontMm = "overhang_front_mm"
    }
}

// MARK: - Construction

struct ConstructionElements: Codable, Hashable {
    let wreathsAndTraverses: WreathsAndTraverses
    let blendsAndFillers: BlendsAndFillers
    let cncMachiningFeatures: CncMachiningFeatures

    enum CodingKeys: String, CodingKey {
        case wreathsAndTraverses = "wreaths_and_traverses"
        case blendsAndFillers = "blends_and_fillers"
        case cncMachiningFeatures = "cnc_machining_features"
    }
}

struct WreathsAndTraverses: Codable, Hashable {
    let bottomWreath: BottomWreath
    let topWreath: TopWreath

    enum CodingKeys: String, CodingKey {
        case bottomWreath = "bottom_wreath"
        case topWreath = "top_wreath"
    }
}

struct BottomWreath: Codable, Hashable {
    let type: String
    let thicknessMm: Double

    enum CodingKeys: String, CodingKey {
        case type
        case thicknessMm = "thickness_mm"
    }
}

struct TopWreath: Codable, Hashable {
    let type: String
    let traverseWidthMm: Double
    let frontTraverseOrientation: String
    let rearTraverseOrientation: String

    enum CodingKeys: String, CodingKey {
        case type
        case traverseWidthMm = "traverse_width_mm"
        case frontTraverseOrientation = "front_traverse_orientation"
        case rearTraverseOrientation = "rear_traverse_orientation"
    }
}

struct BlendsAndFillers: Codable, Hashable {
    let sideBlendWidthMm: [Double]
    let materialMatch: String

    enum CodingKeys: String, CodingKey {
        case sideBlendWidthMm = "side_blend_width_mm"
        case materialMatch = "material_match"
    }
}

struct CncMachiningFeatures: Codable, Hashable {
    let ledChannelRouting: LedChannelRouting
    let worktopCutouts: WorktopCutouts

    enum CodingKeys: String, CodingKey {
        case ledChannelRouting = "led_channel_routing"
        case worktopCutouts = "worktop_cutouts"
    }
}

struct LedChannelRouting: Codable, Hashable {
    let widthMm: Double
    let depthMm: Double
    let offsetFromFrontMm: Double

    enum CodingKeys: String, CodingKey {
        case widthMm = "width_mm"
        case depthMm = "depth_mm"
        case offsetFromFrontMm = "offset_from_front_mm"
    }
}

struct WorktopCutouts: Codable, Hashable {
    let sinkClearanceMm: Double
    let hobVentilationClearanceMm: Double

    enum CodingKeys: String, CodingKey {
        case sinkClearanceMm = "sink_clearance_mm"
        case hobVentilationClearanceMm = "hob_ventilation_clearance_mm"
    }
}

// MARK: - Hardware

struct HardwareAndSystems: Codable, Hashable {
    let legsAndBase: LegsAndBase
    let drawers: DrawersHardware
    let hinges: Hinges
    let cornerSystems: CornerSystems
    let lightingLed: LightingLed

    enum CodingKeys: String, CodingKey {
        case legsAndBase = "legs_and_base"
        case drawers
        case hinges
        case cornerSystems = "corner_systems"
        case lightingLed = "lighting_led"
    }
}

struct LegsAndBase: Codable, Hashable {
    let brand: String
    let clipSystem: String
    let defaultHeightMm: Double
    let adjustmentRangeMm: [Double]
    let setbacksMm: Setbacks
    let plinth: Plinth

    enum CodingKeys: String, CodingKey {
        case brand
        case clipSystem = "clip_system"
        case defaultHeightMm = "default_height_mm"
        case adjustmentRangeMm = "adjustment_range_mm"
        case setbacksMm = "setbacks_mm"
        case plinth
    }
}

struct Setbacks: Codable, Hashable {
    let front: Double
    let rear: Double
    let side: Double
}

struct Plinth: Codable, Hashable {
    let thicknessMm: Double
    let blendsIncluded: Bool

    enum CodingKeys: String, CodingKey {
        case thicknessMm = "thickness_mm"
        case blendsIncluded = "blends_included"
    }
}

struct DrawersHardware: Codable, Hashable {
    let systems: [String]
    let bottomThicknessMm: Double
    let slideClearanceMm: Double
    let drillingPatternFrontMm: Double

    enum CodingKeys: String, CodingKey {
        case systems
        case bottomThicknessMm = "bottom_thickness_mm"
        case slideClearanceMm = "slide_clearance_mm"
        case drillingPatternFrontMm = "drilling_pattern_front_mm"
    }
}

struct Hinges: Codable, Hashable {
    let brands: [String]
    let drilling: HingeDrilling
}

struct HingeDrilling: Codable, Hashable {
    let cupDiameterMm: Double
    let cupDepthMm: Double
    let distanceFromEdgeMm: Double
    let system32OffsetMm: Double

    enum CodingKeys: String, CodingKey {
        case cupDiameterMm = "cup_diameter_mm"
        case cupDepthMm = "cup_depth_mm"
        case distanceFromEdgeMm = "distance_from_edge_mm"
        case system32OffsetMm = "system_32_offset_mm"
    }
}

struct CornerSystems: Codable, Hashable {
    let brands: [String]
    let kinematics: CornerKinematics
}

struct CornerKinematics: Codable, Hashable {
    let minDoorWidthMm: Double
    let minInternalDepthMm: Double
    let collisionZoneCheckRequired: Bool

    enum CodingKeys: String, CodingKey {
        case minDoorWidthMm = "min_door_width_mm"
        case minInternalDepthMm = "min_internal_depth_mm"
        case collisionZoneCheckRequired = "collision_zone_check_required"
    }
}

struct LightingLed: Codable, Hashable {
    let profiles: [String]
    let componentsToCalculate: [String]

    enum CodingKeys: String, CodingKey {
        case profiles
        case componentsToCalculate = "components_to_calculate"
    }
}

// MARK: - Views

struct ViewsAndDrawings: Codable, Hashable {
    let elevation2D: Elevation2D
    let axonometry3D: Axonometry3D
    let technicalSection: TechnicalSection

    enum CodingKeys: String, CodingKey {
        case elevation2D = "elevation_2d"
        case axonometry3D = "axonometry_3d"
        case technicalSection = "technical_section"
    }
}

struct Elevation2D: Codable, Hashable {
    let requiredElements: [String]
    let hiddenLineStyle: String

    enum CodingKeys: String, CodingKey {
        case requiredElements = "required_elements"
        case hiddenLineStyle = "hidden_line_style"
    }
}

struct Axonometry3D: Codable, Hashable {
    let requiredElements: [String]
    let explodedViewOption: Bool?
    let explodeDistanceMm: Double

    enum CodingKeys: String, CodingKey {
        case requiredElements = "required_elements"
        case explodedViewOption = "exploded_view_option"
        case explodeDistanceMm = "explode_distance_mm"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.requiredElements = try container.decode([String].self, forKey: .requiredElements)
        self.explodedViewOption = try container.decodeIfPresent(Bool.self, forKey: .explodedViewOption)
        self.explodeDistanceMm = try container.decode(Double.self, forKey: .explodeDistanceMm)
    }
}

struct TechnicalSection: Codable, Hashable {
    let requiredElements: [String]
    let cutPlane: String

    enum CodingKeys: String, CodingKey {
        case requiredElements = "required_elements"
        case cutPlane = "cut_plane"
    }
}

// MARK: - Financials

struct FinancialsAndPricing: Codable, Hashable {
    let tiers: StolarzProPricingTiers
    let calculationParameters: CalculationParameters
    let logisticsAndServices: LogisticsAndServices

    enum CodingKeys: String, CodingKey {
        case tiers
        case calculationParameters = "calculation_parameters"
        case logisticsAndServices = "logistics_and_services"
    }
}

/// Osobny namespace dla poziomów cenowych StolarzPro — istniejący `PricingTier`
/// (enum) prezentowany w `DomainPresentationExtensions` służy do innego celu.
struct StolarzProPricingTiers: Codable, Hashable {
    let eco: StolarzProPricingTier
    let standard: StolarzProPricingTier
    let premium: StolarzProPricingTier
    let vip: StolarzProPricingTier

    /// Wygodna kolejność do prezentacji w UI (od najtańszej do najdroższej).
    var uporzadkowane: [(nazwa: String, tier: StolarzProPricingTier)] {
        [
            ("Eco", eco),
            ("Standard", standard),
            ("Premium", premium),
            ("VIP", vip)
        ]
    }
}

struct StolarzProPricingTier: Codable, Hashable {
    let description: String
}

struct CalculationParameters: Codable, Hashable {
    let marginPercentage: Double
    let hourlyLaborRate: Double
    let assemblyTimeHours: Double
    let cncProcessingTimeHours: Double

    enum CodingKeys: String, CodingKey {
        case marginPercentage = "margin_percentage"
        case hourlyLaborRate = "hourly_labor_rate"
        case assemblyTimeHours = "assembly_time_hours"
        case cncProcessingTimeHours = "cnc_processing_time_hours"
    }
}

struct LogisticsAndServices: Codable, Hashable {
    let transportBaseFee: Double
    let floorLevelSurcharge: Double
    let elevatorAvailable: Bool
    let cncOperationsPricing: CncOperationsPricing

    enum CodingKeys: String, CodingKey {
        case transportBaseFee = "transport_base_fee"
        case floorLevelSurcharge = "floor_level_surcharge"
        case elevatorAvailable = "elevator_available"
        case cncOperationsPricing = "cnc_operations_pricing"
    }
}

struct CncOperationsPricing: Codable, Hashable {
    let sinkCutout: Double
    let hobCutout: Double
    let ledRoutingPerMeter: Double

    enum CodingKeys: String, CodingKey {
        case sinkCutout = "sink_cutout"
        case hobCutout = "hob_cutout"
        case ledRoutingPerMeter = "led_routing_per_meter"
    }
}
