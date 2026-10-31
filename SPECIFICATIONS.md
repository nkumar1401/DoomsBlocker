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
  * **Kids Mode Disabled**: PIN is not required for normal usage; parent PIN is strictly for Kids Mode overrides.

### 1.2 Mode B: Kids Mode Protection (Formerly Nephew Guard Mode)
* **Goal**: Strict child screen-time limiter and brain-rot shield for YouTube, Games, and Social Media.
* **Invariants**:
  * **Zero-Tolerance Short-Form Lockout (0s Allowance)**:
    * YouTube Shorts, Instagram Reels, Snapchat Spotlight, TikTok, Moj, Josh, and ShareChat are **100% prohibited (0 seconds tolerance)**.
    * The instant a child taps into Shorts or Reels, media is destroyed and `OverlayLockActivity` displays `REASON_KIDS_SHORTS_BLOCKED` ("Shorts & Reels Blocked in Kids Mode to protect attention span") with a smooth 5-second auto-dismiss to the Home screen.
  * **Long-Form Educational YouTube Allowance**:
    * Long-form YouTube videos (lectures, tutorials, cartoons, educational documentaries) are **allowed** up to the parent's configured limit (`prefs.shortsLimitMinutes * 60` seconds, e.g. 20 min).
    * Only active long-form viewing increments the usage counter.
  * **30-Minute Cooldown Lockout**:
    * When the long-form YouTube limit is reached, YouTube is completely locked for a **30-minute cooldown period** (`prefs.youtubeLockUntilTimestamp = now + 30 * 60 * 1000L`).
    * When the 30-minute cooldown expires, `youtubeLockUntilTimestamp` is cleared and `shortsUsedSecondsToday` automatically resets to 0, granting a fresh session.
    * Parents can override the cooldown at any time using their 4-digit Parent PIN.
  * **Social Media & Pure Short-Form 24/7 Complete Lockdown**:
    * Pure social networks and short-form video clones (Instagram, Snapchat, Facebook, TikTok, Twitter/X, Reddit, ShareChat `in.mohalla.sharechat`, Moj `in.mohalla.video`, Josh `com.eterno.shortvideos`) are **completely blocked 24/7 (0-second tolerance)** in Kids Mode. Children under 13 cannot access short feeds. Media is immediately destroyed and `OverlayLockActivity` displays `REASON_KIDS_SHORTS_BLOCKED` or `REASON_KIDS_SOCIAL_BLOCKED` with an auto-dismiss to Home.
  * **Selected Games Daily Limit**:
    * Measures total active screen time across all marked games (`prefs.gameLimitMinutes * 60` seconds).
    * When limit is reached, displays `REASON_GAME_LIMIT` for a smooth 5-second countdown before auto-dismissing to Home.
  * **PIN Protection**:
    * 4-digit Parent PIN (default: `1234`) is required to toggle Kids Mode, change limits, or perform emergency unlocks. Dual recovery via device biometrics (fingerprint/pattern) and Google 1-Tap authentication.

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

### 6.3 Dual Hour/Minute Scroll Wheel Duration Pickers (Ergonomic Invariant)
* **Zero Mental Math**: In place of single-field minutes text inputs, custom durations across the entire application (Shorts Scroll Limit, Lockout Cooldown Duration, Game Session Limits, and Study Zone Goals) use dual Cupertino scroll wheels:
  * **Hours Wheel**: 0 to max hours (44px item extent, native magnifier).
  * **Minutes Wheel**: 0 to 59 minutes.
  * **Live Duration Preview**: Displays formatted string e.g. `2 hr 30 min (150 min)` dynamically.
  * **Quick Preset Chips**: Provides immediate 1-tap presets (e.g. 15m, 30m, 1h, 2h, 4h).
* **Kids Mode Card Navigation & Rules Invariant**:
  * On Dashboard, tapping anywhere on the Kids Mode card (or its `Rules >` badge) opens the dedicated `KidsModeScreen`.
  * `KidsModeScreen` presents detailed explanations for each rule (YouTube limits, selected games daily limits, restricted channels blocked, parent PIN protection) and includes 1-tap configuration shortcuts.
  * The quick switch toggle on the right continues to support 1-tap toggle protected by PIN authentication.





---

## 7. Kids Mode 9-Day Trial, Contextual Google Login & ₹9/Year Subscription (Phase C)

