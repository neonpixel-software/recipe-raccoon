@testable import RecipeRaccoon
import XCTest

/// The form's Servings row (Phase 15.1) and the recipe screen's (Phase 15.3), read per language
/// from the compiled catalog (see LocalizationTestHelper).
final class LocalizedServingsStringsTests: XCTestCase {
    private let strings: [String: [String: String]] = [
        "Servings": ["es": "Raciones", "fr": "Portions", "de": "Portionen", "nl": "Porties"],
        "Set Servings": ["es": "Indicar raciones", "fr": "Indiquer les portions", "de": "Portionen angeben", "nl": "Porties instellen"],
        "Clear Servings": ["es": "Quitar raciones", "fr": "Effacer les portions", "de": "Portionen entfernen", "nl": "Porties wissen"],
        "(recipe: %lld)": ["es": "(receta: %lld)", "fr": "(recette\u{00A0}: %lld)", "de": "(Rezept: %lld)", "nl": "(recept: %lld)"],
        "Fewer Servings": ["es": "Menos raciones", "fr": "Moins de portions", "de": "Weniger Portionen", "nl": "Minder porties"],
        "More Servings": ["es": "Más raciones", "fr": "Plus de portions", "de": "Mehr Portionen", "nl": "Meer porties"],
        "Reset Servings": ["es": "Restablecer raciones", "fr": "Rétablir les portions", "de": "Portionen zurücksetzen", "nl": "Porties herstellen"],
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
