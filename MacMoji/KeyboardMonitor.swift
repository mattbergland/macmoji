import Cocoa
import Carbon.HIToolbox

class KeyboardMonitor {
    static let shared = KeyboardMonitor()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var buffer: String = ""
    private var isTracking: Bool = false
    private var savedClipboard: String?
    private var previousChar: String = ""  // Track last character to check if `:` is at word boundary
    // Marker value to tag our simulated events so the event tap can skip them
    // while still processing real user keystrokes during replacement
    private static let simulatedEventMarker: Int64 = 0x4D4D4A49  // "MMJI"
    private var clickMonitor: Any?  // Global click monitor to reset state on any click
    private var tapCheckTimer: Timer?  // Periodic timer to re-enable event tap if macOS disabled it
    private var appActivationObserver: NSObjectProtocol?  // Observe app switches (Cmd+Tab, etc.)
    private var syncWorkItem: DispatchWorkItem?  // Debounced accessibility sync to verify buffer

    var onBufferUpdate: ((String) -> Void)?
    var onEmojiInserted: (() -> Void)?
    var onTrackingCancelled: (() -> Void)?

    private init() {}

    func start() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: refcon
        ) else {
            print("MacMoji: Failed to create event tap. Check Accessibility permissions.")
            return
        }

        self.eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("MacMoji: Keyboard monitor started")

        // Monitor all clicks to reset previousChar (handles app switching, clicking into new fields)
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.previousChar = ""  // Any click = new typing context, treat next `:` as word boundary
            self?.cancelTracking()
        }

        // Periodically check if the event tap is still enabled (macOS can disable it silently)
        tapCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, let tap = self.eventTap else { return }
            if !CGEvent.tapIsEnabled(tap: tap) {
                CGEvent.tapEnable(tap: tap, enable: true)
                print("MacMoji: Re-enabled event tap (was disabled by macOS)")
            }
        }

        // Reset state when switching apps via Cmd+Tab or other non-click methods
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.previousChar = ""  // New app = new typing context
            self?.cancelTracking()
        }
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
        }
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        tapCheckTimer?.invalidate()
        tapCheckTimer = nil
        if let observer = appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            appActivationObserver = nil
        }
        cancelTracking()
    }

    func cancelTracking() {
        isTracking = false
        buffer = ""
        syncWorkItem?.cancel()
        DispatchQueue.main.async {
            self.onTrackingCancelled?()
        }
    }

    func selectEmoji(_ emoji: String, shortcode: String) {
        let deleteCount: Int
        if isTracking {
            // Delete the `:` + current buffer content
            deleteCount = buffer.count + 1
        } else {
            deleteCount = 0
        }

        isTracking = false
        buffer = ""

        DispatchQueue.main.async {
            self.onTrackingCancelled?()
        }

        // Perform the replacement on a background thread to avoid blocking the main thread
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.05) {
            self.replaceText(deleteCount: deleteCount, replacement: emoji)
        }
    }

    /// Returns true if the colon is at a word boundary (start of input, after space/newline/tab)
    private func isAtWordBoundary() -> Bool {
        if previousChar.isEmpty { return true }  // Start of input
        let boundary = CharacterSet.whitespacesAndNewlines
        return previousChar.unicodeScalars.allSatisfy { boundary.contains($0) }
    }

    /// Check if the currently focused text field has selected text
    /// (e.g., browser inline autocomplete selects the suggested completion).
    /// When selected text exists, a backspace clears the selection instead of deleting a character.
    private func hasSelectedText() -> Bool {
        let systemElement = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemElement, kAXFocusedUIElementAttribute as CFString, &focusedElement
        )
        guard result == .success, let focused = focusedElement else { return false }
        let axElement = unsafeBitCast(focused, to: AXUIElement.self)
        var selectedTextObj: AnyObject?
        let stResult = AXUIElementCopyAttributeValue(
            axElement, kAXSelectedTextAttribute as CFString, &selectedTextObj
        )
        if stResult == .success, let selectedText = selectedTextObj as? String, !selectedText.isEmpty {
            return true
        }
        return false
    }

    /// Schedule a debounced async verification of the buffer against the actual text field content.
    /// This catches any desync between our keystroke-tracked buffer and reality (e.g., browser
    /// autocomplete absorbing keystrokes, apps handling backspace differently, etc.).
    private func scheduleSyncFromAccessibility() {
        syncWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.syncBufferFromAccessibility()
        }
        syncWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }

    /// Read the actual text field content via the Accessibility API and correct the buffer if needed.
    private func syncBufferFromAccessibility() {
        guard isTracking else { return }

        let systemElement = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(
            systemElement, kAXFocusedUIElementAttribute as CFString, &focusedElement
        )
        guard focusResult == .success, let focused = focusedElement else { return }
        let axElement = unsafeBitCast(focused, to: AXUIElement.self)

        // Get the text value of the focused element
        var valueObj: AnyObject?
        let valueResult = AXUIElementCopyAttributeValue(
            axElement, kAXValueAttribute as CFString, &valueObj
        )
        guard valueResult == .success, let value = valueObj as? String, !value.isEmpty else { return }

        // Get the cursor position (start of selected text range)
        var rangeObj: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(
            axElement, kAXSelectedTextRangeAttribute as CFString, &rangeObj
        )
        guard rangeResult == .success, let range = rangeObj else { return }
        let axRange = unsafeBitCast(range, to: AXValue.self)
        var cfRange = CFRange(location: 0, length: 0)
        guard AXValueGetValue(axRange, .cfRange, &cfRange) else { return }

        let cursorPos = cfRange.location
        // Convert CFRange location (UTF-16 offset) to String index
        let utf16View = value.utf16
        guard cursorPos > 0, cursorPos <= utf16View.count else { return }
        let utf16Index = utf16View.index(utf16View.startIndex, offsetBy: cursorPos)
        guard let stringIndex = String.Index(utf16Index, within: value) else { return }

        // Extract text before cursor
        let textBeforeCursor = String(value[..<stringIndex])

        // Find the last `:` that could be our trigger colon
        guard let colonIndex = textBeforeCursor.lastIndex(of: ":") else {
            cancelTracking()
            return
        }

        let colonPosition = textBeforeCursor.distance(from: textBeforeCursor.startIndex, to: colonIndex)

        // Verify the colon is at a word boundary
        if colonPosition > 0 {
            let charBefore = textBeforeCursor[textBeforeCursor.index(before: colonIndex)]
            let boundary = CharacterSet.whitespacesAndNewlines
            if !String(charBefore).unicodeScalars.allSatisfy({ boundary.contains($0) }) {
                cancelTracking()
                return
            }
        }

        // Extract the actual buffer (text between `:` and cursor)
        let afterColon = String(textBeforeCursor[textBeforeCursor.index(after: colonIndex)...])
        let actualBuffer = afterColon.lowercased()

        // Validate that it only contains valid shortcode characters
        let validChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        if !actualBuffer.isEmpty && !actualBuffer.unicodeScalars.allSatisfy({ validChars.contains($0) }) {
            cancelTracking()
            return
        }

        // If the actual buffer differs from our tracked buffer, correct it
        if actualBuffer != buffer {
            buffer = actualBuffer
            onBufferUpdate?(buffer)
        }
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable tap if it gets disabled (macOS can disable taps that take too long)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        // Skip our own simulated events (tagged with our marker) but process real user keystrokes
        if event.getIntegerValueField(.eventSourceUserData) == KeyboardMonitor.simulatedEventMarker {
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // For Command modifier shortcuts: pass through but reset previousChar
        // because Cmd+A (select all), Cmd+Left/Right (jump to start/end), Cmd+Z (undo)
        // all change cursor position, making previousChar unreliable
        if flags.contains(.maskCommand) {
            previousChar = ""
            if isTracking {
                cancelTracking()
            }
            return Unmanaged.passRetained(event)
        }

        // Handle cursor movement keys — after any cursor move, we can't know
        // what character is before the cursor, so reset previousChar.
        // Note: Up/Down arrows during tracking are handled below for popup navigation.
        let cursorMovementKeys = [kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown, kVK_ForwardDelete]
        let arrowKeys = [kVK_LeftArrow, kVK_RightArrow]
        if cursorMovementKeys.contains(Int(keyCode)) || (!isTracking && arrowKeys.contains(Int(keyCode))) {
            previousChar = ""
            if isTracking {
                cancelTracking()
            }
            return Unmanaged.passRetained(event)
        }

        // Handle backspace globally (both tracking and non-tracking)
        // Backspace means the character before the cursor is gone, so we can't know
        // what's actually there now. Reset previousChar so `:` can trigger.
        if Int(keyCode) == kVK_Delete {
            if isTracking {
                // Check if the text field has selected text (e.g., browser inline autocomplete).
                // If so, this backspace will clear the selection rather than deleting a
                // character from our buffer, so we should NOT remove from the buffer.
                let selectionActive = hasSelectedText()

                if !selectionActive && !buffer.isEmpty {
                    buffer.removeLast()
                    if buffer.isEmpty {
                        cancelTracking()
                    } else {
                        DispatchQueue.main.async {
                            self.onBufferUpdate?(self.buffer)
                        }
                    }
                } else if !selectionActive {
                    // No selection and buffer is empty — user is deleting the `:` itself
                    cancelTracking()
                }
                // When selectionActive is true, keep buffer as-is (backspace only clears selection)

                // Always schedule an async sync to verify the buffer matches reality
                if isTracking {
                    scheduleSyncFromAccessibility()
                }
            }
            previousChar = ""  // After backspace, treat next `:` as word boundary
            return Unmanaged.passRetained(event)
        }

        // Handle other special keys when tracking is active
        if isTracking {
            let popup = AutocompleteWindowController.shared

            switch Int(keyCode) {
            case kVK_Escape:
                cancelTracking()
                return nil // Consume the event

            case kVK_Return, kVK_Tab:
                if popup.isVisible, let selected = popup.selectedEmoji {
                    selectEmoji(selected.emoji, shortcode: selected.shortcode)
                    previousChar = ""  // Reset after emoji insertion
                    return nil // Consume the event
                }
                cancelTracking()
                previousChar = " "  // Treat return/tab as whitespace for boundary detection
                return Unmanaged.passRetained(event)

            case kVK_UpArrow:
                if popup.isVisible {
                    DispatchQueue.main.async { popup.moveSelectionUp() }
                    return nil
                }
                return Unmanaged.passRetained(event)

            case kVK_DownArrow:
                if popup.isVisible {
                    DispatchQueue.main.async { popup.moveSelectionDown() }
                    return nil
                }
                return Unmanaged.passRetained(event)

            case kVK_Space:
                cancelTracking()
                previousChar = " "  // Space is a word boundary
                return Unmanaged.passRetained(event)

            default:
                break
            }
        }

        // Get the character typed
        if let characters = event.keyboardString(), !characters.isEmpty {
            let char = characters

            if char == ":" {
                if isTracking && !buffer.isEmpty {
                    // Closing colon - check if we have a valid shortcode
                    let shortcode = buffer.lowercased()
                    if let emoji = EmojiDatabase.all[shortcode] {
                        // Valid shortcode! Replace :shortcode: with emoji
                        // Consume the closing `:` (don't let it type into the field)
                        // Only need to delete the opening `:` + buffer content
                        let deleteCount = buffer.count + 1 // +1 for opening `:`
                        isTracking = false
                        buffer = ""
                        DispatchQueue.main.async {
                            self.onTrackingCancelled?()
                        }
                        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.05) {
                            self.replaceText(deleteCount: deleteCount, replacement: emoji)
                        }
                        previousChar = ""  // Reset so next `:` triggers properly
                        return nil // Consume the closing colon — prevents leftover `:` in apps like Chrome
                    } else {
                        // Not a valid shortcode — only re-start tracking if at word boundary
                        if isAtWordBoundary() {
                            buffer = ""
                            isTracking = true
                            DispatchQueue.main.async {
                                self.onBufferUpdate?(self.buffer)
                            }
                        } else {
                            cancelTracking()
                        }
                        previousChar = char
                        return Unmanaged.passRetained(event)
                    }
                } else {
                    // Only start tracking if `:` is at a word boundary
                    // (after space, newline, tab, or at the very start of input)
                    if isAtWordBoundary() {
                        isTracking = true
                        buffer = ""
                        DispatchQueue.main.async {
                            self.onBufferUpdate?(self.buffer)
                        }
                    }
                    previousChar = char
                    return Unmanaged.passRetained(event)
                }
            } else if isTracking {
                // Only allow alphanumeric and underscore in shortcodes
                let validChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
                if char.unicodeScalars.allSatisfy({ validChars.contains($0) }) {
                    buffer += char.lowercased()
                    DispatchQueue.main.async {
                        self.onBufferUpdate?(self.buffer)
                    }
                } else {
                    // Invalid character for shortcode, cancel tracking
                    cancelTracking()
                }
                previousChar = char
            } else {
                // Not tracking, just update previousChar
                previousChar = char
            }
        }

        return Unmanaged.passRetained(event)
    }

    private func replaceText(deleteCount: Int, replacement: String) {
        let pasteboard = NSPasteboard.general

        // Save current clipboard content
        let savedString = pasteboard.string(forType: .string)

        // Use backspace keys to delete the shortcode text, then paste the emoji.
        // Backspaces work reliably across all apps including web browser text fields.
        // (Shift+Left selection was tried but doesn't work in web contentEditable/textarea.)
        let src = CGEventSource(stateID: .hidSystemState)
        for _ in 0..<deleteCount {
            let backDown = CGEvent(keyboardEventSource: src, virtualKey: UInt16(kVK_Delete), keyDown: true)
            backDown?.setIntegerValueField(.eventSourceUserData, value: KeyboardMonitor.simulatedEventMarker)
            backDown?.post(tap: .cghidEventTap)
            let backUp = CGEvent(keyboardEventSource: src, virtualKey: UInt16(kVK_Delete), keyDown: false)
            backUp?.setIntegerValueField(.eventSourceUserData, value: KeyboardMonitor.simulatedEventMarker)
            backUp?.post(tap: .cghidEventTap)
            usleep(5000) // 5ms between keystrokes
        }

        // Small delay to let backspaces process
        usleep(30000) // 30ms

        // Put emoji on clipboard
        pasteboard.clearContents()
        pasteboard.setString(replacement, forType: .string)

        // Simulate Cmd+V to paste the emoji
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: UInt16(kVK_ANSI_V), keyDown: true)
        vDown?.flags = .maskCommand
        vDown?.setIntegerValueField(.eventSourceUserData, value: KeyboardMonitor.simulatedEventMarker)
        vDown?.post(tap: .cghidEventTap)
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: UInt16(kVK_ANSI_V), keyDown: false)
        vUp?.flags = .maskCommand
        vUp?.setIntegerValueField(.eventSourceUserData, value: KeyboardMonitor.simulatedEventMarker)
        vUp?.post(tap: .cghidEventTap)

        // Wait for paste to complete
        usleep(50000) // 50ms

        // Restore clipboard after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let savedString = savedString {
                pasteboard.clearContents()
                pasteboard.setString(savedString, forType: .string)
            }
            self.onEmojiInserted?()
        }
    }
}

// Extension to get string from CGEvent
extension CGEvent {
    func keyboardString() -> String? {
        let maxLength = 4
        var length = 0
        var chars = [UniChar](repeating: 0, count: maxLength)
        self.keyboardGetUnicodeString(maxStringLength: maxLength, actualStringLength: &length, unicodeString: &chars)
        guard length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}
