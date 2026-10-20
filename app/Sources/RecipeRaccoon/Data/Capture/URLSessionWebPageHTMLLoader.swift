import Foundation

/// Not unit tested: a real network round trip isn't exercised in CI or this environment,
/// matching how FoundationModelsRecipeCaptureService's real AI call is treated. The HTTP status
/// check, size cap enforcement and decoding this delegates to (WebPageTextDecoding) are tested
/// independently, and so is what DefaultWebPageFetcher does with the HTML.
final class URLSessionWebPageHTMLLoader: WebPageHTMLLoader {
    func html(from url: URL) async throws -> String {
        let data: Data
        let encodingName: String?
        do {
            let (bytes, response) = try await URLSession.shared.bytes(from: url)
            try WebPageTextDecoding.validateStatus(of: response)
            encodingName = response.textEncodingName
            if response.expectedContentLength > Int64(WebPageTextDecoding.maxDownloadBytes) {
                throw WebPageFetchError.tooLarge
            }
            var buffer = Data()
            buffer.reserveCapacity(WebPageTextDecoding.maxDownloadBytes)
            for try await byte in bytes {
                try WebPageTextDecoding.append(byte, to: &buffer)
            }
            data = buffer
        } catch let error as WebPageFetchError {
            throw error
        } catch let error as URLError where error.code == .appTransportSecurityRequiresSecureConnection {
            throw WebPageFetchError.insecureConnection
        } catch {
            throw WebPageFetchError.requestFailed(underlying: error)
        }

        guard let html = WebPageTextDecoding.decode(data, declaredEncodingName: encodingName) else {
            throw WebPageFetchError.emptyContent
        }
        return html
    }
}
