import AppKit

/// Steam Input s'intercale entre la manette et macOS : il masque la vraie DualSense
/// derriere un peripherique virtuel, ce qui rend le mapping muet.
enum SteamWatch {
    static func isRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.valvesoftware.steam"
                || $0.localizedName?.lowercased() == "steam"
        }
    }

    static func quit() {
        for app in NSWorkspace.shared.runningApplications
        where app.bundleIdentifier == "com.valvesoftware.steam" || app.localizedName?.lowercased() == "steam" {
            app.terminate()
        }
    }
}
