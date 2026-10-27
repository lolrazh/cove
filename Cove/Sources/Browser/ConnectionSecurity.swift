import Foundation
import Security

/// How the page reached Cove, as site controls tell it: encrypted, with the
/// certificate WebKit accepted, or not.
struct ConnectionSecurity {
    enum Level {
        case secure
        /// The page came over HTTPS but loaded some of its parts without it.
        case mixedContent
        case notSecure
    }

    /// The site's certificate, as much of it as people read.
    struct Certificate {
        let subject: String
        let issuer: String?
        let expires: Date?

        init?(_ trust: SecTrust) {
            guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
                  let leaf = chain.first,
                  let subject = SecCertificateCopySubjectSummary(leaf) as String? else { return nil }
            self.subject = subject
            self.issuer = chain.dropFirst().first.flatMap { SecCertificateCopySubjectSummary($0) as String? }
            self.expires = SecCertificateCopyNotValidAfterDate(leaf) as Date?
        }
    }

    let level: Level
    let certificate: Certificate?

    /// WebKit only shows a page whose certificate it trusted, so an HTTPS page
    /// with a certificate is secure, unless parts of it weren't encrypted.
    init(url: URL?, trust: SecTrust?, hasOnlySecureContent: Bool) {
        certificate = trust.flatMap(Certificate.init)
        level = if url?.scheme == "https", certificate != nil {
            hasOnlySecureContent ? .secure : .mixedContent
        } else {
            .notSecure
        }
    }
}
