import SwiftUI

struct ContentView: View {
    @State private var searchText = ""
    @State private var copiedShortcode: String?

    private var filteredEmojis: [(shortcode: String, emoji: String)] {
        let query = searchText
            .lowercased()
            .replacingOccurrences(of: ":", with: "")
            .trimmingCharacters(in: .whitespaces)

        if query.isEmpty {
            return EmojiDatabase.popular.compactMap { code in
                guard let emoji = EmojiDatabase.all[code] else { return nil }
                return (code, emoji)
            }
        }

        return EmojiDatabase.all
            .filter { $0.key.contains(query) }
            .sorted { a, b in
                let aPrefix = a.key.hasPrefix(query)
                let bPrefix = b.key.hasPrefix(query)
                if aPrefix != bPrefix { return aPrefix }
                let aExact = a.key == query
                let bExact = b.key == query
                if aExact != bExact { return aExact }
                return a.key < b.key
            }
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            emojiGrid
            Divider()
            footer
        }
        .frame(width: 340, height: 420)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 14))

            TextField("Type a shortcode... (fire, eyes, joy)", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
    }

    // MARK: - Emoji Grid

    private var emojiGrid: some View {
        Group {
            if filteredEmojis.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6),
                        spacing: 4
                    ) {
                        ForEach(filteredEmojis.prefix(150), id: \.shortcode) { item in
                            emojiButton(shortcode: item.shortcode, emoji: item.emoji)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No emojis found")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Try a different shortcode")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emojiButton(shortcode: String, emoji: String) -> some View {
        let isCopied = copiedShortcode == shortcode

        return Button(action: {
            copyToClipboard(emoji)
            withAnimation(.easeInOut(duration: 0.2)) {
                copiedShortcode = shortcode
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    if copiedShortcode == shortcode {
                        copiedShortcode = nil
                    }
                }
            }
        }) {
            VStack(spacing: 2) {
                Text(emoji)
                    .font(.system(size: 26))
                Text(isCopied ? "Copied!" : ":\(shortcode):")
                    .font(.system(size: 7))
                    .foregroundColor(isCopied ? .green : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(width: 50, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isCopied ? Color.green.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help(":\(shortcode):")
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("\(filteredEmojis.count) emojis")
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
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
