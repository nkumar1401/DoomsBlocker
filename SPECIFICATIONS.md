# DoomsBlocker — System Specifications & Invariants

This document serves as the **Single Source of Truth (SSOT)** for DoomsBlocker. Any future feature addition or code modification must comply with these specifications and pass the Automated Spec Driver.

---

## 1. Core Operating Modes

### 1.1 Mode A: Adult Focus Mode
* **Goal**: Stop doomscrolling on short-form feeds without blocking educational long-form videos.
* **YouTube Invariants**:
  * **Long-Form Videos**: 100% permitted. Lectures, news, documentaries, tutorials must play uninterrupted.
  * **Shorts Player**: Strictly tracked. Every second in Shorts adds to `shortsUsedSecondsToday`.
  * **Dynamic Threshold**: Limit is read dynamically from `prefs.shortsLimitMinutes * 60`. (Default: 5 min, selectable from 1 min to 180 min).
  * **Lock Action**: When `usedSec >= limitSec`:
    1. Immediately pause media audio (`KEYCODE_MEDIA_PAUSE`).
    2. Display `OverlayLockActivity` with `REASON_SHORTS_LIMIT` for a smooth 5-second countdown popup.
    3. Auto-dismiss to Phone Home Screen upon countdown expiry.
    4. Maintain active lockout window for `prefs.shortsLockDurationMinutes` (e.g., 30m, 2h, 8h).
  * **Nephew Mode Disabled**: PIN is not required for normal usage; parent PIN is strictly for Nephew Mode overrides.

### 1.2 Mode B: Nephew Guard Mode
* **Goal**: Strict child screen-time limiter for YouTube and Games.
* **Invariants**:
  * **Total YouTube Block**: When locked or limit reached, locks the **entire** YouTube application (both Shorts and long-form).
  * **Restricted Apps / Games**: Measures total active screen time across all selected games.
  * **Daily Limit**: `gameLimitMinutes * 60` seconds. (Excludes phone Settings, System UI, Play Store, and Phone dialer).
  * **Lock Action**: Immediate audio pause + `OverlayLockActivity` with `REASON_GAME_LIMIT` or `REASON_YOUTUBE_LOCKED`.
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

---

## 3. Native Accessibility & Background Tracking Specifications

### 3.1 Package Event Filtering
* **Protected System Packages**: `com.android.systemui`, `com.google.android.inputmethod.latin` (keyboards), volume sliders, and notification shades must **never** overwrite `activePackage` or reset `isInsideShorts`.
* **Foreground Verification**: The 1-second background ticker directly verifies `rootInActiveWindow?.packageName` to prevent false exits.

### 3.2 Overlay Lock Screen & Dismissal Dynamics
* **Initial Debounce**: Debounce lock screen triggers by 2.5 seconds to prevent rapid duplicate activity calls.
* **Back-Press Immunity**: `OverlayLockActivity.onBackPressed()` ignores back presses during the first 1.5 seconds after creation to absorb any trailing accessibility back actions and guarantee the 5-second countdown popup is smoothly visible.
* **Auto-Dismiss**: Countdown counts down `5s -> 4s -> 3s -> 2s -> 1s` and redirects to the phone's Home Screen via `Intent.CATEGORY_HOME`.

---

## 4. UI Design & Scanner Standards
* **Camera Viewfinder**: Must use hardware-accelerated `CustomPainter` with `PathOperation.difference` to ensure a 100% clear transparent cutout window. Never use GPU blend-mode masks that glitch to solid red.
* **All Numbers Dynamic**: Every time rule, limit, and duration must be read from `SharedPreferences` / `NativeBridge`. Zero hardcoding.
