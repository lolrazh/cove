import WebKit

/// The user's answers when sites ask for the camera, microphone or location,
/// remembered per site until Cove quits, so a site asks once per session.
@MainActor
final class SitePermissions {
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
    }

    private struct Key: Hashable {
        let site: String
        let device: Device
    }

    private var answers: [Key: Bool] = [:]

    /// Grants the devices if the site already has all of them, denies if it was
    /// refused any, and otherwise asks, remembering the answer for each device.
    func decide(
        _ devices: [Device],
        for origin: WKSecurityOrigin,
        ask: () async -> Bool
    ) async -> WKPermissionDecision {
        let site = "\(origin.protocol)://\(origin.host):\(origin.port)"
        let keys = devices.map { Key(site: site, device: $0) }
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
