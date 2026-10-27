import WebKit

/// The user's answers when sites ask for the camera, microphone or location,
/// remembered per site until Cove quits, so a site asks once per session.
/// Site controls can change an answer or forget it, so the site asks again.
@MainActor
final class SitePermissions: ObservableObject {
    enum Device: CaseIterable {
        case camera, microphone, location

        static func devices(for type: WKMediaCaptureType) -> [Device] {
            switch type {
            case .camera: [.camera]
            case .microphone: [.microphone]
            case .cameraAndMicrophone: [.camera, .microphone]
            @unknown default: [.camera, .microphone]
            }
        }

        var name: String {
            switch self {
            case .camera: "camera"
            case .microphone: "microphone"
            case .location: "location"
            }
        }
    }

    /// Where a request comes from: scheme, host and port. A default port is
    /// left out, so a page's URL and its security origin give the same origin.
    struct Origin: Hashable {
        let scheme: String
        let host: String
        let port: Int?

        init(scheme: String, host: String, port: Int?) {
            self.scheme = scheme.lowercased()
            self.host = host.lowercased()
            let defaultPort = ["http": 80, "https": 443][self.scheme]
            self.port = port == 0 || port == defaultPort ? nil : port
        }

        @MainActor
        init(_ origin: WKSecurityOrigin) {
            self.init(scheme: origin.protocol, host: origin.host, port: origin.port)
        }

        init?(_ url: URL) {
            guard let scheme = url.scheme, let host = url.host(), !host.isEmpty else { return nil }
            self.init(scheme: scheme, host: host, port: url.port)
        }
    }

    private struct Key: Hashable {
        let origin: Origin
        let device: Device
    }

    @Published private var answers: [Key: Bool] = [:]

    /// Whether the site may use the device, or nil if it would ask.
    func answer(for device: Device, at origin: Origin) -> Bool? {
        answers[Key(origin: origin, device: device)]
    }

    /// Changes the answer; nil forgets it, so the site asks next time.
    func setAnswer(_ allowed: Bool?, for device: Device, at origin: Origin) {
        answers[Key(origin: origin, device: device)] = allowed
    }

    /// Grants the devices if the site already has all of them, denies if it was
    /// refused any, and otherwise asks, remembering the answer for each device.
    func decide(
        _ devices: [Device],
        for origin: WKSecurityOrigin,
        ask: () async -> Bool
    ) async -> WKPermissionDecision {
        let keys = devices.map { Key(origin: Origin(origin), device: $0) }
        let known = keys.compactMap { answers[$0] }

        if known.contains(false) { return .deny }
        if known.count == keys.count { return .grant }

        let allowed = await ask()
        for key in keys {
            answers[key] = allowed
        }
        return allowed ? .grant : .deny
    }
}
