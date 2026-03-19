# MacMoji

A tiny Mac menu bar app that lets you type Slack-style emoji shortcodes (like `:fire:` or `:eyes:`) and copy the real emoji to your clipboard. Paste it into iMessage, email, notes, or anywhere else.

---

## What It Does

- Lives in your **menu bar** (top-right of your screen, near the clock)
- Click the smiley face icon to open it
- Type a shortcode like `fire`, `eyes`, `joy`, `thumbsup`, etc.
- Click an emoji to **copy it to your clipboard**
- Paste it anywhere with **Cmd + V**

### Examples

| You type   | You get |
|------------|---------|
| `fire`     | `fire emoji`    |
| `eyes`     | `eyes emoji`    |
| `joy`      | `joy emoji`     |
| `heart`    | `heart emoji`   |
| `thumbsup` | `thumbsup emoji`|
| `100`      | `100 emoji`     |
| `rocket`   | `rocket emoji`  |
| `sparkles` | `sparkles emoji`|
| `tada`     | `tada emoji`    |
| `skull`    | `skull emoji`   |

Includes **400+ emoji shortcodes** from Slack, covering smileys, hand gestures, hearts, animals, food, objects, flags, and more.

---

## How to Install & Run

### What You Need

- A Mac running **macOS 13 (Ventura) or newer**
- **Xcode** (free from the Mac App Store)
  - If you don't have it: Open the **App Store** on your Mac, search for "Xcode", and install it (it's a large download, ~7 GB, so give it some time)

### Step-by-Step Instructions

1. **Download this project**
   - Click the green **"Code"** button at the top of this GitHub page
   - Click **"Download ZIP"**
   - Find the downloaded ZIP file (usually in your Downloads folder) and double-click it to unzip

2. **Open the project in Xcode**
   - Open the unzipped folder
   - Double-click the file called **`MacMoji.xcodeproj`** (it has a blue icon)
   - Xcode will open with the project

3. **Trust the project** (if Xcode asks)
   - If you see a popup saying something about "trust", click **"Trust"** or **"Trust and Open"**

4. **Set your signing team** (first time only)
   - In Xcode, click on **"MacMoji"** in the left sidebar (the blue project icon at the very top)
   - Click the **"Signing & Capabilities"** tab
   - Under **"Team"**, click the dropdown and select your Apple ID
   - If your Apple ID isn't listed, click **"Add an Account..."** and sign in with your regular Apple ID (no paid developer account needed)

5. **Build and run the app**
   - In the top-left of Xcode, make sure it says **"MacMoji" > "My Mac"**
   - Click the **Play button** (triangle icon, top-left) or press **Cmd + R**
   - The first build may take a moment

6. **Find MacMoji in your menu bar**
   - Look at the **top-right of your screen** (near the clock, Wi-Fi, battery icons)
   - You'll see a new **smiley face icon** -- that's MacMoji!
   - Click it to open the emoji picker

7. **Use it!**
   - Type a shortcode in the search box (e.g., `fire`)
   - Click any emoji to copy it to your clipboard
   - Switch to iMessage (or any app) and press **Cmd + V** to paste

### How to Make It Open Automatically When You Start Your Mac

1. Open **System Settings** (click the Apple menu > System Settings)
2. Click **"General"** in the sidebar
3. Click **"Login Items"**
4. Click the **"+"** button
5. Navigate to **Applications**, find **MacMoji**, and click **"Add"**

> **Note:** To add MacMoji to your Applications folder, you can first build it in Xcode (Cmd + R), then in Xcode go to **Product > Show Build Folder in Finder**. Find `MacMoji.app` inside the `Build/Products/Debug/` folder and drag it to your **Applications** folder.

---

## How to Quit

Click the MacMoji icon in the menu bar, then click **"Quit"** at the bottom of the popup.

---

## Troubleshooting

### "MacMoji" is not appearing in my menu bar
- Make sure you clicked the Play button in Xcode and the build succeeded (no red errors)
- Look carefully at the right side of your menu bar -- the smiley face icon might be hidden behind the notch on newer MacBooks. Try expanding your menu bar by holding **Cmd** and dragging icons around

### Xcode says something about "signing" or "team"
- In Xcode, click on **"MacMoji"** in the left sidebar (the blue project icon at the very top)
- Click the **"Signing & Capabilities"** tab
- Under **"Team"**, select your personal Apple ID (you can sign in with any Apple ID for free -- you don't need a paid developer account)

### The app doesn't have an icon
- That's normal! The app uses a system smiley face icon in the menu bar. You can add a custom app icon later by replacing the images in `Assets.xcassets/AppIcon.appiconset/`

---

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later
