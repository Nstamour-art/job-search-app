import Testing
@testable import JobSearchApp

struct LiquidGlassDiscoverTests {
    @available(iOS 26, *)
    @Test("Discover overlay uses glass on iOS 26")
    func overlayGlassOn26() {
        #expect(discoverOverlayStyle() == .glass(cornerRadius: 12))
    }

    @available(iOS, introduced: 17, obsoleted: 26)
    @Test("Discover overlay uses plain fallback before iOS 26")
    func overlayPlainFallback() {
        #expect(discoverOverlayStyle() == .plain)
    }
}
