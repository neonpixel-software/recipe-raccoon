@testable import RecipeRaccoon
import XCTest

/// The filter row's Delete Tag menu and its confirmation (#211), read per language from the
/// compiled catalog (see LocalizationTestHelper).
final class LocalizedDeleteTagStringsTests: XCTestCase {
    private let strings: [String: [String: String]] = [
        "Delete Tag": ["es": "Eliminar etiqueta", "fr": "Supprimer l'étiquette", "de": "Tag löschen", "nl": "Tag verwijderen"],
        "Delete “%@”?": ["es": "¿Eliminar «%@»?", "fr": "Supprimer «\u{00A0}%@\u{00A0}»\u{00A0}?", "de": "„%@“ löschen?", "nl": "‘%@’ verwijderen?"],
        "The tag comes off every recipe that has it. The recipes stay.": [
            "es": "La etiqueta se quita de todas las recetas que la tienen. Las recetas se quedan.",
            "fr": "L'étiquette est retirée de toutes les recettes qui l'ont. Les recettes restent.",
            "de": "Der Tag wird von allen Rezepten entfernt, die ihn haben. Die Rezepte bleiben.",
            "nl": "De tag gaat van alle recepten die hem hebben. De recepten blijven.",
        ],
    ]

    func testEachDeleteTagStringTranslatesPerLocale() {
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
