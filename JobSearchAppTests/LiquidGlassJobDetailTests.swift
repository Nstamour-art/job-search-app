import Testing
@testable import JobSearchApp

struct LiquidGlassJobDetailTests {
    @available(iOS 26, *)
    @Test("priorityCardStyle uses glass on iOS 26")
    func priorityCardUsesGlassOn26() {
        #expect(priorityCardStyle() == .glass(cornerRadius: 12))
    }

    @available(iOS, introduced: 17, obsoleted: 26)
    @Test("priorityCardStyle uses material fallback before iOS 26")
    func priorityCardUsesMaterialFallback() {
        #expect(priorityCardStyle() == .material(cornerRadius: 12))
    }
}
