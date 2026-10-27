import Foundation
import Testing
@testable import Cove

struct WebArchiveTests {
    private func archive(_ data: Data, encoding: String?) throws -> Data {
        var resource: [String: Any] = ["WebResourceData": data, "WebResourceURL": "https://example.com/"]
        resource["WebResourceTextEncodingName"] = encoding
        return try PropertyListSerialization.data(
            fromPropertyList: ["WebMainResource": resource],
            format: .binary,
            options: 0
        )
    }

    @Test func `reads the main resource in its declared encoding`() throws {
        let html = "<p>café</p>"
        let latin1 = try #require(html.data(using: .isoLatin1))
        let data = try archive(latin1, encoding: "ISO-8859-1")
        #expect(WebArchive.mainResource(in: data)?.text == html)
    }

    @Test func `assumes UTF-8 when no encoding is declared`() throws {
        let html = "<p>naïve ✓</p>"
        let data = try archive(Data(html.utf8), encoding: nil)
        #expect(WebArchive.mainResource(in: data)?.text == html)
    }

    @Test func `anything that isn't an archive has no source`() {
        #expect(WebArchive.mainResource(in: Data("<html>".utf8)) == nil)
    }
}
