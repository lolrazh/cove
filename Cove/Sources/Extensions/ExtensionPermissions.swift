import AppKit
import SwiftUI
import WebKit

/// What an extension asks to be allowed, said the way the sheet says it:
/// when it's added, everything its manifest asks for; later, what it asks
/// for while running.
struct ExtensionPermissionRequest {
    let name: String
    let icon: NSImage?
    let lines: [String]
    /// The review when adding an extension, rather than a running one asking.
    let isInstall: Bool

    @MainActor
    init(_ webExtension: WKWebExtension, permissions: [String] = [], sites: [String] = [], isInstall: Bool = false) {
        name = webExtension.displayName ?? "This extension"
        icon = webExtension.icon(for: CGSize(width: 64, height: 64))
        let lines = Self.lines(permissions: permissions, sites: sites)
        // A running extension asking only for something harmless still says what.
        self.lines = lines.isEmpty && !isInstall && !permissions.isEmpty
            ? ["Use \(ListFormatter.localizedString(byJoining: permissions.sorted()))"]
            : lines
        self.isInstall = isInstall
    }

    /// The review for a candidate: all it asks for when it's added.
    @MainActor
    init(installing webExtension: WKWebExtension) {
        self.init(
            webExtension,
            permissions: webExtension.requestedPermissions.map(\.rawValue),
            sites: webExtension.allRequestedMatchPatterns.map(\.string),
            isInstall: true
        )
    }

    /// Plain sentences for what matters: access to sites first, then the
    /// permissions that reach beyond the extension itself. Ones that don't,
    /// like storage or alarms, go unmentioned, as in Chrome.
    static func lines(permissions: [String], sites: [String]) -> [String] {
        [siteLine(sites)].compactMap { $0 } + Set(permissions).sorted().compactMap(description)
    }

    /// Sites as match patterns (`*://*.example.com/*`) or bare hosts.
    static func siteLine(_ sites: [String]) -> String? {
        if sites.contains(where: allSites.contains) {
            return "Read and change your data on all websites"
        }
        let hosts = Set(sites.compactMap(host)).sorted()
        guard let first = hosts.first else { return nil }
        let list = switch hosts.count {
        case 1: first
        case 2: "\(first) and \(hosts[1])"
        case 3: "\(first), \(hosts[1]) and \(hosts[2])"
        default: "\(first), \(hosts[1]) and \(hosts.count - 2) other sites"
        }
        return "Read and change your data on \(list)"
    }

    /// A site as Settings lists it: by host, or as all websites.
    static func siteName(_ site: String) -> String {
        allSites.contains(site) ? "All websites" : host(of: site) ?? site
    }

    /// Patterns that match every site.
    private static let allSites: Set<String> = ["<all_urls>", "*://*/*", "http://*/*", "https://*/*"]

    private static func host(of site: String) -> String? {
        let afterScheme = site.components(separatedBy: "://").last ?? site
        let host = afterScheme.prefix { $0 != "/" && $0 != ":" }
        let bare = host.hasPrefix("*.") ? host.dropFirst(2) : host
        return bare.isEmpty || bare == "*" ? nil : String(bare)
    }

    /// What a permission lets an extension do, for those worth saying.
    static func description(of permission: String) -> String? {
        switch permission {
        case "tabs": "See the addresses and titles of your tabs"
        case "webNavigation": "See the pages you visit"
        case "cookies": "Read and change cookies on sites it can access"
        case "webRequest": "See network requests on sites it can access"
        case "declarativeNetRequest": "Block content on any page"
        case "declarativeNetRequestWithHostAccess": "Block and redirect content on sites it can access"
        case "clipboardWrite": "Change what's on the clipboard"
        case "nativeMessaging": "Talk to other apps on your Mac"
        default: nil
        }
    }
}

/// Asks in a sheet on a browser window. With several requests at once, the
/// window shows them one after another.
@MainActor
enum ExtensionPermissionPrompt {
    static func ask(_ request: ExtensionPermissionRequest, in window: NSWindow) async -> Bool {
        await withCheckedContinuation { continuation in
            let host = NSHostingController(rootView: AnyView(EmptyView()))
            let sheet = NSWindow(contentViewController: host)
            host.rootView = AnyView(ExtensionPermissionSheet(request: request) { isAllowed in
                window.endSheet(sheet)
                continuation.resume(returning: isAllowed)
            })
            window.beginSheet(sheet)
        }
    }
}

/// The sheet: the extension's icon and name, what it would be allowed, and
/// the choice. Used for adding an extension and for a running one asking.
struct ExtensionPermissionSheet: View {
    let request: ExtensionPermissionRequest
    let onDecision: (Bool) -> Void

    var body: some View {
        VStack(spacing: 16) {
            ExtensionIcon(image: request.icon, size: 56)

            Text(request.isInstall ? "Add \u{201C}\(request.name)\u{201D}?" : "\u{201C}\(request.name)\u{201D} would like to")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            if request.lines.isEmpty {
                Text("It doesn\u{2019}t ask for access to your data.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(request.lines, id: \.self) { line in
                        Label(line, systemImage: ChromeSymbols.Extensions.permission)
                            .labelStyle(PermissionLabelStyle())
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ChromePalette.resting, in: .rect(cornerRadius: ChromeRadius.tile))
            }

            HStack(spacing: 10) {
                Button { onDecision(false) } label: {
                    Text(request.isInstall ? "Cancel" : "Don\u{2019}t Allow").frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.cancelAction)
                Button { onDecision(true) } label: {
                    Text(request.isInstall ? "Add Extension" : "Allow").frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        }
        .padding(24)
        .frame(width: 360)
    }
}

private struct PermissionLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon
                .foregroundStyle(.secondary)
            configuration.title
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// An extension's icon, or a puzzle piece for one without.
struct ExtensionIcon: View {
    let image: NSImage?
    let size: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: ChromeSymbols.Extensions.extensions)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.15)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}
