import SwiftUI

struct EmojiItem: Identifiable {
    let id: String
    let emoji: String

    init(shortcode: String, emoji: String) {
        self.id = shortcode
        self.emoji = emoji
    }

    var shortcode: String { id }
}

struct ContentView: View {
    @State private var searchText = ""
    @State private var copiedShortcode: String?
    @State private var displayedEmojis: [EmojiItem] = []

    private static let popularItems: [EmojiItem] = {
        EmojiDatabase.popular.compactMap { code in
            guard let emoji = EmojiDatabase.all[code] else { return nil }
            return EmojiItem(shortcode: code, emoji: emoji)
        }
    }()

    private static let allSorted: [(key: String, value: String)] = {
        EmojiDatabase.all.sorted { $0.key < $1.key }
    }()

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            emojiGrid
            Divider()
            footer
        }
        .frame(width: 340, height: 420)
        .onAppear {
            displayedEmojis = Self.popularItems
        }
        .onChange(of: searchText) { newValue in
            updateResults(query: newValue)
        }
    }

    private func updateResults(query: String) {
        let cleaned = query
            .lowercased()
            .replacingOccurrences(of: ":", with: "")
            .trimmingCharacters(in: .whitespaces)

        if cleaned.isEmpty {
            displayedEmojis = Self.popularItems
            return
        }

        var exactMatches: [EmojiItem] = []
        var prefixMatches: [EmojiItem] = []
        var containsMatches: [EmojiItem] = []

        for entry in Self.allSorted {
            if entry.key == cleaned {
                exactMatches.append(EmojiItem(shortcode: entry.key, emoji: entry.value))
            } else if entry.key.hasPrefix(cleaned) {
                prefixMatches.append(EmojiItem(shortcode: entry.key, emoji: entry.value))
            } else if entry.key.contains(cleaned) {
                containsMatches.append(EmojiItem(shortcode: entry.key, emoji: entry.value))
            }
        }

        var results = exactMatches
        results.append(contentsOf: prefixMatches)
        results.append(contentsOf: containsMatches)
        displayedEmojis = Array(results.prefix(120))
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
            if displayedEmojis.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6),
                        spacing: 4
                    ) {
                        ForEach(displayedEmojis) { item in
                            emojiButton(item: item)
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

    private func emojiButton(item: EmojiItem) -> some View {
        let isCopied = copiedShortcode == item.shortcode

        return Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.emoji, forType: .string)
            copiedShortcode = item.shortcode
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if copiedShortcode == item.shortcode {
                    copiedShortcode = nil
                }
            }
        }) {
            VStack(spacing: 2) {
                Text(item.emoji)
                    .font(.system(size: 26))
                Text(isCopied ? "Copied!" : ":\(item.shortcode):")
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
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("\(displayedEmojis.count) emojis")
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
}
