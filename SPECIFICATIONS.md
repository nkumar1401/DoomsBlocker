# DoomsBlocker — System Specifications & Invariants

This document serves as the **Single Source of Truth (SSOT)** for DoomsBlocker. Any future feature addition or code modification must comply with these specifications and pass the Automated Spec Driver.

---

## 1. Core Operating Modes

### 1.1 Mode A: Adult Focus Mode
* **Goal**: Stop doomscrolling on short-form feeds without blocking educational long-form videos or productive communication.
* **Unified Short-Form Pool (YouTube Shorts & Instagram)**:
  * **Short-Form Tracking**: Time spent inside YouTube Shorts or active inside Instagram (including home feed reels and the clips viewer) increments the shared `shortsUsedSecondsToday` pool.
  * **YouTube Shorts Scope**:
    1. **Fullscreen Shorts Player**: Opened from bottom Shorts tab, tapped from Home feed shelf, search, or external links.
    2. **Home Feed Shorts Shelf**: Actively playing or scrolling through vertical Short cards in the Home feed carousel.
  * **YouTube Long-Form Exemption (Invariant 2)**: Long-form YouTube videos (lectures, tutorials, news, podcasts, `watch_player`) and non-Shorts Home Feed browsing (16:9 regular video posts and feed overviews) are **100% permitted** and immediately pause the scroll timer without requiring an app restart.
  * **Dynamic Threshold**: Shared limit is read dynamically from `prefs.shortsLimitMinutes * 60` (Default: 5 min).
  * **Lock Action**: When `usedSec >= limitSec` (whether in fullscreen Shorts or on the Home feed Shorts shelf) or during active lockout window (`shortsLockDurationMinutes`):
    1. Immediately pause media audio and request transient audio focus.
    2. In YouTube: Vertical short-form player is ejected/blocked, preserving educational long-form playback.
    3. In Instagram: The entire Instagram application is locked to prevent home-feed reels doomscrolling.
    4. Display `OverlayLockActivity` with `REASON_SHORTS_LIMIT` for a smooth 5-second countdown popup.
    5. Auto-dismiss to Phone Home Screen upon countdown expiry.
  * **Blocked Channels (Soft Search Immunity Invariant)**: Channels listed in `prefs.blockedChannels` are strictly blocked ONLY when a video from that channel is actively playing (opened on the video watch screen or fullscreen Shorts) using case-insensitive matching across channel handles (e.g. `@Firstpost`), avatars, and video metadata. Typing in the search bar (`search_edit_text`), viewing search suggestions, and scrolling through search results or feed recommendation lists are **100% immune** from lock action. As soon as a blocked channel video opens and starts playing, it immediately pauses media and displays `OverlayLockActivity.REASON_CHANNEL_BLOCKED` for a 5-second countdown popup before returning to Home.
  * **Cooldown Expiration & Scroll Time Reset Invariant**:
    * When the configured cooldown lockout window finishes (`System.currentTimeMillis() >= youtubeLockUntilTimestamp`), the lockout timestamp is cleared and `shortsUsedSecondsToday` automatically resets to 0.
    * The user receives a fresh scroll time allowance for their new session without re-triggering the lockout.
    * The persistent notification immediately transitions to the unlocked status icon (`ic_notification_unlocked`) and resets its progress bar to `00:00 / <limit>`.
  * **Nephew Mode Disabled**: PIN is not required for normal usage; parent PIN is strictly for Nephew Mode overrides.

### 1.2 Mode B: Nephew Guard Mode
* **Goal**: Strict child screen-time limiter for YouTube, Games, and Social Media.
* **Invariants**:
  * **Total YouTube Block**: When locked or limit reached, locks the **entire** YouTube application (both Shorts and long-form).
  * **Restricted Apps / Games**: Measures total active screen time across all selected games.
  * **Daily Limit**: `gameLimitMinutes * 60` seconds. (Excludes phone Settings, System UI, Play Store, and Phone dialer).
  * **Smooth Game Lock Action**: When a game crosses its limit:
    1. Silence background media and pause audio.
    2. Display `OverlayLockActivity` with `REASON_GAME_LIMIT` for a smooth 5-second countdown popup.
    3. Never trigger `GLOBAL_ACTION_HOME` concurrently with overlay start; allow the 5-second timer to auto-dismiss smoothly to Home.
  * **PIN Protection**: 4-digit Parent PIN (default: `1234`) is required to bypass or modify rules.

