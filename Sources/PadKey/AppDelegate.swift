import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private var state: AppState!
    private var settingsWindow: NSWindow?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        state = AppState()
        buildMainMenu()
        state.onDockPreferenceChange = { [weak self] in self?.applyActivationPolicy() }
        applyActivationPolicy()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = buildMenu()
        statusItem.menu?.delegate = self
        refreshStatusIcon()

        state.$isEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshStatusIcon() }
            .store(in: &cancellables)
        state.$controllerName
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshStatusIcon() }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            self, selector: #selector(displaysChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        // Une application sans icone dans le Dock n'a que son icone de barre de
        // menus pour se manifester, et macOS la masque quand la barre est pleine.
        // On ouvre donc la fenetre a chaque lancement : sinon, double-cliquer
        // l'application ne produit rien de visible et elle parait cassee.
        showSettings(nil)
        if !state.hasAccessibility {
            promptForAccessibility()
        }
        warnIfStatusItemHidden()
    }

    /// Relancer une application deja ouverte passe par ici : c'est ce qui arrive
    /// quand on double-clique son icone dans le Finder.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings(nil)
        return true
    }

    /// Quand la barre de menus deborde, l'element existe mais n'est jamais dessine.
    /// Le dire vaut mieux que laisser chercher.
    private func warnIfStatusItemHidden() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, let button = self.statusItem.button else { return }
            let frame = button.window?.frame ?? .zero
            let visible = frame.width > 0 && NSScreen.screens.contains { $0.frame.intersects(frame) }
            guard !visible else { return }
            self.state.statusItemHidden = true
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        state.setEnabled(false)
    }

    /// Presente dans le Dock, ou discrete en barre de menus seulement.
    /// Une application d'arriere-plan sans icone de Dock devient introuvable quand
    /// la barre de menus est pleine : le Dock sert alors de porte d'entree.
    func applyActivationPolicy() {
        NSApp.setActivationPolicy(state.showInDock ? .regular : .accessory)
        if state.showInDock {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// En mode Dock, l'application a une barre de menus applicative : sans ce menu
    /// elle serait vide et Commande+Q ne repondrait pas.
    private func buildMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "A propos de PadKey", action: #selector(showAbout), keyEquivalent: "")
            .target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Reglages", action: #selector(showSettings(_:)), keyEquivalent: ",")
            .target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Masquer PadKey", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Masquer les autres",
                                         action: #selector(NSApplication.hideOtherApplications(_:)),
                                         keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quitter PadKey", action: #selector(quit), keyEquivalent: "q")
            .target = self
        appItem.submenu = appMenu
        main.addItem(appItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Fenetre")
        windowMenu.addItem(withTitle: "Reduire", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Fermer", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)

        NSApp.mainMenu = main
        NSApp.windowsMenu = windowMenu
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationVersion: AppInfo.version,
            .version: AppInfo.build,
        ])
    }

    @objc private func displaysChanged() {
        // Le curseur doit rester dans les bornes du nouvel agencement d'ecrans.
        state.reloadDisplays()
    }

    // MARK: - Barre de menus

    private func refreshStatusIcon() {
        guard let button = statusItem.button else { return }
        let symbol = state.isEnabled ? "gamecontroller.fill" : "gamecontroller"
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "PadKey")
        button.image?.isTemplate = true
        button.appearsDisabled = !state.isEnabled
        button.toolTip = state.controllerName.map { "PadKey - \($0)" } ?? "PadKey - aucune manette"
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()

        state.refreshControllers()

        let header = NSMenuItem(title: "Manettes detectees", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        if state.availableControllers.isEmpty {
            let none = NSMenuItem(title: "  Aucune manette", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
        } else {
            for controller in state.availableControllers {
                let item = NSMenuItem(title: "\(controller.name)  -  \(controller.kind)",
                                      action: #selector(selectController(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = controller.id
                item.state = controller.isActive ? .on : .off
                item.isEnabled = controller.isUsable
                menu.addItem(item)
            }
        }

        if state.steamRunning {
            let steam = NSMenuItem(title: "Steam Input peut capter la manette",
                                   action: #selector(showSettings(_:)), keyEquivalent: "")
            steam.target = self
            menu.addItem(steam)
        }

        if !state.hasAccessibility {
            let warning = NSMenuItem(title: "Autoriser PadKey dans Accessibilite",
                                     action: #selector(promptForAccessibility), keyEquivalent: "")
            warning.target = self
            menu.addItem(warning)
        }

        menu.addItem(.separator())

        let toggle = NSMenuItem(title: state.isEnabled ? "Desactiver le mapping" : "Activer le mapping",
                                action: #selector(toggleEnabled), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        let hint = NSMenuItem(title: "Astuce : bouton PS maintenu 1 s fait la meme chose",
                              action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)

        menu.addItem(.separator())
        let profilesHeader = NSMenuItem(title: "Profil", action: nil, keyEquivalent: "")
        profilesHeader.isEnabled = false
        menu.addItem(profilesHeader)

        for profile in state.profiles {
            let item = NSMenuItem(title: profile.name, action: #selector(selectProfile(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = profile.name
            item.state = profile.name == state.selectedProfileName ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Reglages...", action: #selector(showSettings(_:)), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let dock = NSMenuItem(title: "Afficher dans le Dock", action: #selector(toggleDock), keyEquivalent: "")
        dock.target = self
        dock.state = state.showInDock ? .on : .off
        menu.addItem(dock)

        let folder = NSMenuItem(title: "Ouvrir le dossier des profils", action: #selector(openFolder), keyEquivalent: "")
        folder.target = self
        menu.addItem(folder)

        let reload = NSMenuItem(title: "Recharger les profils", action: #selector(reloadProfiles), keyEquivalent: "r")
        reload.target = self
        menu.addItem(reload)

        menu.addItem(.separator())
        let version = NSMenuItem(title: "PadKey \(AppInfo.full)", action: nil, keyEquivalent: "")
        version.isEnabled = false
        menu.addItem(version)

        let quit = NSMenuItem(title: "Quitter PadKey", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - Actions

    @objc private func toggleEnabled() { state.toggleEnabled() }

    @objc private func selectController(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        state.choose(controller: id)
    }

    @objc private func selectProfile(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        state.select(profileNamed: name)
    }

    @objc private func toggleDock() { state.showInDock.toggle() }

    @objc private func openFolder() { state.revealProfilesFolder() }

    @objc private func reloadProfiles() { state.reload() }

    @objc private func promptForAccessibility() { state.requestAccessibility() }

    @objc private func quit() {
        state.setEnabled(false)
        NSApp.terminate(nil)
    }

    @objc private func showSettings(_ sender: Any?) {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView(state: state))
            let window = NSWindow(contentViewController: hosting)
            window.title = "PadKey"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 1280, height: 820))
            // Avec plusieurs ecrans, center() choisit au hasard : on vise celui
            // ou se trouve le curseur.
            let pointer = NSEvent.mouseLocation
            let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
            if let visible = screen?.visibleFrame {
                let size = window.frame.size
                window.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2,
                                              y: visible.midY - size.height / 2))
            } else {
                window.center()
            }
            window.isReleasedWhenClosed = false
            settingsWindow = window

            NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
                    // Sinon le stick droit ferait bouger le curseur pendant qu'on regle les touches.
                    Task { @MainActor in self?.state.suspendForSettings(true) }
                }
            NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.state.suspendForSettings(false) }
                }
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.state.suspendForSettings(false) }
                }
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