### 7.1 Zero-Friction Adult Mode & Study Zone Immunity Invariant
* **General Users & Students**: Users utilizing Adult Focus Mode (YouTube Shorts limiter) and Library Study Zone **never see a login prompt, account creation, or paywall**. The app is 100% free forever for exam focus and general doomscrolling protection.
* **Contextual Authentication**: Google 1-Tap Sign-In is required **only** on Day 10+ when parents choose to subscribe to Kids Mode protection.

### 7.2 9-Day Free Trial Window Invariant
* **Unrestricted Trial**: Every installation begins with a 9-day unrestricted free trial of Kids Mode starting from `kidsModeFirstInstalledAt`.
* **Calculation**: `trialDaysRemaining = clamp(9 - floor((now - installedAt) / (1000 * 60 * 60 * 24)), 0, 9)`.
* **Trial Active State**: Kids Mode can be toggled and configured freely while `trialDaysRemaining > 0`.
* **Trial Expiration**: Once `trialDaysRemaining == 0` (Day 10+), attempting to toggle Kids Mode ON triggers the contextual Paywall bottom sheet.

### 7.3 Google Play Billing & ₹9/Year Subscription Invariant
* **SKU**: `doomsblocker_kids_annual_9inr` (₹9.00 INR per year).
* **Payment Methods**: Google Play Billing natively supports Google Pay (GPay), PhonePe, Paytm, BHIM UPI, Net Banking, Debit/Credit Cards (RuPay, Visa, MasterCard), and Google Play balance.
* **Merchant Account Payout**: All net revenue (85% after Google's 15% platform fee) is automatically deposited into the developer's registered Indian bank account via Google Play Console Merchant Profile.
* **Cross-Device Restore**: Parents can reinstall or change phones and restore their active subscription in 1 tap via `InAppPurchase.restorePurchases()`.

### 7.4 Production-Ready Kids Mode & Developer Simulation Suite Invariant
* **Production User Interface**: The developer simulation panel is removed from `KidsModeScreen` for production end-users. Real users only see the clean active subscription status banner ("⭐ Active Annual Subscriber" or "🎁 Free Trial Active: X days remaining") and the contextual ₹9/year paywall on expiration.
* **Underlying Test Methods Retained**: Helper methods in `SubscriptionService` (`simulateDay10Expiry()`, `simulateMockPurchase()`, `resetTrialToDay1()`) remain permanently accessible for automated regression suites (`test/spec_driver_test.dart`).

---

## 8. Theme & Security UI Invariants

### 8.1 Silver-White Light Theme Constitution
* **Background Surface**: App-wide background is styled in crisp Silver-White (`#F8FAFC` / `#F1F5F9`).
* **Card & Glassmorphism Surfaces**: Elevated cards use pure white (`#FFFFFF`) with subtle silver borders (`#E2E8F0`) and soft ambient shadows (`BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))`).
* **High-Contrast Dark Slate Typography**:
  * Primary titles, headers, and metrics use deep Slate-900 (`#0F172A`).
  * Subtitles, descriptions, and labels use readable Slate-500 (`#64748B`).
* **System UI Overlay**: Status bar and navigation bar icons enforce `Brightness.dark` for crystal-clear readability against the light background.
* **Preserved Vibrant Accents**: All functional accent colors (Cyan `#06B6D4`, Emerald `#10B981`, Amber `#F59E0B`, Crimson `#EF4444`, Blue `#3B82F6`, Purple `#8B5CF6`) remain 100% vibrant and recognizable.

### 8.2 Security PIN Setup vs. Reset Semantic Invariant
* **First-Time PIN Creation**: Displayed during onboarding or when no PIN exists (`isUpdating = false`). Dialog title is `"Create Security PIN"`, and confirmation title is `"Confirm Security PIN"`.
* **PIN Updating / Resetting**: Triggered from Dashboard, Kids Mode screen, or biometric recovery (`isUpdating = true`). Dialog title strictly displays `"Set New Security PIN"`, and confirmation title strictly displays `"Confirm New Security PIN"` with subtitle `"Choose a new 4-digit PIN to protect your settings, channel blocks, and app limits."`
* **Dashboard Subtitle**: When a PIN is set, the tile subtitle displays `"Parent PIN Set (Tap to Reset)"` so parents clearly know they can update it anytime.

---

## 9. Onboarding, Notification 1-Tap & Sideloaded Restricted Setting Invariants

### 9.1 Android 13+ 1-Tap Runtime Notification Permission
* **Native Dialog Integration**: On Android 13+ (API 33+), the app invokes `requestPermissions` for `android.permission.POST_NOTIFICATIONS` via a dedicated `NativeBridge.requestNotificationPermission()` channel. This triggers the native system permission dialog in 1 tap directly inside the onboarding flow.
* **Non-Blocking Graceful Degradation**: Notification permission is strongly encouraged to ensure real-time countdown updates and foreground stability, but onboarding does not hard-block dashboard access if a user declines it.

### 9.2 Android 13/14/15 Sideloaded "Restricted Setting" Resolution
* **Root Cause**: Android 13+ automatically disables Accessibility Service toggles ("Restricted setting - For your security, this setting is currently unavailable") exclusively for APKs installed outside the Google Play Store (sideloaded / untrusted installer).
* **Play Store Exemption**: APKs downloaded directly from the Google Play Store are cryptographically certified by the Play package installer and **never** trigger the "Restricted Setting" grey-out.
* **1-Tap Direct Shortcut**: Both `OnboardingSetupScreen` and `PermissionsGuideScreen` provide an actionable `[Open App Info (Allow Restricted Settings)]` button executing `Settings.ACTION_APPLICATION_DETAILS_SETTINGS` with `package:$packageName`. This takes the user straight to DoomsBlocker's App Info page where they can tap the top 3 dots $
ightarrow$ "Allow restricted settings" without manual searching.
* **Illustrated Step-by-Step OEM Guide**: An interactive bottom sheet modal (`AccessibilityGuideDialog`) displays clear visual step pills (`Settings → Downloaded Apps → DoomsBlocker → Turn ON`) customized by manufacturer tabs (**Samsung**, **Xiaomi / Redmi / Poco**, **Vivo / Oppo / Realme**, and **Other / Stock Android**).
* **Shortcut Toggle Prevention Invariant**: All guide instructions explicitly instruct users to leave the accessibility "Shortcut" switch **OFF**, preventing the Android floating human accessibility button from cluttering the user's screen.

---

## 10. Play Console Target Audience & Paywall Disclosures Compliance

### 10.1 18+ Parental Classification (COPPA & Families Policy Exemption)
* **Target Audience Declaration**: In the Google Play Console, target age is declared strictly as **18 and over (Adults/Parents)** with "Could your app appeal to children?" set to **No**.
* **Parental Control Framing**: The gated feature is framed as a "Parental Control Tool for Parents" ("Parental Controls (Kids Mode)") rather than an app designed for child use. This avoids Families Policy bans on standard Google OAuth and analytics SDKs.
* **Reviewer Instructions**: Clear Play Console test credentials and instructions are provided for reviewers: core digital wellbeing features are open without login; Kids Mode trial is reviewable via Google test accounts.

### 10.2 Mandatory Play Store Paywall Disclosures
* **Exact Subscription SKU & Name**: The purchase sheet clearly presents `"Kids Mode Annual Subscription"` / `"Kids Mode 1-Year Pass"`.
* **Explicit Trial & Renewal Terms**: State `"9-day free trial, then ₹9.00 / 1-Year Pass (or localized $9.00/year)"`.
* **24-Hour Cancellation Disclosure**: Displays explicit terms: *"Cancel anytime in Google Play Subscriptions at least 24 hours before the trial ends or renewal date to avoid being charged."*

---

## 11. Prepaid Recharge Model (No AutoPay), Expiry Alerts & Lock Architecture

### 11.1 100% Prepaid Recharge Model (No Auto-Debit Mandate)
* **Prepaid Base Plan**: To maximize consumer trust in India and eliminate fears of unexpected bank deductions, the subscription is configured in Google Play Console as a **Prepaid Plan** (`kids_mode_annual_prepaid` / `doomsblocker_kids_annual_prepaid`).
* **One-Time UPI Payment**: Users pay once (₹9.00 for 365 days) using Google Pay, PhonePe, Paytm, BHIM UPI, Net Banking, or Debit/Credit Cards. Zero recurring AutoPay mandate is created.
* **Peaceful Expiration**: When the 365 days elapse, the pass expires peacefully without touching the user's bank account. Kids Mode simply disables itself and returns to Adult Focus Mode until manually recharged.

### 11.2 48h & 24h Expiry Push Notifications
* **Pre-Expiry Reminders**: Background checks track `prepaidHoursRemaining`. When a pass has $\le 48	ext{h}$ and $\le 24	ext{h}$ remaining, local high-priority notifications are dispatched:
  * Title: *"Parental Controls Plan Expiring Soon"*
  * Body: *"Your 1-Year Parental Controls pass expires tomorrow. Tap to recharge for ₹9 with zero auto-debit."*
* **1-Tap Recharge Deep Link**: Tapping the notification opens DoomsBlocker directly into the Kids Mode screen with the recharge paywall sheet ready.

### 11.3 5-Second Popup & PIN Scope Invariant
* **Dopamine-Break Popups**: On rapid dopamine break triggers (`REASON_SHORTS_LIMIT`, `REASON_KIDS_SHORTS_BLOCKED`, `REASON_KIDS_SOCIAL_BLOCKED`, `REASON_CHANNEL_BLOCKED`, `REASON_STUDY_ZONE`, and WindowManager overlay), the PIN override section is strictly hidden (`pinSection.visibility = View.GONE`).
* **Guaranteed Auto-Home**: Popups strictly count down `5s -> 4s -> 3s -> 2s -> 1s -> 0s` and automatically redirect to the phone's Home Screen (`CATEGORY_HOME`) with a 1.5-second back-press immunity guard.
* **Parent PIN Scope**: PIN authentication is strictly reserved for:
  1. Accessing and editing app settings, channel lists, and limits inside DoomsBlocker.
  2. Disabling Kids Mode from the Dashboard or Kids Mode screen.
  3. Parent emergency cooldown override (`REASON_YOUTUBE_LOCKED` / `REASON_GAME_LIMIT`).
---

## 12. 5-Second Popup PIN Unlock, Auto-Pause, Resume Target App & Silver Theme Invariants

### 12.1 5-Second Popup PIN Availability for Rapid Dopamine Locks
* **Scoped PIN Visibility**: On rapid dopamine break popups (`REASON_SHORTS_LIMIT`, `REASON_GAME_LIMIT`, `REASON_CHANNEL_BLOCKED`, `REASON_KIDS_SHORTS_BLOCKED`, `REASON_KIDS_SOCIAL_BLOCKED`, `REASON_YOUTUBE_LOCKED`), the PIN unlock button (`"Unlock with Security PIN"`) is visible and accessible.
* **Study Zone Cheat-Proof Invariant**: For `REASON_STUDY_ZONE`, the PIN section is **strictly hidden** (`pinSection.visibility = View.GONE`). Library sessions can only be released via countdown expiration (00:00:00) or scanning the physical Exit QR poster.

### 12.2 Countdown Timer Auto-Pause on PIN Interaction
* **No-Rush Freeze**: Tapping "Unlock with Security PIN" or focusing the PIN input immediately cancels/pauses the 5-second countdown timer.
* The timer badge switches from counting down to a prominent `"PAUSED"` / `"PIN UNLOCK ACTIVE"` status badge, giving the user ample time to enter their 4-digit security PIN without being evicted to the home screen.

### 12.3 Targeted App Resume upon Valid PIN Verification
* Entering the correct 4-digit PIN clears the active lockout in SharedPreferences and immediately resumes the specific locked target app (e.g., Instagram, YouTube, Roblox) via `packageManager.getLaunchIntentForPackage(targetPackage)` instead of redirecting the user to the device home screen.

### 12.4 Real-Time Study Zone Background Notification Ticker
* While a Study Zone session is active, the foreground service notification dynamically updates every second.
* **Notification Content**:
  * Title: `"📚 Study Zone: [Library Name] • [HH:mm:ss]"` (or `[mm:ss]` when hours == 0).
  * Text: Displays remaining focus time alongside active distraction lockdown details.

### 12.5 Silver-White Theme Consistency
* **Scaffold & Surfaces**: Converted from dark navy (`#080D1A`/`#131B2E`) to Silver-White (`#F8FAFC`) with pure white (`#FFFFFF`) cards and Slate-200 (`#E2E8F0`) borders.
* **Text Contrast**: All titles, subtitles, and input fields use dark slate (`#0F172A`/`#334155`/`#64748B`) to guarantee WCAG AA contrast.
* **Unified Screens**: `study_zone_screen.dart`, `game_limits_screen.dart`, `blocked_channels_screen.dart`, and `activity_overlay_lock.xml` are 100% harmonized.
