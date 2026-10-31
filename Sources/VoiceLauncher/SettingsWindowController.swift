import AppKit
import SwiftUI

/// Hosts the settings view in a plain titled NSWindow, as AllyClicker does.
/// A SwiftUI `Window` scene on macOS 26 folds the tabs into the title bar; in
/// an ordinary window the same `TabView` gets classic tabs under a visible title.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let frameKey = "SettingsWindowFrame"

    func show(state: AppState) {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let view = SettingsView(state: state, onDone: { [weak self] in self?.window?.close() })
        let win = NSWindow(contentViewController: NSHostingController(rootView: view))
        win.title = "Voice Launcher Settings"
        win.styleMask = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.delegate = self
        if let saved = UserDefaults.standard.string(forKey: frameKey) {
            win.setFrameOrigin(NSRectFromString(saved).origin)
        } else {
            win.center()
        }
        window = win
        // A menu-bar app is never frontmost by itself.
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        if let win = notification.object as? NSWindow {
            UserDefaults.standard.set(NSStringFromRect(win.frame), forKey: frameKey)
        }
        window = nil
    }
}
