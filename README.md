# DoomsBlocker 🛡️
> **YouTube Shorts Doomscrolling Stopper & Nephew Screen Time Limiter for Android**

Built with **Flutter** (UI) and **Native Android Kotlin** (System Accessibility, Usage Monitoring, and Overlay Lockout Engine).

---

## 🌟 Key Features

### 1. YouTube Shorts 5-Minute Scroll Limiter & 30-Minute Lockout
* **Shorts Detection:** Detects when you enter YouTube Shorts without root or special firmware.
* **Stopwatch:** Tracks active scrolling time inside Shorts.
* **Strict Lockout:** Once you reach **5 minutes** of Shorts scrolling:
  * YouTube is immediately minimized to the Home Screen.
  * A 30-minute lockout is initiated.
  * If you try to open YouTube within those 30 minutes, an unclosable full-screen overlay appears displaying an active live countdown timer: `29:59`...
  * You cannot bypass the lock screen unless you wait out the 30 minutes or enter your secret **Parent PIN**.

### 2. Nephew Mode (20-Minute Limit on YouTube & Games)
* Mark any installed games (e.g., *Subway Surfers, Free Fire, Roblox, Candy Crush*) or YouTube.
* Limits play time to **20 minutes per day / session**.
* Once 20 minutes is exhausted, the app is closed and locked with the message: *"Time limit reached (20 mins). Screen time limit for this game has ended."*
* Protected by a 4-digit Parent PIN (Default: `1234`).

### 3. Block Specific YouTube Channels
* Blacklist distracting channels (e.g., *Skibidi Toilet, Cocomelon*, etc.).
* Whenever a video from a blacklisted channel plays or its channel page opens, the Accessibility Service detects the channel name and instantly ejects out to the home screen.

---

## 📱 Required Android Permissions

Because DoomsBlocker enforces system-level controls, it requires 3 Android system permissions:

1. **Accessibility Service (`DoomsAccessibilityService`)**:
   - Detects the YouTube Shorts viewport layout.
   - Inspects active video/channel titles for blacklisted names.
   - Immediately closes locked apps (`GLOBAL_ACTION_HOME`).
2. **Display Over Other Apps (`SYSTEM_ALERT_WINDOW`)**:
   - Renders the fullscreen countdown lock screen over locked apps.
3. **Usage Access (`PACKAGE_USAGE_STATS`)**:
   - Measures screen time accurately for marked games.

---

## 🚀 How to Build the APK

### Prerequisites
1. **Flutter SDK** (v3.0.0 or higher) installed and added to your system `PATH`.
2. **Android SDK** & JDK 17 (installed via Android Studio).

### Build Commands

Open terminal in the project folder (`DoomsBlocker`):

```bash
# 1. Fetch Flutter dependencies
flutter pub get

# 2. Build Release APK
flutter build apk --release
```

To build a smaller, optimized APK for your specific phone architecture:
```bash
flutter build apk --split-per-abi
```

### Where to Find Your APK
Once compilation completes, your APK file will be located at:
```text
build/app/outputs/flutter-apk/app-release.apk
```

---

## 📲 Installing on Your Android Phone

### Option A: Using USB & ADB (Recommended - Bypasses WhatsApp/Play Protect restrictions)
Connect your phone with USB debugging enabled:
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Option B: Direct Phone Transfer (WhatsApp / Google Drive)
1. Copy `app-release.apk` to your phone via USB cable, Google Drive, WhatsApp, or Bluetooth.
2. If **Google Play Protect** shows *"App blocked to protect your device"*:
   - Open **Google Play Store** on your phone.
   - Tap your **Profile icon** (top right) $\rightarrow$ **Play Protect**.
   - Tap the **Settings gear** icon (top right) and temporarily turn OFF **"Scan apps with Play Protect"**.
   - Tap `app-release.apk` again $\rightarrow$ **Install**.
   - Once installed, you can turn Play Protect scanning back on.
3. Open **DoomsBlocker**.
4. **Important for Android 13 / 14 / 15 (Restricted Settings)**:
   - If Accessibility is grayed out: Phone Settings $\rightarrow$ Apps $\rightarrow$ DoomsBlocker $\rightarrow$ 3 dots (top right) $\rightarrow$ **"Allow restricted settings"** $\rightarrow$ Confirm your fingerprint/PIN.
5. Tap the warning icon in DoomsBlocker to toggle all 3 permissions ON:
   - **Accessibility** $\rightarrow$ Installed Apps $\rightarrow$ Turn ON **DoomsBlocker**.
   - **Display over other apps** $\rightarrow$ Allow for **DoomsBlocker**.
   - **Usage access** $\rightarrow$ Allow for **DoomsBlocker**.

---

## 📂 Project Structure

```text
DoomsBlocker/
├── pubspec.yaml                        # Flutter dependencies
├── README.md                           # Documentation & build guide
├── lib/
│   ├── main.dart                       # App entry point & Dark theme
│   ├── models/
│   │   ├── dashboard_data.dart         # Dashboard statistics model
│   │   └── installed_app_model.dart    # Installed application model
│   ├── services/
│   │   └── native_bridge.dart          # MethodChannel bridge to Android
│   ├── widgets/
│   │   └── pin_dialog.dart             # 4-Digit Parent PIN prompt
│   └── screens/
│       ├── dashboard_screen.dart       # Live status, timers & quick toggles
│       ├── shorts_settings_screen.dart # 5-min scroll / 30-min lock settings
│       ├── game_limits_screen.dart     # Select games with 20-min limit
│       ├── blocked_channels_screen.dart# YouTube channel blacklist
│       ├── nephew_mode_screen.dart     # Nephew mode switch & PIN configuration
│       └── permissions_guide_screen.dart# One-tap permission setup
└── android/
    ├── app/
    │   ├── build.gradle                # Android app build configuration
    │   └── src/main/
    │       ├── AndroidManifest.xml     # Permissions & Service declarations
    │       ├── res/
    │       │   ├── layout/activity_overlay_lock.xml # Fullscreen lock overlay
    │       │   └── xml/accessibility_service_config.xml # Accessibility filters
    │       └── kotlin/com/doomsblocker/app/
    │           ├── MainActivity.kt                  # Flutter MethodChannel handler
    │           ├── DoomsAccessibilityService.kt     # Shorts & Channel & Game detection
    │           ├── AppMonitorForegroundService.kt   # Persistent background timer
    │           ├── OverlayLockActivity.kt           # 30-minute countdown lock screen
    │           └── AppPreferences.kt                # Persistent settings & timers
```

---

## 🔒 Security & Default PIN
* The default Parent PIN is: `1234`.
* You can change this anytime from the **Nephew Mode & Parent PIN** screen.
