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

        // Retry starting the monitor periodically until accessibility is granted
        startMonitorWithRetry(monitor: monitor, attempt: 0)
    }

    private func startMonitorWithRetry(monitor: KeyboardMonitor, attempt: Int) {
        let maxAttempts = 60 // Try for up to 60 seconds
        let delay: TimeInterval = attempt == 0 ? 0.1 : 1.0

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let trusted = AXIsProcessTrusted()
            if trusted {
                monitor.start()
                print("MacMoji: Monitor started successfully on attempt \(attempt + 1)")
            } else if attempt < maxAttempts {
                print("MacMoji: Waiting for Accessibility permission... (attempt \(attempt + 1))")
                self.startMonitorWithRetry(monitor: monitor, attempt: attempt + 1)
            } else {
                print("MacMoji: Timed out waiting for Accessibility permission.")
            }
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
