import Foundation
import SwiftUI
import ApplicationServices
import IOKit.hid

/// Etat partage entre la barre de menus, la fenetre de reglages et le moteur.
@MainActor
final class AppState: ObservableObject {

    @Published var profiles: [Profile] = []
    @Published var selectedProfileName: String = ""
    @Published var isEnabled: Bool = false
    @Published var controllerName: String? = nil
    @Published var hasAccessibility: Bool = false
    @Published var hasInputMonitoring: Bool = true
    @Published var lastError: String? = nil
    /// Etat brut de la manette, alimente seulement quand la fenetre de test est ouverte.
    @Published var liveSnapshot: PadSnapshot? = nil
    /// Steam Input capture la manette et la remplace par un peripherique virtuel :
    /// PadKey ne recoit alors plus rien d'utilisable.
    @Published var steamRunning: Bool = false
    /// Vrai quand la barre de menus est trop chargee pour afficher notre icone.
    @Published var statusItemHidden: Bool = false
    /// Presence dans le Dock, avec Commande+Tab, plutot qu'en arriere-plan seul.
    @Published var showInDock: Bool = true {
        didSet {
            guard showInDock != oldValue else { return }
            UserDefaults.standard.set(showInDock, forKey: "showInDock")
            onDockPreferenceChange?()
        }
    }
    /// Appele quand la presence dans le Dock change, pour appliquer la bascule.
    var onDockPreferenceChange: (() -> Void)?
    /// Manettes visibles par macOS, pour laisser choisir quand il y en a plusieurs.
    @Published var availableControllers: [ControllerInfo] = []
    @Published var preferredController: String? = nil

    private let engine: MappingEngine
    private var accessibilityTimer: Timer? = nil
    /// Le mapping est mis en sommeil tant que la fenetre de reglages a le focus.
    private var suspended = false

    static let profilesDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PadKey", isDirectory: true)
            .appendingPathComponent("Profiles", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    init() {
        let loaded = AppState.loadProfiles()
        let remembered = UserDefaults.standard.string(forKey: "selectedProfile") ?? ""
        let chosen = loaded.contains(where: { $0.name == remembered })
            ? remembered
            : (loaded.first?.name ?? "")
        let startProfile = loaded.first(where: { $0.name == chosen }) ?? loaded.first ?? DefaultProfiles.outlast

        profiles = loaded
        selectedProfileName = chosen
        engine = MappingEngine(profile: startProfile)

        engine.onControllerChange = { [weak self] name in self?.controllerName = name }
        engine.onEnabledChange = { [weak self] value in self?.isEnabled = value }
        engine.start()

        // Presente dans le Dock par defaut : c'est la seule porte d'entree fiable
        // quand la barre de menus deborde.
        showInDock = UserDefaults.standard.object(forKey: "showInDock") as? Bool ?? true
        hasAccessibility = Permissions.hasAccessibility
        hasInputMonitoring = Permissions.inputMonitoring != kIOHIDAccessTypeDenied
        controllerName = engine.connectedControllerName
        availableControllers = engine.detectedControllers
        steamRunning = SteamWatch.isRunning()
        if let saved = UserDefaults.standard.string(forKey: "preferredController") {
            preferredController = saved
            engine.setPreferredController(saved)
        }

        // L'autorisation est accordee dans les Reglages Systeme, hors de l'app :
        // on la reverifie regulierement pour mettre l'interface a jour toute seule.
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let trusted = Permissions.hasAccessibility
                if trusted != self.hasAccessibility { self.hasAccessibility = trusted }
                let hid = Permissions.inputMonitoring != kIOHIDAccessTypeDenied
                if hid != self.hasInputMonitoring { self.hasInputMonitoring = hid }
                self.controllerName = self.engine.connectedControllerName
                let controllers = self.engine.detectedControllers
                if controllers != self.availableControllers { self.availableControllers = controllers }
                let steam = SteamWatch.isRunning()
                if steam != self.steamRunning { self.steamRunning = steam }
            }
        }

