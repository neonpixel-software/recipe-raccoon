import Foundation

/// Pure helpers for the fetch layer, split out of the HTML loaders so the size and
/// encoding rules can be unit tested without a network round trip.
enum WebPageTextDecoding {
    /// Download cap. Real recipe pages are usually well under this; anything bigger is
    /// almost certainly not a page the model could use.
    static let maxDownloadBytes = 2 * 1024 * 1024

    /// Cap on the converted plain text handed to the model. Its context is 4,096 tokens shared
    /// by the instructions (~50), the CapturedRecipeSchema (~350) and the generated recipe (up to
    /// ~1,000), leaving ~2,500 for page text. Flattened pages measured as low as ~2.7 characters
    /// per token on device, so 6,000 characters fits; 12,000 overflowed on most sites (issue #74).
    static let maxPlainTextCharacters = 6000

    /// Decodes using, in order: the charset the server declared, a `<meta charset>` in the
    /// first KB, UTF-8, then windows-1252 and ISO-8859-1 for legacy pages. ISO-8859-1 maps
    /// every byte, so this only returns nil for empty data.
    static func decode(_ data: Data, declaredEncodingName: String?) -> String? {
        guard !data.isEmpty else { return nil }

        var candidates: [String.Encoding] = []
        if let declared = declaredEncodingName.flatMap(encoding(forName:)) {
            candidates.append(declared)
        }
        if let sniffed = sniffMetaCharset(in: data) {
            candidates.append(sniffed)
        }
        candidates += [.utf8, .windowsCP1252, .isoLatin1]

        for encoding in candidates {
            if let string = String(data: data, encoding: encoding) {
                return string
            }
        }
        return nil
    }

    static func truncated(_ text: String) -> String {
        String(text.prefix(maxPlainTextCharacters))
    }

    /// Appends a downloaded byte to `buffer`, throwing once the size cap is exceeded. Split out
    /// so the streaming fetcher's cap enforcement — not just the `maxDownloadBytes` threshold —
    /// is covered by a unit test rather than only the untested network path.
    static func append(_ byte: UInt8, to buffer: inout Data) throws {
        buffer.append(byte)
        if buffer.count > maxDownloadBytes {
            throw WebPageFetchError.tooLarge
        }
    }

    /// Throws for a non-2xx HTTP status so an error page never reaches the model — a 404 was
    /// otherwise captured as a recipe titled "ERROR 404" (issue #75). Non-HTTP responses pass.
    static func validateStatus(of response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw WebPageFetchError.httpStatus(httpResponse.statusCode)
        }
    }

    private static func encoding(forName name: String) -> String.Encoding? {
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
        guard cfEncoding != kCFStringEncodingInvalidId else { return nil }
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
        // HTML5: iso-8859-1 is an alias for windows-1252 (Latin-1 leaves 0x80–0x9F as C1 controls;
        // browsers decode as CP1252). CP1252 agrees with Latin-1 everywhere else, so this is safe.
        return encoding == .isoLatin1 ? .windowsCP1252 : encoding
    }

    private static func sniffMetaCharset(in data: Data) -> String.Encoding? {
        // Latin-1 maps every byte, so this head is always decodable regardless of the real charset.
        guard let head = String(data: data.prefix(1024), encoding: .isoLatin1),
              let match = head.range(of: #"charset\s*=\s*["']?([A-Za-z0-9_\-]+)"#, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        let name = head[match]
            .drop(while: { $0 != "=" })
            .dropFirst()
            .trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
        return encoding(forName: name)
    }
}
