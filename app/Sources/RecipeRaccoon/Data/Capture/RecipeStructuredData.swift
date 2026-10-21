import Foundation

/// Reads the schema.org `Recipe` JSON-LD most recipe sites embed for search engines, and turns
/// it into compact plain text for the model. A whole page flattened to text is mostly site
/// navigation and ads and overflows the on-device model's 4,096-token context (issue #74); the
/// JSON-LD is just the recipe. The model still does the structuring (amount/unit/name), so this
/// feeds the same capture pipeline rather than bypassing it.
enum RecipeStructuredData {
    static func recipeText(fromHTML html: String) -> String? {
        for json in jsonLDBlocks(in: html) {
            guard let data = json.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data),
                  let recipe = findRecipe(in: object),
                  let text = format(recipe) else { continue }
            return text
        }
        return nil
    }

    private static func jsonLDBlocks(in html: String) -> [String] {
        let pattern = #"<script[^>]*type\s*=\s*["']?application/ld\+json["']?[^>]*>(.*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(html.startIndex..., in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            Range(match.range(at: 1), in: html).map { String(html[$0]) }
        }
    }

    /// Recipes appear at the top level, inside a top-level array, or as one node of an `@graph`,
    /// with `@type` either "Recipe" or an array containing it.
    private static func findRecipe(in object: Any) -> [String: Any]? {
        if let array = object as? [Any] {
            return array.lazy.compactMap(findRecipe(in:)).first
        }
        guard let dictionary = object as? [String: Any] else { return nil }
        if isRecipe(dictionary["@type"]) {
            return dictionary
        }
        return dictionary["@graph"].flatMap(findRecipe(in:))
    }

    private static func isRecipe(_ type: Any?) -> Bool {
        if let type = type as? String { return type == "Recipe" }
        if let types = type as? [String] { return types.contains("Recipe") }
        return false
    }

    private static func format(_ recipe: [String: Any]) -> String? {
        let ingredients = ingredientLines(from: recipe["recipeIngredient"])
        let steps = instructionSteps(from: recipe["recipeInstructions"])
        guard !ingredients.isEmpty || !steps.isEmpty else { return nil }

        var sections: [String] = []
        if let name = recipe["name"] as? String, !cleaned(name).isEmpty {
            sections.append(cleaned(name))
        }
        if let yield = yieldText(from: recipe["recipeYield"]) {
            // A "Yield:" line, so the servings check (CapturedServings) finds the number.
            sections.append("Yield: \(yield)")
        }
        if !ingredients.isEmpty {
            sections.append((["Ingredients:"] + ingredients.map { "- \($0)" }).joined(separator: "\n"))
        }
        if !steps.isEmpty {
            let numbered = steps.enumerated().map { "\($0.offset + 1). \($0.element)" }
            sections.append((["Steps:"] + numbered).joined(separator: "\n"))
        }
        return sections.joined(separator: "\n\n")
    }

    /// `recipeIngredient` is usually an array of strings, but schema.org also allows a single
    /// string, which is split on line breaks like single-string `recipeInstructions`.
    private static func ingredientLines(from value: Any?) -> [String] {
        let items = value as? [Any] ?? (value as? String)?.components(separatedBy: .newlines) ?? []
        return items.compactMap { $0 as? String }.map(cleaned).filter { !$0.isEmpty }
    }

    /// `recipeYield` is a string ("4 servings"), a number, or an array of either (["8", "1 loaf"]).
    private static func yieldText(from value: Any?) -> String? {
        let items = value as? [Any] ?? value.map { [$0] } ?? []
        let texts = items.compactMap { item -> String? in
            if let text = item as? String { return cleaned(text) }
            return (item as? NSNumber).map(\.stringValue)
        }.filter { !$0.isEmpty }
        return texts.isEmpty ? nil : texts.joined(separator: ", ")
    }

    /// `recipeInstructions` may be one string, an array of strings, `HowToStep`s, or
    /// `HowToSection`s whose `itemListElement` holds more steps.
    private static func instructionSteps(from value: Any?) -> [String] {
        switch value {
        case let text as String:
            text.components(separatedBy: .newlines).map(cleaned).filter { !$0.isEmpty }
        case let items as [Any]:
            items.flatMap(instructionSteps(from:))
        case let item as [String: Any]:
            if let children = item["itemListElement"] {
                instructionSteps(from: children)
            } else {
                instructionSteps(from: item["text"] ?? item["name"])
            }
        default:
            []
        }
    }

    /// JSON-LD strings often still carry HTML entities and inline markup.
    private static func cleaned(_ text: String) -> String {
        var result = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        result = decodingEntities(result)
        return result
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "deg": "°", "frac12": "½", "frac14": "¼", "frac34": "¾", "ndash": "–", "mdash": "—",
        "rsquo": "’", "lsquo": "‘", "rdquo": "”", "ldquo": "“", "hellip": "…",
    ]

    private static func decodingEntities(_ text: String) -> String {
        guard text.contains("&"),
              let regex = try? NSRegularExpression(pattern: "&(#[0-9]+|#[xX][0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);") else {
            return text
        }
        var result = ""
        var cursor = text.startIndex
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let whole = Range(match.range, in: text), let body = Range(match.range(at: 1), in: text) else { continue }
            result += text[cursor..<whole.lowerBound]
            result += replacement(forEntity: String(text[body])) ?? String(text[whole])
            cursor = whole.upperBound
        }
        result += text[cursor...]
        return result
    }

    private static func replacement(forEntity entity: String) -> String? {
        guard entity.hasPrefix("#") else { return namedEntities[entity] }
        let isHex = entity.dropFirst().first.map { $0 == "x" || $0 == "X" } ?? false
        let digits = entity.dropFirst(isHex ? 2 : 1)
        return UInt32(digits, radix: isHex ? 16 : 10).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
    }
}
