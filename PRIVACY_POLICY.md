# Privacy Policy for DoomsBlocker

**Last updated: October 27, 2026**

DoomsBlocker ("we", "our", or "the App") is committed to protecting your privacy. This Privacy Policy explains our practices regarding information handling and permissions utilized by the DoomsBlocker Android application.

---

### 1. Zero Data Collection Principle

**DoomsBlocker does NOT collect, store, transmit, sell, or share any personal data.** 

* **No Account Required**: You do not need to register an account, provide an email address, or log in to use the App.
* **No Cloud Telemetry or Tracking**: The App does not contain third-party analytics SDKs, advertising trackers, or telemetry libraries.
* **100% On-Device Execution**: All calculations, timers, rules, and restrictions operate entirely in local device memory and local encrypted Android storage (`SharedPreferences`).

---

### 2. Android Permissions & How They Are Used

To deliver digital wellbeing, screen-time limitation, and library focus locking, DoomsBlocker requests specific Android permissions. Each permission is used strictly on-device for its declared purpose:

#### A. Accessibility Service (`android.permission.BIND_ACCESSIBILITY_SERVICE`)
* **Purpose**: DoomsBlocker utilizes Android's Accessibility Service API strictly as a digital wellbeing tool to help users avoid addictive vertical video feeds (YouTube Shorts, Instagram Reels) and restrict specific blocked channels.
* **Scope**: 
  * The service inspects window events only within specified media packages to identify vertical short-form video players and channel titles.
  * System UI packages, keyboards, notification shades, and private messages are completely filtered and ignored.
* **Privacy Guarantee**: 
  * The Accessibility Service **does NOT** log, store, or transmit screen contents, typed text, passwords, or personal communications.
  * The service does not alter user inputs or perform unauthorized automated actions.

#### B. Display Over Other Apps (`android.permission.SYSTEM_ALERT_WINDOW`)
* **Purpose**: When a configured doomscrolling time limit expires, a restricted game limit is reached, or a study session distraction is opened, this permission allows DoomsBlocker to display a smooth, full-screen lock countdown overlay (`OverlayLockActivity`).
* **Privacy Guarantee**: The overlay is a local UI element that auto-dismisses to the Home Screen. It does not monitor other apps.

#### C. Usage Access (`android.permission.PACKAGE_USAGE_STATS`)
* **Purpose**: Allows DoomsBlocker to monitor daily screen-time spent on user-selected game packages to enforce parental limits.
* **Privacy Guarantee**: Statistics are read locally via Android's `UsageStatsManager` and are never shared or uploaded.

#### D. Camera (`android.permission.CAMERA`)
* **Purpose**: Used exclusively for the **Library Study Zone** feature to scan physical Entrance and Exit QR code posters pasted at study desks and library reception counters.
* **Privacy Guarantee**: Camera frames are processed strictly in real-time by the local QR scanner engine. No images, photos, or video recordings are ever captured, saved to disk, or transmitted over any network.

#### E. Foreground Service & Notifications (`android.permission.FOREGROUND_SERVICE_SPECIAL_USE`, `POST_NOTIFICATIONS`)
* **Purpose**: Maintains a lightweight foreground notification displaying active study timers or shorts countdown status and ensures timer accuracy when the screen is active.

---

### 3. Children's Privacy (Nephew Guard Mode)

DoomsBlocker includes a **Nephew Guard Mode** designed for parents and guardians to limit screen time on games and YouTube.
* We do not knowingly collect personal information from children under the age of 13.
* All child restriction settings (Parent Security PIN, game limits) are stored solely on the parent's physical device.

---

### 4. Data Security

Because no data is transferred off your device, your information is protected by Android’s sandboxed operating system environment. Your custom Security PIN is stored in private Android app storage.

---

### 5. Changes to This Privacy Policy

We may update this Privacy Policy from time to time. Any changes will be reflected with an updated "Last updated" date at the top of this document.

---

### 6. Contact Us

If you have any questions or feedback regarding this Privacy Policy or DoomsBlocker, please contact us at:

* **Developer Email**: support@doomsblocker.app *(or your developer contact email)*
* **Repository**: https://github.com/Nkumar1401/DoomsBlocker
