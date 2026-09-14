import Foundation
import IOKit.hid
import ApplicationServices
import AppKit

/// Les deux autorisations qui peuvent rendre PadKey muet, et qui echouent
/// toutes les deux en silence quand elles manquent.
enum Permissions {

    /// Necessaire pour envoyer des evenements clavier / souris.
    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    /// Necessaire sur certaines configurations pour lire un peripherique HID
    /// pendant qu'une autre application est au premier plan.
    static var inputMonitoring: IOHIDAccessType {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
    }

    static var hasInputMonitoring: Bool {
        inputMonitoring == kIOHIDAccessTypeGranted
    }

    static var inputMonitoringLabel: String {
        switch inputMonitoring {
        case kIOHIDAccessTypeGranted: return "accordee"
        case kIOHIDAccessTypeDenied: return "refusee"
        default: return "non demandee"
        }
    }

    @discardableResult
    static func requestInputMonitoring() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    static func openAccessibilitySettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    static func openInputMonitoringSettings() {
        requestInputMonitoring()
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    private static func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}
