# MacMoji

Type Slack-style emoji shortcodes anywhere on your Mac and they instantly become real emojis. Works in iMessage, email, Slack, Notes, browsers -- everywhere you type.

Made with Devin

---

## What It Does

MacMoji runs in the background and watches for Slack-style shortcodes as you type:

- **Auto-replace**: Type `:fire:` and it instantly becomes the fire emoji
- **Autocomplete**: Type `:fi` and a popup appears with matching emojis -- press **Tab** or **Enter** to insert one
- **Works everywhere**: Any text field on your Mac -- iMessage, email, browsers, Notes, etc.
- Lives in your **menu bar** as a smiley face icon

### How It Works

1. Start typing a colon `:` anywhere on your Mac
2. As you type letters after the colon, a small popup appears with matching emoji suggestions
3. Pick an emoji by:
   - Pressing **Tab** or **Enter** to insert the highlighted emoji
   - Using **arrow keys** to navigate the suggestions
   - Finishing the shortcode with a closing colon (e.g., `:fire:`) to auto-replace
4. Press **Escape** to dismiss the popup

### Examples

| You type     | You get |
|--------------|---------|
| `:fire:`     | fire emoji (auto-replaced)  |
| `:eyes:`     | eyes emoji (auto-replaced)  |
| `:jo` + Tab  | joy emoji (autocomplete)    |
| `:heart:`    | heart emoji (auto-replaced) |
| `:th` + Tab  | thumbsup emoji (autocomplete) |
| `:rocket:`   | rocket emoji (auto-replaced) |

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

6. **Grant Accessibility Permission** (first time only)
   - A system popup will ask you to grant MacMoji Accessibility access
   - Click **"Open System Settings"** (or go to System Settings > Privacy & Security > Accessibility)
   - Find **MacMoji** in the list and **toggle it ON**
   - You may need to click the lock icon and enter your password first
   - Go back to MacMoji's menu bar icon and click **"Check Again"** to confirm

7. **Find MacMoji in your menu bar**
   - Look at the **top-right of your screen** (near the clock, Wi-Fi, battery icons)
   - You'll see a new **smiley face icon** -- that's MacMoji!
   - Click it to see the status and usage instructions

8. **Start typing emojis!**
   - Open any app (iMessage, Notes, a browser, etc.)
   - Type `:fire:` -- it will be replaced with the fire emoji
   - Or type `:fi` and pick from the autocomplete popup

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

### Emojis are not being replaced / no popup appears
- Click the MacMoji smiley face in the menu bar -- check if the status shows "Active" with a green dot
- If it says "Needs Permission", click **"Open System Settings"** and enable Accessibility for MacMoji
- After enabling, click **"Check Again"** in the MacMoji popup
- You may need to quit and restart MacMoji after granting permissions

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
- Accessibility permission (prompted on first launch)
