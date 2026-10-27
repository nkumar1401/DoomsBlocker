# DoomsBlocker — Official Google Play Console Submission Guide

This document contains **ready-to-use, copy-paste declarations and store metadata** designed to pass Google Play review on the first attempt.

---

## 1. Google Play Console: "App Content" Policy Declarations

### A. Accessibility Service Declaration (Critical ⚠️)

Google asks: *"How does your app use the AccessibilityService API?"*

* **Category to Select**: `Digital Wellbeing / Parental Controls / App Locker`
* **Video Link Requirement**: Provide an unlisted YouTube video URL demonstrating the accessibility flow.
* **Text for "Describe how your app uses the Accessibility API"**:
```text
DoomsBlocker is a digital wellbeing and focus application. It uses the AccessibilityService API solely to detect when a user is actively viewing short-form vertical video feeds (such as YouTube Shorts and Instagram Reels) and to enforce user-configured screen time limits and channel blocking.

1. Detection: The service inspects window state changes strictly to identify the vertical player interface.
2. Enforcement: When the user's configured scroll limit expires, the service safely navigates back to prevent doomscrolling and triggers our overlay countdown timer.
3. Privacy Guarantee: The AccessibilityService operates 100% locally on-device. It never records, collects, stores, or transmits any keystrokes, personal communications, passwords, or personal data. System UI, keyboards, and messaging apps are explicitly filtered out and ignored.
```

---

### B. Foreground Service Declaration (Special Use)

Google asks: *"Why does your app require FOREGROUND_SERVICE_SPECIAL_USE?"*

* **Selected Subtype**: `Screen time parental control and doomscrolling restriction`
* **Explanation Text**:
```text
DoomsBlocker requires a Special Use Foreground Service to provide reliable, real-time screen-time tracking and focus timers during active user study sessions (Library Study Zone) and game limiter sessions. 

The service runs a persistent notification informing the user of their remaining focus time and active lock status. Without this foreground service, the Android system would terminate the background timer, allowing addictive doomscrolling and bypassed parental limits. No other system foreground service type accurately describes real-time digital wellbeing restriction.
```

---

### C. Data Safety Questionnaire Answers

Complete the questionnaire with these exact options:

* **Does your app collect or share any user data?** $\rightarrow$ **NO**
* **Is all of the user data collected by your app encrypted in transit?** $\rightarrow$ **N/A** (No data collected)
* **Do you provide a way for users to request that their data be deleted?** $\rightarrow$ **YES** (Users can reset app data locally anytime via phone settings or by clearing storage)

---

### D. Target Audience and Content Rating

* **Target Age**: 13 and older (or select 18+ for adult focus, or 13–17 and 18+).
* **Could this app appeal to children?** $\rightarrow$ **NO** (Select No to avoid strict "Designed for Families" review unless you specifically target kids under 13).
* **Ads**: Select **"No, my app does not contain ads"**.
* **App Access**: Select **"All features are available without special access"** (or explain that Parental PIN can be set directly within the app).

---

## 2. Store Listing Assets & Text

### App Title (Max 30 characters)
```text
DoomsBlocker: Focus & Study
```

### Short Description (Max 80 characters)
```text
Block YouTube Shorts, Instagram Reels & lock distractions with QR Study Zone.
```

### Full Description (Max 4000 characters)
```text
Tired of losing hours to endless doomscrolling on short-form videos? DoomsBlocker is your ultimate digital wellbeing companion, built to reclaim your attention span, improve study focus, and protect family screen time.

━━━━━━━━━━━━━━━━━━━━━━━━━━
🛡️ THREE POWERFUL FOCUS MODES
━━━━━━━━━━━━━━━━━━━━━━━━━━

1. 🎯 ADULT FOCUS MODE (UNIFIED SHORT-FORM LIMITER)
• Say goodbye to vertical doomscrolling! Set a daily time limit for short-form feeds (YouTube Shorts & Instagram Reels).
• When your limit expires, short-form feeds are smoothly locked for your cooldown period.
• Long-Form Exemption: Watch educational lectures, tutorials, news, podcasts, and study videos without interruption. Educational long-form content is 100% permitted!
• Block Distracting Channels: Completely restrict specific YouTube channels from appearing in your feed.

2. 📚 LIBRARY STUDY ZONE (PIN-FREE QR GOAL LOCK)
• Designed specifically for students and library goers.
• Scan the Entrance QR poster at your library desk or study hall to pick your goal (from 15 min to 24 hours).
• Distraction Lockdown: Instagram, games, and distracting apps are instantly locked until your timer expires.
• 100% PIN-Free for Students: Zero passwords needed. Scan the Exit QR poster when leaving the study hall to release focus.

3. 👶 NEPHEW GUARD MODE (PARENTAL PROTECTION)
• Strict child mode for YouTube and gaming.
• Sets hard daily limits on marked mobile games.
• Completely locks YouTube when limits are reached.
• Protected by a custom 4-digit Security PIN so children cannot alter settings or bypass limits.

━━━━━━━━━━━━━━━━━━━━━━━━━━
✨ PREMIUM FEATURES
━━━━━━━━━━━━━━━━━━━━━━━━━━
• Google Pay-Style Security: Unlocks settings with a session PIN that automatically re-locks after 1 minute of background inactivity.
• Smooth Lock Screen: Gentle 5-second countdown popup before returning to the Home Screen—no abrupt screen glitches.
• Dynamic Status Bar Notification: Clear visual icons showing whether focus shield is active or locked.
• 100% Offline & Private: No sign-up, no cloud servers, no ads, and zero data tracking. Your habits stay on your device.

Take control of your digital wellbeing today with DoomsBlocker!
```

### Category & Tags
* **Application Category**: `Tools` or `Productivity`
* **Tags**: `Digital Wellbeing`, `Parental Control`, `Screen Time`, `Study`, `Productivity`

---

## 3. How to Run the 14-Day Closed Testing (20 Testers)

For new personal developer accounts, Google Play requires **20 testers opted in for 14 continuous days** before production release:

1. **Upload the Bundle**:
   * In Play Console, go to **Testing $\rightarrow$ Closed testing**.
   * Create a new track (e.g. `Closed Alpha`).
   * Upload `build/app/outputs/bundle/release/app-release.aab`.
2. **Create Email List of 20 Testers**:
   * Click **Testers** tab $\rightarrow$ Create email list $\rightarrow$ Enter 20 Google account email addresses of friends, students, or family.
3. **Send Opt-In Link**:
   * Copy the "Join on Android" or "Join on Web" opt-in link and share it with your 20 testers.
   * Ensure all 20 testers click "Accept Invite", install the app from Google Play, and keep it installed for 14 continuous days.
4. **Apply for Production**:
   * On Day 15, the "Apply for Production" button will activate in your Play Console dashboard.
   * Google will ask a few simple questions about your test feedback, and approve your app for general public release!
