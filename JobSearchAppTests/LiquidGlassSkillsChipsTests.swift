import Testing
@testable import JobSearchApp

struct LiquidGlassSkillsChipsTests {
    @available(iOS 26, *)
    @Test("Skills chips use glass on iOS 26")
    func chipsGlassOn26() {
        #expect(skillChipStyle() == .glass)
    }

    @available(iOS, introduced: 17, obsoleted: 26)
    @Test("Skills chips use material fallback before iOS 26")
    func chipsMaterialFallback() {
        #expect(skillChipStyle() == .material)
    }
}
