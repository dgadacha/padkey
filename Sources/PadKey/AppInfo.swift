import Foundation

/// Identite de la version en cours, lue dans le bundle assemble par build.sh.
enum AppInfo {
    /// Version publique, du genre 1.1.0.
    static let version: String =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"

    /// Numero de build : horodatage de la compilation.
    static let build: String =
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "local"

    /// "1.1.0 (20260914.1145)"
    static var full: String { "\(version) (\(build))" }
}
