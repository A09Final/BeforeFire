import Testing
import UIKit
@testable import BeforeFire

@MainActor
struct AppFontTests {
    @Test func emphasisFontIsRegisteredByTheApp() throws {
        let font = try #require(UIFont(name: MonitorStyle.emphasisFontName, size: 32))

        #expect(font.fontName == "BarlowCondensed-ExtraBold")
        #expect(font.familyName == "Barlow Condensed")
    }
}
