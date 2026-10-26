import AppKit
import WebKit

/// Native sheets for what a page asks of the user. Each is an `NSAlert` on the
/// page's window that names the site asking, so a page can't pass its dialog
/// off as one of Cove's.
@MainActor
enum PageDialogs {
    static func alert(_ message: String, from frame: WKFrameInfo, in window: NSWindow) async {
        let alert = pageAlert(message, from: frame)
        _ = await alert.beginSheetModal(for: window)
    }

    static func confirm(_ message: String, from frame: WKFrameInfo, in window: NSWindow) async -> Bool {
        let alert = pageAlert(message, from: frame)
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        return await alert.beginSheetModal(for: window) == .alertFirstButtonReturn
    }

    static func prompt(
        _ message: String,
        defaultText: String?,
        from frame: WKFrameInfo,
        in window: NSWindow
    ) async -> String? {
        let alert = pageAlert(message, from: frame)
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(string: defaultText ?? "")
        field.frame.size.width = fieldWidth
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard await alert.beginSheetModal(for: window) == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }

    /// Asks for a user name and password for a site behind HTTP authentication.
    static func logIn(
        to challenge: URLAuthenticationChallenge,
        in window: NSWindow
    ) async -> URLCredential? {
        let space = challenge.protectionSpace
        let alert = NSAlert()
        alert.messageText = "Log in to \(space.host)"
        alert.informativeText = if challenge.previousFailureCount > 0 {
            "The user name or password was incorrect."
        } else if space.receivesCredentialSecurely {
            "Your login information will be sent securely."
        } else {
            "Your login information will be sent unencrypted."
        }
        alert.addButton(withTitle: "Log In")
        alert.addButton(withTitle: "Cancel")

        let user = NSTextField(string: challenge.proposedCredential?.user ?? "")
        user.placeholderString = "User Name"
        let password = NSSecureTextField()
        password.placeholderString = "Password"
        let fields = NSStackView(views: [user, password])
        fields.orientation = .vertical
        for field in [user, password] {
            field.widthAnchor.constraint(equalToConstant: fieldWidth).isActive = true
        }
        fields.frame.size = fields.fittingSize
        alert.accessoryView = fields
        alert.window.initialFirstResponder = user
        user.nextKeyView = password

        guard await alert.beginSheetModal(for: window) == .alertFirstButtonReturn else { return nil }
        return URLCredential(user: user.stringValue, password: password.stringValue, persistence: .forSession)
    }

    // MARK: - Private

    /// Wide enough for a URL or a sentence, like the fields in system alerts.
    private static let fieldWidth: CGFloat = 240

    private static func pageAlert(_ message: String, from frame: WKFrameInfo) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "\(siteName(frame.securityOrigin)) says"
        alert.informativeText = message
        return alert
    }

    /// The host, or a plain description for pages without one, like files.
    private static func siteName(_ origin: WKSecurityOrigin) -> String {
        origin.host.isEmpty ? "This page" : origin.host
    }
}