        if UserDefaults.standard.bool(forKey: "enabledAtLaunch") && hasAccessibility {
            setEnabled(true)
        }
    }

    // MARK: - Activation

    var selectedProfile: Profile {
        profiles.first(where: { $0.name == selectedProfileName }) ?? DefaultProfiles.outlast
    }

    func setEnabled(_ value: Bool) {
        if value && !Permissions.hasAccessibility {
            hasAccessibility = false
            requestAccessibility()
            return
        }
        isEnabled = value
        engine.setEnabled(value && !suspended)
        UserDefaults.standard.set(value, forKey: "enabledAtLaunch")
    }

    func toggleEnabled() { setEnabled(!isEnabled) }

    func suspendForSettings(_ value: Bool) {
        guard suspended != value else { return }
        suspended = value
        engine.setEnabled(isEnabled && !suspended)
    }

    func reloadDisplays() { engine.refreshDisplays() }

    /// Le flux d'etat coute quelques cycles : on ne l'alimente que quand on l'affiche.
    func setLiveMonitoring(_ on: Bool) {
        if on {
            engine.onSnapshot = { [weak self] snapshot in self?.liveSnapshot = snapshot }
        } else {
            engine.onSnapshot = nil
            liveSnapshot = nil
        }
    }

    func quitSteam() { SteamWatch.quit() }

    /// La barre de menus deborde : expliquer comment retrouver l'application.
    func showMenuBarHelp() {
        let alert = NSAlert()
        alert.messageText = "L'icone de PadKey ne tient pas dans la barre de menus"
        alert.informativeText = Self.menuBarHelpText
        alert.addButton(withTitle: "Compris")
        alert.runModal()
    }

    private static let menuBarHelpText = """
        Votre barre de menus est pleine, macOS a donc masque l'icone de PadKey. \
        L'application tourne quand meme et le mapping fonctionne.

        Pour retrouver cette fenetre a tout moment, double-cliquez PadKey dans le \
        dossier Applications : elle se rouvre meme si l'application tourne deja.

        Pour faire de la place, maintenez la touche Commande et faites glisser les \
        icones de la barre pour les reordonner ou les sortir, ou masquez-en depuis \
        Reglages Systeme, Barre des menus.
        """

    func choose(controller id: String?) {
        preferredController = id
        if let id {
            UserDefaults.standard.set(id, forKey: "preferredController")
        } else {
            UserDefaults.standard.removeObject(forKey: "preferredController")
        }
        engine.setPreferredController(id)
        availableControllers = engine.detectedControllers
        controllerName = engine.connectedControllerName
    }

    func refreshControllers() {
        availableControllers = engine.detectedControllers
        controllerName = engine.connectedControllerName
    }

    func requestAccessibility() { Permissions.openAccessibilitySettings() }

    func requestInputMonitoring() { Permissions.openInputMonitoringSettings() }

    // MARK: - Profils

    func select(profileNamed name: String) {
        guard let profile = profiles.first(where: { $0.name == name }) else { return }
        selectedProfileName = name
        UserDefaults.standard.set(name, forKey: "selectedProfile")
        engine.update(profile: profile)
    }

    func update(_ profile: Profile) {
        guard let index = profiles.firstIndex(where: { $0.name == profile.name }) else { return }
        profiles[index] = profile
        save(profile)
        if profile.name == selectedProfileName { engine.update(profile: profile) }
    }

    func duplicateSelected() {
        var copy = selectedProfile
        var name = copy.name + " copie"
        var suffix = 2
        while profiles.contains(where: { $0.name == name }) {
            name = copy.name + " copie \(suffix)"
            suffix += 1
        }
        copy.name = name
        profiles.append(copy)
        save(copy)
        select(profileNamed: name)
    }

    func deleteSelected() {
        guard profiles.count > 1 else { return }
        let profile = selectedProfile
        profiles.removeAll { $0.name == profile.name }
        try? FileManager.default.removeItem(at: AppState.profilesDirectory.appendingPathComponent(profile.fileName))
        if let first = profiles.first { select(profileNamed: first.name) }
    }

    func renameSelected(to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !profiles.contains(where: { $0.name == trimmed }) else { return }
        var profile = selectedProfile
        let oldFile = AppState.profilesDirectory.appendingPathComponent(profile.fileName)
        guard let index = profiles.firstIndex(where: { $0.name == profile.name }) else { return }
        profile.name = trimmed
        profiles[index] = profile
        try? FileManager.default.removeItem(at: oldFile)
        save(profile)
        select(profileNamed: trimmed)
    }

    func reload() {
        let loaded = AppState.loadProfiles()
        profiles = loaded
        if !loaded.contains(where: { $0.name == selectedProfileName }), let first = loaded.first {
            select(profileNamed: first.name)
        } else {
            engine.update(profile: selectedProfile)
        }
    }

    func revealProfilesFolder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: AppState.profilesDirectory.path)
    }

    func restoreDefaults() {
        for profile in DefaultProfiles.all { save(profile) }
        reload()
    }

    // MARK: - Fichiers

    private func save(_ profile: Profile) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        do {
            let data = try encoder.encode(profile)
            try data.write(to: AppState.profilesDirectory.appendingPathComponent(profile.fileName), options: .atomic)
        } catch {
            lastError = "Enregistrement impossible : \(error.localizedDescription)"
        }
    }

    private static func loadProfiles() -> [Profile] {
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: profilesDirectory, includingPropertiesForKeys: nil)) ?? []
        let files = urls.filter { $0.pathExtension.lowercased() == "json" }

        if files.isEmpty {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            for profile in DefaultProfiles.all {
                if let data = try? encoder.encode(profile) {
                    try? data.write(to: profilesDirectory.appendingPathComponent(profile.fileName), options: .atomic)
                }
            }
            return DefaultProfiles.all
        }

        let decoder = JSONDecoder()
        var result: [Profile] = []
        for url in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let data = try? Data(contentsOf: url),
                  let profile = try? decoder.decode(Profile.self, from: data) else { continue }
            result.append(profile)
        }
        return result.isEmpty ? DefaultProfiles.all : result
    }
}
