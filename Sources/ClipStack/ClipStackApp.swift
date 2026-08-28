import AppKit
import ServiceManagement
import SwiftUI

@main
enum ClipStackApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Menu bar only: no Dock tile, no main window.
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

/// Launch-at-login, backed by the system login item registry so the switch always
/// agrees with System Settings > General > Login Items.
final class LoginItem: ObservableObject {
    @Published private(set) var isEnabled = false

    init() { refresh() }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Fails when running the bare binary rather than the .app bundle.
            let alert = NSAlert(error: error)
            alert.messageText = "Couldn't \(enabled ? "enable" : "disable") launch at login"
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
        refresh()

        if enabled, SMAppService.mainApp.status == .requiresApproval {
            let alert = NSAlert()
            alert.messageText = "Approve ClipStack in Login Items"
            alert.informativeText = "macOS needs you to switch ClipStack on under "
                + "System Settings > General > Login Items."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let monitor = ClipboardMonitor()
    private let loginItem = LoginItem()
    private let hotKeys = HotKeyManager()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var hostingController: NSHostingController<PopoverView>!
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clipboard",
                                   accessibilityDescription: "ClipStack")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        hostingController = NSHostingController(
            rootView: PopoverView(monitor: monitor,
                                  loginItem: loginItem,
                                  dismiss: { [weak self] in self?.popover.performClose(nil) }))
        // Without this the controller reports a zero preferredContentSize, so the
        // popover sizes itself from a default and leaves dead space below.
        hostingController.sizingOptions = [.preferredContentSize]

        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        popover.contentViewController = hostingController

        monitor.start()

        hotKeys.start()
        hotKeys.register(.pasteAsPlainText) { [weak self] in
            self?.monitor.pasteAsPlainText()
        }
        hotKeys.register(.showHistory) { [weak self] in
            self?.showPopoverFromHotKey()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeys.stop()
        monitor.stop()
    }

    @objc private func togglePopover() {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showContextMenu()
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    /// Installed only while the popover is up, so ordinary typing elsewhere is
    /// never intercepted. Returning nil swallows the key; returning the event
    /// lets it through to the app.
    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.popover.isShown else { return event }
            guard let key = PopoverKey.interpret(event, itemCount: self.monitor.clippings.count)
            else { return event }

            switch key {
            case .dismiss:
                self.popover.performClose(nil)
            case .move(let delta):
                let count = self.monitor.clippings.count
                guard count > 0 else { break }
                self.monitor.highlighted = (self.monitor.highlighted + delta + count) % count
            case .confirm:
                self.pick(self.monitor.highlighted)
            case .pick(let index):
                self.pick(index)
            }
            return nil
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private func pick(_ index: Int) {
        guard monitor.clippings.indices.contains(index) else { return }
        monitor.copy(monitor.clippings[index])
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        removeKeyMonitor()
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        // It may have been toggled in System Settings since we last looked.
        loginItem.refresh()
        // Resolve the SwiftUI content size before the popover reads it.
        hostingController.view.layoutSubtreeIfNeeded()
        popover.contentSize = hostingController.view.fittingSize
        monitor.highlighted = 0
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        installKeyMonitor()
    }

    /// Opened by hotkey rather than a click, so nothing has focused us yet.
    private func showPopoverFromHotKey() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        showPopover()
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit ClipStack", action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
}
