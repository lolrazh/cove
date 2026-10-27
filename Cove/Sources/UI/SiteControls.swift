import SwiftUI

/// The glyph at the front of the URL pill and the address field: a lock,
/// globe or search glyph. On a website it opens that site's controls, as
/// Arc's does; on a start page it's only a glyph.
///
/// Every tab layout has one of these on screen, and only that one presents
/// the controls, so the Command Bar's Site Settings opens a single popover.
struct SiteControlsButton: View {
    @ObservedObject var tabManager: TabManager
    @ObservedObject var page: TabSession
    let presentsControls: Bool

    var body: some View {
        if page.siteURL == nil {
            glyphImage
                .frame(width: Self.side, height: Self.side)
        } else {
            Button {
                tabManager.isShowingSiteControls.toggle()
            } label: {
                glyphImage
            }
            .buttonStyle(ChromeButtonStyle(size: .accessory(side: Self.side)))
            .help("Site Settings")
            .popover(isPresented: isPresented, arrowEdge: .bottom) {
                SiteControlsPanel(
                    page: page,
                    permissions: page.sitePermissions,
                    boosts: page.boostStore,
                    onEditBoost: editBoost,
                    onClearData: tabManager.clearSiteData
                )
            }
        }
    }

    static let side: CGFloat = 20

    private var isPresented: Binding<Bool> {
        Binding(
            get: { presentsControls && tabManager.isShowingSiteControls },
            set: { tabManager.isShowingSiteControls = $0 }
        )
    }

    /// Boosts are made and changed in normal windows only.
    private var editBoost: (() -> Void)? {
        guard tabManager.canBoost else { return nil }
        return { tabManager.editBoost() }
    }

    private var glyphImage: some View {
        Image(systemName: glyph)
            .foregroundStyle(.secondary)
    }

    private var glyph: String {
        switch page.siteURL?.scheme {
        case nil: page.currentURL.isEmpty ? ChromeSymbols.Navigation.search : ChromeSymbols.Navigation.globe
        case "https": ChromeSymbols.Navigation.secure
        default: ChromeSymbols.Navigation.globe
        }
    }
}

/// Arc's site controls: who the site is and how it was reached, then what it
/// may do here (blocking, zoom, its Boost, the camera, microphone and
/// location), then clearing what it stored.
struct SiteControlsPanel: View {
    @ObservedObject var page: TabSession
    @ObservedObject var permissions: SitePermissions
    /// Watched so the Boost row follows the site's Boost.
    @ObservedObject var boosts: BoostStore
    /// Nil where Boosts can't be edited: in a private window.
    let onEditBoost: (() -> Void)?
    let onClearData: () -> Void

    @State private var zoom: Double = 1
    @State private var blocksContent = true

    private enum Metrics {
        static let width: CGFloat = 300
        static let rowHeight: CGFloat = 30
        static let inset: CGFloat = 12
        static let iconWidth: CGFloat = 18
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(Metrics.inset)

            Divider()

            VStack(spacing: 0) {
                contentBlockingRow
                zoomRow
                if let onEditBoost {
                    boostRow(onEdit: onEditBoost)
                }
            }
            .padding(.vertical, 6)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                Text("Permissions")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Metrics.inset)
                    .padding(.bottom, 2)

