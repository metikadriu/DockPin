import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var pinner: DockPinner!

    func applicationDidFinishLaunching(_ notification: Notification) {
        promptAccessibilityIfNeeded()
        pinner = DockPinner()
        setupStatusItem()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.pinner.refresh()
            self?.rebuildMenu()
        }
    }

    private func promptAccessibilityIfNeeded() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    // MARK: - Status bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "pin.fill",
                                   accessibilityDescription: "DockPin")
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let active = NSMenuItem(title: "Active",
                                action: #selector(toggleActive),
                                keyEquivalent: "")
        active.state = DockPinner.isEnabled ? .on : .off
        active.target = self
        menu.addItem(active)

        menu.addItem(.separator())

        let lockHeader = NSMenuItem(title: "Lock Dock to", action: nil, keyEquivalent: "")
        let lockSubmenu = NSMenu()
        let currentUUID = DockPinner.lockedDisplayUUID
        for screen in NSScreen.screens {
            guard let uuid = DisplayUtils.uuid(for: screen) else { continue }
            let item = NSMenuItem(title: DisplayUtils.label(for: screen),
                                  action: #selector(selectDisplay(_:)),
                                  keyEquivalent: "")
            item.representedObject = uuid
            item.state = (uuid == currentUUID) ? .on : .off
            item.target = self
            lockSubmenu.addItem(item)
        }
        if NSScreen.screens.count < 2 {
            let warn = NSMenuItem(title: "Only one display detected", action: nil, keyEquivalent: "")
            warn.isEnabled = false
            lockSubmenu.addItem(warn)
        }
        menu.setSubmenu(lockSubmenu, for: lockHeader)
        menu.addItem(lockHeader)

        let bypass = NSMenuItem(title: "Hold ⌥ Option to bypass", action: nil, keyEquivalent: "")
        bypass.isEnabled = false
        menu.addItem(bypass)

        menu.addItem(.separator())

        let login = NSMenuItem(title: "Open at Login",
                               action: #selector(toggleLogin),
                               keyEquivalent: "")
        login.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        login.target = self
        menu.addItem(login)

        menu.addItem(.separator())

        let accessibility = NSMenuItem(title: "Open Accessibility Settings…",
                                       action: #selector(openAccessibility),
                                       keyEquivalent: "")
        accessibility.target = self
        menu.addItem(accessibility)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit DockPin",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func toggleActive() {
        DockPinner.isEnabled.toggle()
        pinner.refresh()
        rebuildMenu()
    }

    @objc private func selectDisplay(_ sender: NSMenuItem) {
        guard let uuid = sender.representedObject as? String else { return }
        DockPinner.lockedDisplayUUID = uuid
        pinner.refresh()
        rebuildMenu()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
        rebuildMenu()
    }

    @objc private func openAccessibility() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
