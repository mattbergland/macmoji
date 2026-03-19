import SwiftUI

struct ContentView: View {
    @State private var hasAccessibility = AXIsProcessTrusted()

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("MacMoji")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(hasAccessibility ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(hasAccessibility ? "Active" : "Needs Permission")
                    .font(.caption)
                    .foregroundColor(hasAccessibility ? .green : .red)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Divider()

            if hasAccessibility {
                activeView
            } else {
                permissionView
            }

            Divider()

            // Footer
            HStack {
                Text("\(EmojiDatabase.all.count) emojis")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .frame(width: 300, height: 280)
        .onAppear {
            hasAccessibility = AXIsProcessTrusted()
        }
    }

    private var activeView: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.green)

            Text("MacMoji is running!")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                instructionRow(icon: "keyboard", text: "Type :shortcode: anywhere to insert emoji")
                instructionRow(icon: "text.cursor", text: "Type : to see autocomplete suggestions")
                instructionRow(icon: "return", text: "Press Tab or Enter to select")
                instructionRow(icon: "escape", text: "Press Esc to dismiss")
            }
            .padding(.horizontal, 8)

            Spacer()
        }
        .padding(.top, 8)
    }

    private var permissionView: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.system(size: 36))
                .foregroundColor(.orange)

            Text("Accessibility Permission Required")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("MacMoji needs Accessibility access to detect your typing and insert emojis.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("Check Again") {
                hasAccessibility = AXIsProcessTrusted()
                if hasAccessibility {
                    KeyboardMonitor.shared.start()
                }
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)

            Spacer()
        }
        .padding(.top, 8)
    }

    private func instructionRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.accentColor)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}