---

## 2. Library Study Zone (PIN-Free Physical QR Goal Lock)

### 2.1 State Machine Specification

```text
       [ State: IDLE / NOT CHECKED IN ]
              |                  |
   Scan Entrance QR        Scan Exit QR
              |                  |
              v                  v
     [ Goal Picker Modal ]   [ Warning: Not Checked In ]
              |              (Directs to scan Entrance)
     Select Duration & Lock
              |
              v
       [ State: ACTIVE STUDY SESSION ]
              |                  |
   Scan Entrance QR        Scan Exit QR
              |                  |
              v                  v
     [ Info: Already Active ] [ Confirm Exit Modal ]
     (Directs to scan Exit)      |
                              Confirm
                                 |
                                 v
                     [ State: IDLE / UNLOCKED ]
```

### 2.2 Study Zone Invariants
1. **Short-Form Content**: 100% blocked immediately. Opening YouTube Shorts displays the 5-second Study Zone countdown lock overlay.
2. **Social Media & Gaming**:
   * Instagram (`com.instagram.android`), Snapchat, TikTok, Facebook, Twitter/X, Reddit, and all marked games are **blocked immediately** upon opening.
   * Lock overlay displays: Library name, remaining study timer, and notice that distractions are locked.
3. **Educational YouTube Videos**: Long-form videos (news, current affairs, lectures) are **100% permitted** during Study Zone.
4. **PIN Bypass Immunity**: The Personal PIN override is completely disabled during an active Study Zone session. Focus can only be released by:
   * Natural expiration of the study timer (`studyZoneRemainingSeconds <= 0`).
   * Scanning the physical Desk Exit QR poster (`DOOMSBLOCKER_STUDY:OUT:<zoneName>`).
5. **Study Durations**:
   * Presets: 30m, 45m, 1h, 2h, 3h, 4h, 6h, 8h, 10h, 12h.
   * Slider: 15m to 12 Hours (15-minute increments).
   * Custom Time Input: Type any exact hours and minutes up to 24 Hours (e.g., 10h 30m).
6. **Permanent Physical QR Poster Guarantee (Forward-Compatibility Invariant)**:
   * Physical posters printed and pasted at the reception desk (`DOOMSBLOCKER_STUDY:IN:<zoneName>` and `DOOMSBLOCKER_STUDY:OUT:<zoneName>`) are **Permanent and Immutable**.
   * Library managers print the 2 posters **once**. The posters will continue to scan and function identically across all future Google Play Store updates of DoomsBlocker without ever requiring re-printing or poster replacement.
   * Scanner parsers must permanently guarantee whitespace trimming, protocol case-insensitivity, and robust zone name extraction.

---

## 3. Native Accessibility & Background Tracking Specifications

### 3.1 Package Event Filtering
* **Protected System Packages**: `com.android.systemui`, `com.google.android.inputmethod.latin` (keyboards), volume sliders, and notification shades must **never** overwrite `activePackage` or reset `isInsideShorts`.
* **Foreground Verification**: The 1-second background ticker directly verifies `rootInActiveWindow?.packageName` to prevent false exits.

### 3.2 Overlay Lock Screen & Dismissal Dynamics
* **Initial Debounce**: Debounce lock screen triggers by 2.5 seconds to prevent rapid duplicate activity calls.
* **Back-Press Immunity**: `OverlayLockActivity.onBackPressed()` ignores back presses during the first 1.5 seconds after creation to absorb any trailing accessibility back actions and guarantee the 5-second countdown popup is smoothly visible.
* **Auto-Dismiss**: Countdown counts down `5s -> 4s -> 3s -> 2s -> 1s` and redirects to the phone's Home Screen via `Intent.CATEGORY_HOME`.

