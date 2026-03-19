import Cocoa
import SwiftUI

struct EmojiSuggestion: Identifiable {
    let id: String
    let emoji: String
    var shortcode: String { id }

    init(shortcode: String, emoji: String) {
        self.id = shortcode
        self.emoji = emoji
    }
}

class AutocompleteWindowController {
    static let shared = AutocompleteWindowController()

    private var window: NSWindow?
    private var suggestions: [EmojiSuggestion] = []
    private var selectedIndex: Int = 0
    private var hostingView: NSHostingView<AutocompleteView>?
    private var clickMonitor: Any?

    private static let maxSuggestions = 8
    private static let allSorted: [(key: String, value: String)] = {
        EmojiDatabase.all.sorted { $0.key < $1.key }
    }()

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    var selectedEmoji: EmojiSuggestion? {
        guard !suggestions.isEmpty, selectedIndex >= 0, selectedIndex < suggestions.count else {
            return nil
        }
        return suggestions[selectedIndex]
    }

    private init() {
        setupClickMonitor()
    }

    private func setupClickMonitor() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let window = self.window, window.isVisible else { return }
            // Hide the popup when clicking outside it, but don't cancel tracking
            // so the popup reappears when the user types the next letter
            let screenPoint = NSEvent.mouseLocation
            if !window.frame.contains(screenPoint) {
                self.hide()
            }
        }
    }

    deinit {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    func updateSuggestions(for query: String) {
        guard !query.isEmpty else {
            hide()
            return
        }

        let cleaned = query.lowercased()

        var exactMatches: [EmojiSuggestion] = []
        var prefixMatches: [EmojiSuggestion] = []
        var containsMatches: [EmojiSuggestion] = []

        for entry in Self.allSorted {
            if entry.key == cleaned {
                exactMatches.append(EmojiSuggestion(shortcode: entry.key, emoji: entry.value))
            } else if entry.key.hasPrefix(cleaned) {
                prefixMatches.append(EmojiSuggestion(shortcode: entry.key, emoji: entry.value))
            } else if entry.key.contains(cleaned) {
                containsMatches.append(EmojiSuggestion(shortcode: entry.key, emoji: entry.value))
            }
        }

        var results = exactMatches
        results.append(contentsOf: prefixMatches)
        results.append(contentsOf: containsMatches)
        suggestions = Array(results.prefix(Self.maxSuggestions))
        selectedIndex = 0

        if suggestions.isEmpty {
            hide()
            return
        }

        show()
    }

    func moveSelectionUp() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = max(0, selectedIndex - 1)
        updateView()
    }

    func moveSelectionDown() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = min(suggestions.count - 1, selectedIndex + 1)
        updateView()
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func show() {
        if window == nil {
            createWindow()
        }
        updateView()
        positionWindow()
        window?.orderFrontRegardless()
    }

    private func createWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 300),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.styleMask.insert(.borderless)

        window = panel
    }

    private func updateView() {
        let view = AutocompleteView(
            suggestions: suggestions,
            selectedIndex: selectedIndex,
            onSelect: { [weak self] suggestion in
                KeyboardMonitor.shared.selectEmoji(suggestion.emoji, shortcode: suggestion.shortcode)
                self?.hide()
            }
        )

        if let hostingView = hostingView {
            hostingView.rootView = view
        } else {
            let hosting = NSHostingView(rootView: view)
            hostingView = hosting
            window?.contentView = hosting
        }

        // Resize window to fit content
        let itemHeight: CGFloat = 36
        let padding: CGFloat = 8
        let height = CGFloat(suggestions.count) * itemHeight + padding * 2
        let width: CGFloat = 280
        if let window = window {
            var frame = window.frame
            frame.size = NSSize(width: width, height: min(height, 320))
            window.setFrame(frame, display: true)
        }
    }

    private func positionWindow() {
        guard let window = window else { return }

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero
        var cursorPoint: NSPoint? = nil

        // Try to get the actual text cursor position using Accessibility API
        let systemElement = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        if focusResult == .success, let focused = focusedElement, let axElement = focused as? AXUIElement {
            // Get the selected text range
            var selectedRangeValue: AnyObject?
            let rangeResult = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue)

            if rangeResult == .success, let rangeValue = selectedRangeValue {
                // Get the bounds for the selected text range (this gives us the cursor position)
                var boundsValue: AnyObject?
                let boundsResult = AXUIElementCopyParameterizedAttributeValue(
                    axElement,
                    kAXBoundsForRangeParameterizedAttribute as CFString,
                    rangeValue,
                    &boundsValue
                )

                if boundsResult == .success, let bounds = boundsValue,
                   let axValue = bounds as? AXValue {
                    var rect = CGRect.zero
                    if AXValueGetValue(axValue, .cgRect, &rect) {
                        // Convert from screen coordinates (top-left origin) to Cocoa coordinates (bottom-left origin)
                        if let screen = NSScreen.main {
                            let screenHeight = screen.frame.height
                            cursorPoint = NSPoint(
                                x: rect.origin.x,
                                y: screenHeight - rect.origin.y - rect.size.height
                            )
                        }
                    }
                }
            }
        }

        // Fall back to mouse location if we couldn't get the cursor position
        let referencePoint = cursorPoint ?? NSEvent.mouseLocation

        var x = referencePoint.x
        var y = referencePoint.y - window.frame.height - 4

        // Keep on screen
        if x + window.frame.width > screenFrame.maxX {
            x = screenFrame.maxX - window.frame.width
        }
        if y < screenFrame.minY {
            y = referencePoint.y + 20
        }
        if x < screenFrame.minX {
            x = screenFrame.minX
        }

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

struct AutocompleteView: View {
    let suggestions: [EmojiSuggestion]
    let selectedIndex: Int
    let onSelect: (EmojiSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                Button(action: { onSelect(suggestion) }) {
                    HStack(spacing: 10) {
                        Text(suggestion.emoji)
                            .font(.system(size: 22))
                            .frame(width: 30)
                        Text(":\(suggestion.shortcode):")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(index == selectedIndex ? .white : .primary)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(index == selectedIndex ? Color.accentColor : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }
}
