import Testing
@testable import DomainCore

struct MillimetersTests {
    @Test
    func arithmeticUsesMillimeters() {
        let width: Millimeters = 600
        let allowance: Millimeters = 20

        #expect(width + allowance == Millimeters(620))
        #expect(width - allowance == Millimeters(580))
        #expect(width / 2 == Millimeters(300))
        #expect(width.meters == 0.6)
    }

    @Test
    func pointTranslationPreservesUnits() {
        let point = Point2MM(x: 100, y: 200)
        let vector = Vector2MM(dx: 25, dy: -10)
        let translated = point + vector

        #expect(translated == Point2MM(x: 125, y: 190))
    }

    @Test
    func sizeValidationRejectsZeroDimension() {
        let size = Size3MM(width: 600, height: 2_000, depth: 0)
        #expect(size.isValid == false)
    }
}
