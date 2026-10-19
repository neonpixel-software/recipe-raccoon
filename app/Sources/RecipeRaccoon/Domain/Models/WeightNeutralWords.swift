import Foundation

/// Words in an ingredient name that don't change what a cup or spoon of it weighs, in the
/// languages the app ships in: temperature ("cold", "lauwe", "tiède"), "unsalted" (the butter
/// entry is unsalted butter), oil and extract grades ("extra virgin", "pure"), and, for fats
/// only, softening and melting ("softened", "zachte", "fondu").
///
/// The density lookup drops them only after the exact name finds nothing, so "zachte boter"
/// finds "boter" and "butter, softened" finds "butter". Words that do change what a cup holds
/// aren't here and keep a name from matching: sifted, packed, chopped, and fresh or whole,
/// which name other ingredients (fresh breadcrumbs, whole peppercorns). "Salted" isn't here
/// either: salted butter is a different product from the unsalted entry.
///
/// Words match with or without accents ("a temperature ambiante", "flussige"), since recipes
/// typed on a keyboard without them are common; the words that stay keep their accents.
enum WeightNeutralWords {
    /// German adjectives take an ending that follows the noun's gender and case.
    private static func german(_ stems: [String]) -> [String] {
        stems.flatMap { stem in ["", "e", "en", "er", "es"].map { stem + $0 } }
    }

    /// Temperature, salt and grade: neutral whatever the ingredient.
    private static let anyIngredient = phrases(
        english: [
            "cold", "chilled", "warm", "lukewarm", "room temperature", "at room temperature", "unsalted", "pure",
            "virgin", "extra virgin", "organic", "freshly squeezed",
        ],
        dutch: [
            "koud", "koude", "lauw", "lauwe", "lauwwarm", "lauwwarme", "warm", "warme", "kamertemperatuur",
            "op kamertemperatuur", "ongezouten", "biologisch", "biologische", "extra vierge",
        ],
        german: german(["kalt", "kühl", "gekühlt", "lauwarm", "warm", "zimmerwarm", "ungesalzen"])
            + ["zimmertemperatur", "raumtemperatur", "bio"],
        french: [
            "froid", "froide", "tiède", "à température ambiante", "bio", "vierge", "extra vierge", "vierge extra",
        ],
        spanish: [
            "frío", "fría", "tibio", "tibia", "templado", "templada", "a temperatura ambiente", "sin sal",
            "virgen", "virgen extra", "extra virgen", "ecológico", "ecológica", "orgánico", "orgánica",
        ]
    )

    /// Softening and melting: neutral only for fats and honey, which have no air in them. A cup
    /// of melted chocolate chips or grated cheese weighs far more than a cup of them as they
    /// come, and "soft" also names other products (soft breadcrumbs, soft flour, harina blanda).
    private static let fatsOnly = phrases(
        english: ["softened", "soft", "melted"],
        dutch: ["zacht", "zachte", "gesmolten"],
        german: german(["weich", "zerlassen", "geschmolzen", "flüssig"]),
        french: ["mou", "molle", "ramolli", "ramollie", "fondu", "fondue", "pommade", "en pommade"],
        spanish: [
            "blando", "blanda", "derretido", "derretida", "fundido", "fundida", "pomada", "en pomada",
        ]
    )

    /// The words that name a fat or honey, as they appear in the density entries' names.
    private static let fats = Set(
        [
            "butter", "boter", "roomboter", "beurre", "mantequilla", "manteca", "lard", "reuzel", "schmalz",
            "schweineschmalz", "saindoux", "shortening", "ghee", "margarine", "margarina", "oil", "olie",
            "olijfolie", "kokosolie", "koolzaadolie", "sesamolie", "öl", "olivenöl", "kokosöl", "rapsöl",
            "pflanzenöl", "sesamöl", "huile", "aceite", "honey", "honing", "honig", "miel",
        ].map(fold)
    )

    /// `key` without those words and without commas and brackets, or nil when that leaves it
    /// unchanged or empty. `key` is a lookup key: lower case, single spaces, no hyphens.
    static func removing(from key: String) -> String? {
        let words = key.split { $0.isWhitespace || ",()".contains($0) }
        let folded = words.map { fold(String($0)) }
        let kept = remaining(words, folded, removing: anyIngredient)
        let keptFolded = kept.map { fold(String($0)) }
        let reduced = (keptFolded.contains(where: fats.contains) ? remaining(kept, keptFolded, removing: fatsOnly) : kept)
            .joined(separator: " ")
        return reduced.isEmpty || reduced == key ? nil : reduced
    }

    /// `words` without `phrases`, compared on `folded`, the words without accents.
    private static func remaining(_ words: [Substring], _ folded: [String], removing phrases: [[String]]) -> [Substring] {
        var kept: [Substring] = []
        var index = 0
        while index < words.count {
            if let phrase = phrases.first(where: { folded[index...].starts(with: $0) }) {
                index += phrase.count
            } else {
                kept.append(words[index])
                index += 1
            }
        }
        return kept
    }

    /// Without accents, single spaces and longest first, so "at room temperature" goes as a
    /// whole before "room temperature".
    private static func phrases(english: [String], dutch: [String], german: [String], french: [String], spanish: [String]) -> [[String]] {
        Set((english + dutch + german + french + spanish).map(fold))
            .map { $0.split(separator: " ").map(String.init) }
            .sorted { $0.count > $1.count }
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: .diacriticInsensitive, locale: nil)
    }
}