### 3.3 Multi-Brand OEM Compatibility & WindowManager Overlay Invariant
* **Multi-Brand Immunity (Xiaomi, Samsung, Vivo, Oppo, Realme)**: OEM skins restrict background activity launches (`startActivity`) from accessibility and foreground services.
* **Direct WindowManager Overlay**: When "Display over other apps" is granted, the 5-second countdown lock view is rendered directly via `WindowManager` (`TYPE_APPLICATION_OVERLAY`). This guarantees the smooth countdown popup displays reliably on 100% of Android devices without being blocked by Xiaomi/MIUI "Display pop-up windows while running in the background" restrictions.
* **OEM Setup Guidance**: Provide a 1-tap battery and autostart optimization helper card in the UI on devices from aggressive OEM manufacturers (Xiaomi, Samsung, Vivo, Oppo) to prevent background services from being terminated by OEM task killers.

---

## 4. UI Design & Scanner Standards
* **Camera Viewfinder**: Must use hardware-accelerated `CustomPainter` with `PathOperation.difference` to ensure a 100% clear transparent cutout window. Never use GPU blend-mode masks that glitch to solid red.
* **All Numbers Dynamic**: Every time rule, limit, and duration must be read from `SharedPreferences` / `NativeBridge`. Zero hardcoding.

---

## 5. Security Architecture (Google Pay-Style Session Authentication)

### 5.1 First-Time Setup & Onboarding Guard Invariant
* **Mandatory Setup Guard**: Upon app launch, if no PIN is configured (`isPinSet == false`) OR any of the 3 essential permissions (`accessibility`, `overlay`, `usageStats`) is missing, the app directs to a dedicated `OnboardingSetupScreen`.
* **Upfront PIN Creation**: The user must create and confirm their 4-digit Parent/Emergency PIN first so they can never be trapped in a lock window without a known PIN.
* **Live Permission Verification**: The 3 essential permissions (Accessibility Service, Display Over Other Apps, Usage Access) are displayed with live status checkmarks and 1-tap grant buttons.
* **Dashboard Gateway**: The "CONTINUE TO DASHBOARD" button is strictly unlocked only when the PIN is set and all 3 essential permissions are granted. Once configured, subsequent app launches proceed directly to the Dashboard.

### 5.2 Google Pay-Style Session Lifecycle
* **Single Unlock Per Session**: Once the user unlocks any protected section, the entire Control Panel stays authenticated in memory. Users can freely move between Shorts Rules, Blocked Channels, and App Limits without repetitive PIN prompts.
* **1-Minute Background Relock**:
  * When the app is in the foreground, the session remains active.
  * When the app moves to background (`paused` / `inactive`), the exit timestamp is recorded.
  * If the app is resumed after $\ge 60$ seconds, the session immediately relocks.
  * Explicit app termination or task swipe immediately invalidates the session.

### 5.3 Library Study Zone PIN-Free Exemption Invariant
* **Student Ergonomics**: The Library Study Zone is an educational productivity tool for students.
* **Absolute Exemption**: QR scanning, checking into a library, picking a focus goal, viewing active study timers, and scanning the Exit poster must **never** prompt for a PIN.

---

## 6. Future Platform Roadmap (v1.1.0 & v2.0 Architecture)

### 6.1 Multi-App Short-Form Selection (v1.1.0 Competitor Parity Specification)
* **Scope Selector**: Users can choose which short-form platforms contribute to their unified doomscrolling pool:
  * YouTube Shorts (Smart section tracking, long-form educational exemption)
  * Instagram Reels (Clips viewer and home-feed reels)
  * Snapchat (Spotlight feed vs chat)
  * Facebook (Facebook Reels vs feed posts)
  * Moj / Josh / ShareChat (Full-app lock for pure short-video clones)
* **Unified Screen-Time Pool**: All checked platforms share the same dynamic limit (e.g. 10 minutes total across all platforms) and enter the shared cooldown window together.
* **Hybrid Ejection Engine**: Pure short-video apps (Moj, Josh) lock the entire app, while multi-purpose platforms (Snapchat, Facebook) selectively block the vertical video player, preserving direct messages and communication.

### 6.2 Optional Cloud Backup & Cross-Device Sync (v2.0)
* **Launch Stance**: Version 1.0 launches as a 100% offline, zero-data-collection application to ensure instant Google Play review approval and frictionless student/user adoption.
* **v2.0 Authentication Provider**: Google 1-Tap Sign-In (native Android credential manager). Zero SMS gateway bills and instant 1-tap setup.
* **Opt-In Architecture**: 
  * The app remains completely usable without an account.
  * Users may optionally link their Google account from Settings to backup study streaks, restore blocked channel lists, and sync rules when switching phones.


