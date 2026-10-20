@testable import RecipeRaccoon
import XCTest

/// Verifies the String Catalog entries for the 6 capture-failure messages that
/// RecipeCaptureViewModel/RecipeURLCaptureViewModel assign via String(localized:) — reading the
/// compiled catalog output directly per language (see LocalizationTestHelper) makes this
/// deterministic regardless of the test process's own system language.
final class LocalizedCaptureErrorMessagesTests: XCTestCase {
    private let messages: [String: [String: String]] = [
        "Couldn't extract a recipe from that text. Check it over and try again.": [
            "es": "No se pudo extraer una receta de ese texto. Revísalo e inténtalo de nuevo.",
            "fr": "Impossible d'extraire une recette de ce texte. Vérifiez-le et réessayez.",
            "de": "Aus diesem Text konnte kein Rezept extrahiert werden. Überprüfe ihn und versuche es erneut.",
            "nl": "Er kon geen recept uit deze tekst worden gehaald. Controleer het en probeer het opnieuw.",
        ],
        "Couldn't load that page. Check the link and try again.": [
            "es": "No se pudo cargar esa página. Comprueba el enlace e inténtalo de nuevo.",
            "fr": "Impossible de charger cette page. Vérifiez le lien et réessayez.",
            "de": "Diese Seite konnte nicht geladen werden. Überprüfe den Link und versuche es erneut.",
            "nl": "Die pagina kon niet worden geladen. Controleer de link en probeer het opnieuw.",
        ],
        "That page is too large to read. Try a link to just the recipe.": [
            "es": "Esa página es demasiado grande para leerla. Prueba con un enlace directo a la receta.",
            "fr": "Cette page est trop volumineuse pour être lue. Essayez un lien vers la recette seule.",
            "de": "Diese Seite ist zu groß zum Lesen. Versuche einen Link, der nur zum Rezept führt.",
            "nl": "Die pagina is te groot om te lezen. Probeer een link die alleen naar het recept verwijst.",
        ],
        "That site doesn't use a secure connection (https), so it can't be opened.": [
            "es": "Ese sitio no usa una conexión segura (https), por lo que no se puede abrir.",
            "fr": "Ce site n'utilise pas de connexion sécurisée (https) et ne peut donc pas être ouvert.",
            "de": "Diese Website verwendet keine sichere Verbindung (https) und kann daher nicht geöffnet werden.",
            "nl": "Die site gebruikt geen beveiligde verbinding (https) en kan daarom niet worden geopend.",
        ],
        "That site doesn't let apps read its pages. Copy the recipe from the site and paste it into Type It.": [
            "es": "Ese sitio no deja que las apps lean sus páginas. Copia la receta del sitio y pégala en Escribirlo.",
            "fr": "Ce site ne laisse pas les apps lire ses pages. Copiez la recette depuis le site et collez-la dans «\u{00A0}Le taper\u{00A0}».",
            "de": "Diese Website lässt Apps ihre Seiten nicht lesen. Kopiere das Rezept von der Website und füge es bei Eingeben ein.",
            "nl": "Die site laat apps haar pagina's niet lezen. Kopieer het recept van de site en plak het bij Typen.",
        ],
        "Couldn't find a recipe on that page. Check it over and try again.": [
            "es": "No se encontró ninguna receta en esa página. Revísala e inténtalo de nuevo.",
            "fr": "Aucune recette trouvée sur cette page. Vérifiez-la et réessayez.",
            "de": "Auf dieser Seite wurde kein Rezept gefunden. Überprüfe sie und versuche es erneut.",
            "nl": "Er is geen recept gevonden op die pagina. Controleer het en probeer het opnieuw.",
        ],
    ]

    func testEachCaptureErrorMessageTranslatesPerLocale() {
        for (key, translations) in messages {
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
