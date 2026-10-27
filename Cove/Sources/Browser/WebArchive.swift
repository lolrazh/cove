import Foundation

/// Reads WebKit's web archive format, a property list of the page's
/// resources. Its main resource is the page's HTML exactly as the server sent
/// it, before any script changed the document: what View Source shows.
enum WebArchive {
    struct MainResource {
        let data: Data
        let encoding: String.Encoding

        var text: String? {
            String(data: data, encoding: encoding) ?? String(data: data, encoding: .isoLatin1)
        }
    }

    static func mainResource(in archive: Data) -> MainResource? {
        guard let plist = try? PropertyListSerialization.propertyList(from: archive, format: nil) as? [String: Any],
              let resource = plist["WebMainResource"] as? [String: Any],
              let data = resource["WebResourceData"] as? Data else { return nil }

        let encoding = (resource["WebResourceTextEncodingName"] as? String).flatMap(stringEncoding) ?? .utf8
        return MainResource(data: data, encoding: encoding)
    }

    /// An IANA charset name, like "UTF-8" or "windows-1252", as a Swift encoding.
    private static func stringEncoding(named name: String) -> String.Encoding? {
        let encoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
        guard encoding != kCFStringEncodingInvalidId else { return nil }
        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(encoding))
    }
}
