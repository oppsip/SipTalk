import Foundation

final class PushKitManager {
    func configure() {
        // TODO: Register for VoIP pushes and send the token to the device
        // registry backend.
    }

    func handleIncomingPush(payload: [AnyHashable: Any]) {
        // TODO: Validate callId, report to CallKit, and wake SipCore.
    }
}
