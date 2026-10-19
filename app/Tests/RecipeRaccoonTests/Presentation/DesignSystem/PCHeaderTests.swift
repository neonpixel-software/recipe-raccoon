import CoreText
@testable import RecipeRaccoon
import ViewInspector
import XCTest

@MainActor
final class PCHeaderTests: XCTestCase {
    /// The band is one line high: a long recipe title used to run off screen, so it ends in "…"
    /// instead. The fill and every outline copy get the limit, or the outline would show where
    /// the fill is cut.
    func testTitleStaysOnOneLineInTheFillAndTheOutline() throws {
        let title = "Het beste bananenbrood recept ooit (super smeuïg en makkelijk)"
        let sut = PCHeader(title: title)

        let texts = try sut.inspect().findAll(ViewType.Text.self)
        XCTAssertEqual(texts.count, 17, "The fill and its 16 outline copies")
        for text in texts {
            XCTAssertEqual(try text.string(), title)
            XCTAssertEqual(try text.lineLimit(), 1)
        }
    }

    // MARK: - Fitting the title

    /// Ten points a character, so a width of 100 holds ten.
    private func width(_ text: String) -> CGFloat {
        CGFloat(text.count * 10)
    }

    func testATitleThatFitsShowsInFull() {
        XCTAssertEqual(HeaderTitleFitting.fitting("Pancakes", in: 100, measure: width), "Pancakes")
        XCTAssertEqual(HeaderTitleFitting.fitting("Ten chars!", in: 100, measure: width), "Ten chars!")
    }

    /// Before layout the width is 0: show the whole title rather than only the dots.
    func testAnUnknownWidthShowsTheTitleInFull() {
        XCTAssertEqual(HeaderTitleFitting.fitting("Het beste bananenbrood", in: 0, measure: width), "Het beste bananenbrood")
    }

    /// The longest start that fits with the three periods, without a space before them.
    func testALongTitleIsCutToFitWithThreePeriods() {
        XCTAssertEqual(HeaderTitleFitting.fitting("Banana bread", in: 100, measure: width), "Banana...")
        XCTAssertEqual(HeaderTitleFitting.fitting("Het beste bananenbrood", in: 120, measure: width), "Het beste...")
    }

    func testCutsBetweenCharactersNotInsideOne() {
        XCTAssertEqual(HeaderTitleFitting.fitting("Crème brûlée maison", in: 90, measure: width), "Crème...")
    }

    /// Measured in the real font, the miljuschka.nl title is cut on the narrowest iPhone (375 pt
    /// less the paddings and outline), and what's left fits.
    func testTheRealFontCutsTheDutchTitleOnAnIPhoneSE() {
        let title = "Het beste bananenbrood recept ooit"
        let available: CGFloat = 375 - 2 * (20 + 1.5)
        let measure = { HeaderTitleFitting.displayWidth(of: $0, size: 34) }
        // CoreText falls back to another font for an unknown name, which would measure wrong.
        XCTAssertEqual(CTFontCopyFamilyName(CTFontCreateWithName("Edo SZ" as CFString, 34, nil)) as String, "Edo SZ")

        let fitted = HeaderTitleFitting.fitting(title, in: available, measure: measure)

        XCTAssertTrue(fitted.hasSuffix("..."), fitted)
        XCTAssertTrue(title.hasPrefix(String(fitted.dropLast(3))), fitted)
        XCTAssertLessThanOrEqual(measure(fitted), available)
        XCTAssertGreaterThan(measure(title), available)
    }
}
