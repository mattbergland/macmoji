import SwiftUI
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityPermissions()
        setupKeyboardMonitor()
    }

    private func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            print("MacMoji: Accessibility permissions needed. A system prompt should appear.")
        } else {
            print("MacMoji: Accessibility permissions granted.")
        }
    }

    private func setupKeyboardMonitor() {
        let monitor = KeyboardMonitor.shared
        let popup = AutocompleteWindowController.shared

        monitor.onBufferUpdate = { buffer in
            popup.updateSuggestions(for: buffer)
        }

        monitor.onTrackingCancelled = {
            popup.hide()
        }

        monitor.onEmojiInserted = {
            // Could show a brief notification here if desired
        }

        // Delay start slightly to ensure accessibility permissions are processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            monitor.start()
        }
    }
}

@main
struct MacMojiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("MacMoji", systemImage: "face.smiling") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
