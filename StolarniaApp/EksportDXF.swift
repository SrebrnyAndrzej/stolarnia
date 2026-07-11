import DomainCore
import Foundation

// MARK: - DXF Export

/// Generuje plik DXF R12 ASCII z rzutem 2D pomieszczenia.
/// 1 jednostka DXF = 1 mm.
///
/// Warstwy:
///  SCIANY   — obrys pomieszczenia
///  MEBLE    — prostokąty szafek z podpisami
///  KOTA     — wymiary ścian (długość + TEXT)
///  LEGENDA  — tabela meblowy po prawej stronie rzutu
enum EksportDXF {

    // MARK: - Public API

    static func generuj(
        room: RoomDefinition,
        zestawy: [FurnitureAssembly]
    ) -> Data {
        let content = buduj(room: room, zestawy: zestawy)
        return Data(content.utf8)
    }

    static func generujURL(
        room: RoomDefinition,
        zestawy: [FurnitureAssembly]
    ) -> URL {
        let data = generuj(room: room, zestawy: zestawy)
        let safeName = room.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName) - rzut 2D.dxf")
        try? data.write(to: url)
        return url
    }

    // MARK: - Builder

    private static func buduj(
        room: RoomDefinition,
        zestawy: [FurnitureAssembly]
    ) -> String {
        var out = ""

        // Minimal DXF R12 header
        out += header()

        // Layer table
        out += tableLayers()

        // ENTITIES section
        out += "  0\nSECTION\n  2\nENTITIES\n"

        let boundary = room.geometry.boundary

        // Determine if polygon is CCW (positive signed area → inward = left-hand normal)
        let isCCW = signedArea(boundary) >= 0

        // --- SCIANY: room boundary ---
        for seg in boundary.segments {
            out += segmentDXF(seg, layer: "SCIANY", color: 1)
        }

        // --- KOTA: wall length labels ---
        for seg in boundary.segments {
            out += kotaDXF(seg)
        }

        // --- MEBLE: furniture footprints ---
        let placed = zestawy.filter { $0.placement?.wallID != nil }
        for assembly in placed {
            guard let placement = assembly.placement,
                  let wallID = placement.wallID,
                  let wallSeg = room.geometry.geometry(of: wallID)
            else { continue }

            out += mebelDXF(
                assembly: assembly,
                placement: placement,
                wallSeg: wallSeg,
                isCCW: isCCW
            )
        }

        // --- LEGENDA: material table ---
        let bbox = boundingBox(boundary)
        out += legenda(zestawy: placed, bbox: bbox)

        out += "  0\nENDSEC\n  0\nEOF\n"
        return out
    }

    // MARK: - Header & Tables

    private static func header() -> String {
        "  0\nSECTION\n  2\nHEADER\n"
        + "  9\n$ACADVER\n  1\nAC1009\n"
        + "  9\n$INSUNITS\n 70\n     4\n"
        + "  0\nENDSEC\n"
    }

    private static func tableLayers() -> String {
        let layers: [(name: String, color: Int)] = [
            ("SCIANY", 1),   // red
            ("MEBLE",  3),   // green
            ("KOTA",   2),   // yellow
            ("LEGENDA",5)    // blue
        ]

        var out = "  0\nSECTION\n  2\nTABLES\n"
        out += "  0\nTABLE\n  2\nLAYER\n 70\n\(layers.count + 1)\n"

        // Default layer 0
        out += "  0\nLAYER\n  2\n0\n 70\n0\n 62\n7\n  6\nContinuous\n"

        for l in layers {
            out += "  0\nLAYER\n  2\n\(l.name)\n 70\n0\n 62\n\(l.color)\n  6\nContinuous\n"
        }

        out += "  0\nENDTAB\n  0\nENDSEC\n"
        return out
    }

    // MARK: - Entities

    private static func segmentDXF(
        _ seg: ContourSegment2D,
        layer: String,
        color: Int
    ) -> String {
        switch seg {
        case .line(let ls):
            return lineDXF(
                layer: layer,
                x1: ls.start.x.rawValue,
                y1: ls.start.y.rawValue,
                x2: ls.end.x.rawValue,
                y2: ls.end.y.rawValue,
                color: color
            )
        case .arc(let arc):
            return arcDXF(
                layer: layer,
                cx: arc.center.x.rawValue,
                cy: arc.center.y.rawValue,
                r: arc.radius.rawValue,
                startAngle: angleDeg(
                    from: arc.center,
                    to: arc.start
                ),
                endAngle: angleDeg(
                    from: arc.center,
                    to: arc.end
                ),
                clockwise: arc.clockwise,
                color: color
            )
        }
    }

    private static func kotaDXF(_ seg: ContourSegment2D) -> String {
        let length = seg.length.rawValue
        guard length > 1 else { return "" }

        let mx = (seg.start.x.rawValue + seg.end.x.rawValue) / 2
        let my = (seg.start.y.rawValue + seg.end.y.rawValue) / 2

        // Compute segment direction angle for text rotation
        let dx = seg.end.x.rawValue - seg.start.x.rawValue
        let dy = seg.end.y.rawValue - seg.start.y.rawValue
        var angle = atan2(dy, dx) * 180 / Double.pi
        // Keep text readable (rotate if facing left)
        if angle > 90 || angle < -90 {
            angle += 180
        }

        // Offset label perpendicular to segment (slightly inside)
        let segLen = hypot(dx, dy)
        let normX = segLen > 0 ? dx / segLen : 0
        let normY = segLen > 0 ? dy / segLen : 0
        let offsetX = -normY * 80 // 80mm offset
        let offsetY =  normX * 80

        let label = formatMM(length)
        return textDXF(
            layer: "KOTA",
            x: mx + offsetX,
            y: my + offsetY,
            height: 60,
            value: label,
            angle: angle,
            color: 2
        )
    }

    private static func mebelDXF(
        assembly: FurnitureAssembly,
        placement: FurniturePlacement,
        wallSeg: ContourSegment2D,
        isCCW: Bool
    ) -> String {
        let startX = wallSeg.start.x.rawValue
        let startY = wallSeg.start.y.rawValue
        let endX   = wallSeg.end.x.rawValue
        let endY   = wallSeg.end.y.rawValue

        let segLen = hypot(endX - startX, endY - startY)
        guard segLen > 0 else { return "" }

        // Wall direction unit vector
        let dirX = (endX - startX) / segLen
        let dirY = (endY - startY) / segLen

        // Inward normal (into room)
        // CCW polygon: left-hand normal = (-dirY, dirX)
        // CW polygon:  right-hand normal = (dirY, -dirX)
        let normX = isCCW ? -dirY : dirY
        let normY = isCCW ?  dirX : -dirX

        let along  = placement.offsetAlongWall.rawValue
        let fromWall = placement.offsetFromWall.rawValue
        let width  = assembly.size.width.rawValue
        let depth  = assembly.size.depth.rawValue

        // Four corners of furniture footprint (top-down 2D)
        // BL = back-left (closest to wall, wall-start side)
        let blX = startX + dirX * along + normX * fromWall
        let blY = startY + dirY * along + normY * fromWall

        let brX = blX + dirX * width
        let brY = blY + dirY * width

        let frX = brX + normX * depth
        let frY = brY + normY * depth

        let flX = blX + normX * depth
        let flY = blY + normY * depth

        var out = ""

        // Outline (4 lines, closed rect)
        out += lineDXF(layer: "MEBLE", x1: blX, y1: blY, x2: brX, y2: brY, color: 3)
        out += lineDXF(layer: "MEBLE", x1: brX, y1: brY, x2: frX, y2: frY, color: 3)
        out += lineDXF(layer: "MEBLE", x1: frX, y1: frY, x2: flX, y2: flY, color: 3)
        out += lineDXF(layer: "MEBLE", x1: flX, y1: flY, x2: blX, y2: blY, color: 3)

        // Cross-hair inside
        out += lineDXF(layer: "MEBLE", x1: blX, y1: blY, x2: frX, y2: frY, color: 3)
        out += lineDXF(layer: "MEBLE", x1: brX, y1: brY, x2: flX, y2: flY, color: 3)

        // Label at centroid
        let cx = (blX + frX) / 2
        let cy = (blY + frY) / 2
        let dx = dirX
        let dy = dirY
        var angle = atan2(dy, dx) * 180 / Double.pi
        if angle > 90 || angle < -90 { angle += 180 }

        out += textDXF(
            layer: "MEBLE",
            x: cx,
            y: cy,
            height: 40,
            value: assembly.name,
            angle: angle,
            color: 3
        )

        // Dimension: width along wall
        let dimLabelX = (blX + brX) / 2 - normX * 120
        let dimLabelY = (blY + brY) / 2 - normY * 120
        out += textDXF(
            layer: "KOTA",
            x: dimLabelX,
            y: dimLabelY,
            height: 50,
            value: formatMM(width),
            angle: angle,
            color: 2
        )

        return out
    }

    private static func legenda(
        zestawy: [FurnitureAssembly],
        bbox: (minX: Double, minY: Double, maxX: Double, maxY: Double)
    ) -> String {
        guard !zestawy.isEmpty else { return "" }

        var out = ""
        let startX = bbox.maxX + 500   // 500mm offset to the right of room
        var y = bbox.maxY

        let lineHeight: Double = 150
        let textHeight: Double = 80
        let titleHeight: Double = 100

        // Title
        out += textDXF(
            layer: "LEGENDA",
            x: startX,
            y: y,
            height: titleHeight,
            value: "LEGENDA MEBLI",
            angle: 0,
            color: 5
        )
        y -= lineHeight * 1.5

        // Header row
        out += textDXF(
            layer: "LEGENDA",
            x: startX,
            y: y,
            height: textHeight,
            value: "Lp.  Nazwa                    W x H x D [mm]",
            angle: 0,
            color: 5
        )
        y -= lineHeight

        // Items
        for (i, assembly) in zestawy.enumerated() {
            let w = Int(assembly.size.width.rawValue)
            let h = Int(assembly.size.height.rawValue)
            let d = Int(assembly.size.depth.rawValue)
            let nameClipped = String(assembly.name.prefix(24))
                .padding(toLength: 24, withPad: " ", startingAt: 0)
            let row = "\(i + 1). \(nameClipped) \(w) x \(h) x \(d)"
            out += textDXF(
                layer: "LEGENDA",
                x: startX,
                y: y,
                height: textHeight,
                value: row,
                angle: 0,
                color: 5
            )
            y -= lineHeight
        }

        return out
    }

    // MARK: - Primitive DXF entities

    private static func lineDXF(
        layer: String,
        x1: Double, y1: Double,
        x2: Double, y2: Double,
        color: Int
    ) -> String {
        "  0\nLINE\n  8\n\(layer)\n 62\n\(color)\n 10\n\(f(x1))\n 20\n\(f(y1))\n 30\n0.0\n 11\n\(f(x2))\n 21\n\(f(y2))\n 31\n0.0\n"
    }

    private static func arcDXF(
        layer: String,
        cx: Double, cy: Double,
        r: Double,
        startAngle: Double,
        endAngle: Double,
        clockwise: Bool,
        color: Int
    ) -> String {
        // DXF ARC always goes CCW from startAngle to endAngle.
        // If domain arc is clockwise, swap angles.
        let sa = clockwise ? endAngle : startAngle
        let ea = clockwise ? startAngle : endAngle
        return "  0\nARC\n  8\n\(layer)\n 62\n\(color)\n 10\n\(f(cx))\n 20\n\(f(cy))\n 30\n0.0\n 40\n\(f(r))\n 50\n\(f(sa))\n 51\n\(f(ea))\n"
    }

    private static func textDXF(
        layer: String,
        x: Double, y: Double,
        height: Double,
        value: String,
        angle: Double,
        color: Int
    ) -> String {
        // DXF TEXT: group 72=1 (middle horizontal), 73=2 (middle vertical), requires second insertion point
        let safeValue = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: "")
        return "  0\nTEXT\n  8\n\(layer)\n 62\n\(color)\n 10\n\(f(x))\n 20\n\(f(y))\n 30\n0.0\n 40\n\(f(height))\n  1\n\(safeValue)\n 50\n\(f(angle))\n"
    }

    // MARK: - Geometry Helpers

    /// Pole ze znakiem — dodatnie = CCW, ujemne = CW
    private static func signedArea(_ contour: ClosedContour2D) -> Double {
        var area = 0.0
        for seg in contour.segments {
            let x1 = seg.start.x.rawValue
            let y1 = seg.start.y.rawValue
            let x2 = seg.end.x.rawValue
            let y2 = seg.end.y.rawValue
            area += (x1 * y2 - x2 * y1)
        }
        return area / 2.0
    }

    private static func boundingBox(
        _ contour: ClosedContour2D
    ) -> (minX: Double, minY: Double, maxX: Double, maxY: Double) {
        var minX = Double.infinity
        var minY = Double.infinity
        var maxX = -Double.infinity
        var maxY = -Double.infinity

        for seg in contour.segments {
            for pt in [seg.start, seg.end] {
                minX = min(minX, pt.x.rawValue)
                minY = min(minY, pt.y.rawValue)
                maxX = max(maxX, pt.x.rawValue)
                maxY = max(maxY, pt.y.rawValue)
            }
        }

        return (
            minX.isFinite ? minX : 0,
            minY.isFinite ? minY : 0,
            maxX.isFinite ? maxX : 0,
            maxY.isFinite ? maxY : 0
        )
    }

    private static func angleDeg(
        from center: Point2MM,
        to point: Point2MM
    ) -> Double {
        let dx = point.x.rawValue - center.x.rawValue
        let dy = point.y.rawValue - center.y.rawValue
        return atan2(dy, dx) * 180 / Double.pi
    }

    // MARK: - Formatting

    private static func f(_ v: Double) -> String {
        String(format: "%.4f", v)
    }

    private static func formatMM(_ mm: Double) -> String {
        if mm >= 1000 {
            return String(format: "%.0f mm (%.2f m)", mm, mm / 1000)
        }
        return String(format: "%.0f mm", mm)
    }
}