                ForEach(SitePermissions.Device.allCases, id: \.self, content: permissionRow)
            }
            .padding(.vertical, 8)

            Divider()

            Button(action: onClearData) {
                Label("Clear Site Data", systemImage: "trash")
                    .padding(.horizontal, 8)
                    .frame(height: Metrics.rowHeight)
            }
            .buttonStyle(ChromeButtonStyle(size: .row))
            .help("Remove cookies, storage and cache for \(domain), and reload")
            .padding(6)
        }
        .frame(width: Metrics.width)
        .onAppear {
            zoom = page.pageZoom
            blocksContent = page.blocksContent
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            FaviconView(image: page.favicon, size: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(domain)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                security
            }
        }
    }

    private var security: some View {
        let security = page.connectionSecurity
        return VStack(alignment: .leading, spacing: 2) {
            Label(security.title, systemImage: security.symbol)
                .foregroundStyle(security.level == .secure ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))

            if let certificate = security.certificate {
                Text(certificate.summary)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.callout)
        .textSelection(.enabled)
    }

    // MARK: - Rows

    private var contentBlockingRow: some View {
        row("Block Ads and Trackers", symbol: ChromeSymbols.Settings.privacy) {
            Toggle("Block Ads and Trackers", isOn: $blocksContent)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .disabled(!page.canChangeContentBlocking)
                .onChange(of: blocksContent) { _, blocks in
                    guard blocks != page.blocksContent else { return }
                    page.setBlocksContent(blocks)
                }
        }
        .help(page.canChangeContentBlocking ? "" : "Content blocking is off for every site in Settings")
    }

    private var zoomRow: some View {
        row("Zoom", symbol: "plus.magnifyingglass") {
            HStack(spacing: 2) {
                Button {
                    setZoom(PageZoom.zoomedOut(from: zoom))
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(PageZoom.zoomedOut(from: zoom) == nil)
                .help("Zoom Out")

                Button {
                    setZoom(1)
                } label: {
                    Text(zoom.formatted(.percent))
                        .monospacedDigit()
                        .frame(minWidth: 40)
                }
                .help("Actual Size")

                Button {
                    setZoom(PageZoom.zoomedIn(from: zoom))
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(PageZoom.zoomedIn(from: zoom) == nil)
                .help("Zoom In")
            }
            .buttonStyle(ChromeButtonStyle(size: .accessory(side: 22)))
        }
    }

    /// The site's Boost, on or off, and a way into the editor; or, for a
    /// site without one, an offer to make one.
    @ViewBuilder
    private func boostRow(onEdit: @escaping () -> Void) -> some View {
        if let boost = page.boost {
            row("Boost", symbol: ChromeSymbols.Navigation.boost) {
                Button("Edit", action: onEdit)
                    .buttonStyle(.link)
                    .help("Edit the Boost for \(boost.domain)")
                Toggle("Boost", isOn: Binding(get: { boost.isEnabled }, set: page.setBoostEnabled))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
        } else {
            Button(action: onEdit) {
                Label("Boost This Site", systemImage: ChromeSymbols.Navigation.boost)
                    .padding(.horizontal, 6)
                    .frame(height: Metrics.rowHeight)
            }
            .buttonStyle(ChromeButtonStyle(size: .row))
            .help("Change how \(domain) looks with colors, fonts, hidden elements and code")
            .padding(.horizontal, 6)
        }
    }

    private func permissionRow(_ device: SitePermissions.Device) -> some View {
        row(device.title, symbol: device.symbol) {
            Picker(device.title, selection: answer(for: device)) {
                Text("Ask").tag(Bool?.none)
                Text("Allow").tag(Bool?.some(true))
                Text("Block").tag(Bool?.some(false))
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .buttonStyle(.borderless)
            .fixedSize()
        }
    }

    private func row(_ title: String, symbol: String, @ViewBuilder control: () -> some View) -> some View {
        HStack(spacing: 8) {
            // A fixed column, so titles line up whatever their icon's width.
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: Metrics.iconWidth)
            Text(title)
            Spacer(minLength: 8)
            control()
        }
        .padding(.horizontal, Metrics.inset)
        .frame(height: Metrics.rowHeight)
    }

    // MARK: - State

    private var domain: String {
        Site(page.siteURL)?.domain ?? page.currentURL
    }

    private func setZoom(_ newZoom: Double?) {
        guard let newZoom else { return }
        zoom = newZoom
        page.pageZoom = newZoom
    }

    private func answer(for device: SitePermissions.Device) -> Binding<Bool?> {
        let origin = page.siteURL.flatMap(SitePermissions.Origin.init)
        return Binding(
            get: { origin.flatMap { permissions.answer(for: device, at: $0) } },
            set: { answer in
                guard let origin else { return }
                permissions.setAnswer(answer, for: device, at: origin)
            }
        )
    }
}

private extension ConnectionSecurity {
    var title: String {
        switch level {
        case .secure: "Connection is secure"
        case .mixedContent: "Parts of this page are not secure"
        case .notSecure: "Connection is not secure"
        }
    }

    var symbol: String {
        switch level {
        case .secure: ChromeSymbols.Navigation.secure
        case .mixedContent, .notSecure: "lock.open.fill"
        }
    }
}

private extension ConnectionSecurity.Certificate {
    /// "Issued to example.com by R11, valid until 3 Jan 2027"
    var summary: String {
        var summary = "Issued to \(subject)"
        if let issuer { summary += " by \(issuer)" }
        if let expires { summary += ", valid until \(expires.formatted(date: .abbreviated, time: .omitted))" }
        return summary
    }
}

private extension SitePermissions.Device {
    var title: String {
        name.capitalized
    }

    var symbol: String {
        switch self {
        case .camera: "camera"
        case .microphone: "mic"
        case .location: "location"
        }
    }
}
