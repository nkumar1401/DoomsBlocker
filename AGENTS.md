# DoomsBlocker — Agent Specification & Operating Constitution

> **For all AI Coding Agents (Antigravity, Cursor, Claude Code, Copilot, Windsurf):**
> This repository strictly follows **Spec-Driven Development (SDD)** as outlined by DeepLearning.AI & JetBrains.
> Ad-hoc "vibe coding" without consulting specifications is strictly prohibited. Every agent session must follow the workflow and invariants defined below.

---

## 1. The SDD Operational Loop (Plan $\rightarrow$ Implement $\rightarrow$ Verify)

Whenever you receive a task or bug fix request:

1. **Step 1: Consult the Constitution (`SPECIFICATIONS.md`)**
   - Read `SPECIFICATIONS.md` before writing or modifying any code.
   - Identify which specifications, state machines, or invariants are touched by the request.
   - If a new feature is requested, formalize its specification and acceptance criteria in `SPECIFICATIONS.md` first.

2. **Step 2: Scoped Implementation**
   - Make targeted, high-precision code changes.
   - Never remove or compromise existing safeguards (e.g., system UI package filtering, 30-level AST traversal, debounce guards).
   - Preserve dynamic configuration: all rules, timers, and limits must be read from SharedPreferences / NativeBridge. Never hardcode thresholds.

3. **Step 3: Automated Spec Driver Execution**
   - Run the automated test driver:
     ```bash
     flutter test test/spec_driver_test.dart
     ```
   - If tests fail, diagnose and fix the regression before presenting the solution to the user.
   - Add new test cases to `test/spec_driver_test.dart` whenever new rules, parsing logic, or state transitions are introduced.

---

## 2. Immutable Architecture Invariants

Any code change that violates these invariants is considered a build-breaking defect:

### Invariant 1: System UI Event Immunity
* The accessibility service must ignore `com.android.systemui`, keyboards (`com.google.android.inputmethod.latin`), volume sliders, and notification shades.
* Overlay events must **never** overwrite `activePackage` or reset `isInsideShorts = false`.

### Invariant 2: YouTube Long-Form Educational Content Exemption
* In **Adult Focus Mode** and **Library Study Zone**, long-form YouTube videos (lectures, tutorials, news, current affairs) are **100% permitted**.
* Only the vertical short-form player (`reel`, `shorts_player`, `shorts_container`, Remix) is subject to scroll-time limits and lockout ejects.

### Invariant 3: Library Study Zone State Integrity
* **Strict Check-In Before Check-Out**: Scanning an Exit QR while `isStudyZoneActive == false` must trigger the `Not Checked In` warning dialog with a button to scan the Entrance poster. It must **never** execute checkout.
* **Scan Entrance While Active**: Must inform the user that their study session is already active.
* **Distraction Lockdown**: Instagram, Snapchat, TikTok, Facebook, Twitter, Reddit, and marked games are immediately blocked during Study Zone.
* **No PIN Bypass in Study Zone**: PIN override is hidden; only natural timer expiry or Exit QR scan can release focus.

### Invariant 4: Smooth Lock Overlay & Debounce
* Lock activity launches must be debounced by **2.5 seconds** to prevent duplicate activity starts.
* `OverlayLockActivity.onBackPressed()` must enforce a **1.5-second immunity guard** against trailing accessibility back-actions to guarantee the smooth 5-second countdown popup (`5s -> 4s -> 3s...`) is fully visible before auto-dismissing to the Home Screen.
* Never call `GLOBAL_ACTION_BACK` at the same instant as `OverlayLockActivity.start(...)`.

### Invariant 5: Viewfinder Hardware Acceleration
* QR Scanner viewfinders must use `CustomPainter` with `PathOperation.difference` for transparent cutouts. Never use `ColorFiltered` with `BlendMode.srcOut` which glitches to a solid red box on modern Android GPU renderers.

---

## 3. Key File Map & Responsibilities

| File Path | Component | Responsibility |
|---|---|---|
| `SPECIFICATIONS.md` | Single Source of Truth | Master system specifications, state machines, and rules. |
| `test/spec_driver_test.dart` | Spec Driver Test Suite | Automated verification of QR parsing, state transitions, timers, and progress. |
| `android/.../DoomsAccessibilityService.kt` | Accessibility Engine | Scoped view hierarchy detection, 30-level traversal, active second counting, overlay launches. |
| `android/.../AppMonitorForegroundService.kt` | Background Monitor | UsageStats enforcement, fallback monitoring, dynamic persistent notification updates. |
| `android/.../OverlayLockActivity.kt` | Fullscreen Lock Overlay | Countdown timer, PIN override, study zone lock screen, smooth auto-dismiss. |
| `lib/screens/study_zone_screen.dart` | Study Zone UI & Controller | Goal picker modal (presets to 12h, custom to 24h), state validation, poster generation & sharing. |
| `lib/screens/qr_scanner_screen.dart` | QR Scanner | Clean transparent camera viewfinder cutout, laser animation, QR parsing. |
| `lib/services/native_bridge.dart` | MethodChannel Bridge | Bi-directional communication between Flutter UI and native Kotlin services. |
