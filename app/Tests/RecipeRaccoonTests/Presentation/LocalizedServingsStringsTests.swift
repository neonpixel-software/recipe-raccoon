@testable import RecipeRaccoon
import XCTest

/// The form's Servings row (Phase 15.1), read per language from the compiled catalog (see
/// LocalizationTestHelper).
final class LocalizedServingsStringsTests: XCTestCase {
    private let strings: [String: [String: String]] = [
        "Servings": ["es": "Raciones", "fr": "Portions", "de": "Portionen", "nl": "Porties"],
        "Set Servings": ["es": "Indicar raciones", "fr": "Indiquer les portions", "de": "Portionen angeben", "nl": "Porties instellen"],
        "Clear Servings": ["es": "Quitar raciones", "fr": "Effacer les portions", "de": "Portionen entfernen", "nl": "Porties wissen"],
    ]

    func testEachServingsStringTranslatesPerLocale() {
        for (key, translations) in strings {
            for (languageCode, translated) in translations {
                XCTAssertEqual(
                    LocalizationTestHelper.translatedString(key, languageCode: languageCode),
                    translated,
                    "\(key) in \(languageCode)"
                )
            }
        }
    }
}
