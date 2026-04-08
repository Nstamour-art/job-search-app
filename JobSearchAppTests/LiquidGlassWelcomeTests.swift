import Testing
@testable import JobSearchApp

struct LiquidGlassWelcomeTests {
    @available(iOS 26, *)
    @Test("Welcome CTA uses glassProminent on iOS 26")
    func glassCTAOn26() {
        #expect(welcomeCTAStyle() == .glassProminent)
    }

    @available(iOS, introduced: 17, obsoleted: 26)
    @Test("Welcome CTA uses accent fallback before iOS 26")
    func fallbackCTA() {
        #expect(welcomeCTAStyle() == .fallbackAccent)
    }
}
