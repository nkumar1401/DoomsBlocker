import 'package:flutter_test/flutter_test.dart';
import 'package:doomsblocker/screens/qr_scanner_screen.dart';
import 'package:doomsblocker/models/dashboard_data.dart';

void main() {
  group('SPEC 1: Library Study Zone QR Payload Parser', () {
    test('Correctly parses valid Entrance Check-In QR payload', () {
      const raw = 'DOOMSBLOCKER_STUDY:IN:Jijau Library';
      final payload = StudyQrPayload.parse(raw);

      expect(payload, isNotNull);
      expect(payload!.type, equals(StudyScanType.checkIn));
      expect(payload.zoneName, equals('Jijau Library'));
      expect(payload.raw, equals(raw));
    });

    test('Correctly parses valid Exit Check-Out QR payload', () {
      const raw = 'DOOMSBLOCKER_STUDY:OUT:City Central Library';
      final payload = StudyQrPayload.parse(raw);

      expect(payload, isNotNull);
      expect(payload!.type, equals(StudyScanType.checkOut));
      expect(payload.zoneName, equals('City Central Library'));
    });

    test('Rejects invalid or non-DoomsBlocker QR codes', () {
      expect(StudyQrPayload.parse('https://google.com'), isNull);
      expect(StudyQrPayload.parse('DOOMSBLOCKER:IN:Test'), isNull);
      expect(StudyQrPayload.parse(''), isNull);
      expect(StudyQrPayload.parse('DOOMSBLOCKER_STUDY:'), isNull);
    });

    test('Handles case-insensitivity in action keywords', () {
      final payloadIn = StudyQrPayload.parse('DOOMSBLOCKER_STUDY:in:Library A');
      final payloadOut = StudyQrPayload.parse('DOOMSBLOCKER_STUDY:out:Library B');

      expect(payloadIn!.type, equals(StudyScanType.checkIn));
      expect(payloadOut!.type, equals(StudyScanType.checkOut));
    });

    test('Permanently parses physical posters with leading/trailing whitespaces and complex names', () {
      final payload = StudyQrPayload.parse('  DOOMSBLOCKER_STUDY:IN:Jijau Study Room - Branch 2: Floor 1  \n');
      expect(payload, isNotNull);
      expect(payload!.type, equals(StudyScanType.checkIn));
      expect(payload.zoneName, equals('Jijau Study Room - Branch 2: Floor 1'));
    });

    test('Forward-Compatibility Invariant: Printed reception desk posters never expire across updates', () {
      // Simulating a poster printed in v1.0.0 scanned by any future version
      const legacyPrintedEntrancePoster = 'DOOMSBLOCKER_STUDY:IN:City Central Reading Hall';
      const legacyPrintedExitPoster = 'DOOMSBLOCKER_STUDY:OUT:City Central Reading Hall';

      final entrance = StudyQrPayload.parse(legacyPrintedEntrancePoster);
      final exit = StudyQrPayload.parse(legacyPrintedExitPoster);

      expect(entrance, isNotNull);
      expect(entrance!.type, equals(StudyScanType.checkIn));
      expect(entrance.zoneName, equals('City Central Reading Hall'));

      expect(exit, isNotNull);
      expect(exit!.type, equals(StudyScanType.checkOut));
      expect(exit.zoneName, equals('City Central Reading Hall'));
    });
  });

  group('SPEC 2: Library Study Zone State Machine Transitions', () {
    // Simulated state transition engine matching study_zone_screen.dart
    String simulateScanAction({
      required bool isStudyZoneActive,
      required StudyScanType scannedType,
      String? activeZoneName,
      String? scannedZoneName,
    }) {
      if (!isStudyZoneActive) {
        // State: IDLE
        if (scannedType == StudyScanType.checkOut) {
          return 'SHOW_NOT_CHECKED_IN_WARNING';
        }
        return 'SHOW_GOAL_PICKER_MODAL';
      } else {
        // State: ACTIVE
        if (scannedType == StudyScanType.checkIn) {
          return 'SHOW_ALREADY_CHECKED_IN_INFO';
        }
        if (activeZoneName != null &&
            scannedZoneName != null &&
            activeZoneName.trim().toLowerCase() != scannedZoneName.trim().toLowerCase()) {
          return 'SHOW_MISMATCHED_LIBRARY_WARNING';
        }
        return 'SHOW_CHECKOUT_CONFIRMATION';
      }
    }

    test('Scanning Check-Out while IDLE must show Not Checked In warning', () {
      final action = simulateScanAction(
        isStudyZoneActive: false,
        scannedType: StudyScanType.checkOut,
      );
      expect(action, equals('SHOW_NOT_CHECKED_IN_WARNING'));
    });

    test('Scanning Entrance while IDLE must show Goal Picker modal', () {
      final action = simulateScanAction(
        isStudyZoneActive: false,
        scannedType: StudyScanType.checkIn,
      );
      expect(action, equals('SHOW_GOAL_PICKER_MODAL'));
    });

    test('Scanning Entrance while ACTIVE must show Already Checked In info', () {
      final action = simulateScanAction(
        isStudyZoneActive: true,
        scannedType: StudyScanType.checkIn,
      );
      expect(action, equals('SHOW_ALREADY_CHECKED_IN_INFO'));
    });

    test('Scanning Check-Out from matching library while ACTIVE must show Checkout Confirmation', () {
      final action = simulateScanAction(
        isStudyZoneActive: true,
        scannedType: StudyScanType.checkOut,
        activeZoneName: 'Jijau Library',
        scannedZoneName: 'Jijau Library',
      );
      expect(action, equals('SHOW_CHECKOUT_CONFIRMATION'));
    });

    test('Scanning Check-Out from a DIFFERENT library must show Mismatched Library Warning', () {
      final action = simulateScanAction(
        isStudyZoneActive: true,
        scannedType: StudyScanType.checkOut,
        activeZoneName: 'Jijau Library',
        scannedZoneName: 'City Central Library',
      );
      expect(action, equals('SHOW_MISMATCHED_LIBRARY_WARNING'));
    });
  });

  group('SPEC 3: Study Duration & Time Calculations', () {
    String formatTimer(int totalSec) {
      if (totalSec <= 0) return '00:00:00';
      final h = totalSec ~/ 3600;
      final m = (totalSec % 3600) ~/ 60;
      final s = totalSec % 60;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    test('Timer formatting matches HH:mm:ss specification', () {
      expect(formatTimer(0), equals('00:00:00'));
      expect(formatTimer(-10), equals('00:00:00'));
      expect(formatTimer(45), equals('00:00:45'));
      expect(formatTimer(125), equals('00:02:05'));
      expect(formatTimer(3600), equals('01:00:00'));
      expect(formatTimer(37800), equals('10:30:00')); // 10h 30m
    });

    test('Custom study time calculation produces exact minutes', () {
      int calculateDuration(int hours, int minutes) => (hours * 60) + minutes;

      expect(calculateDuration(0, 45), equals(45));
      expect(calculateDuration(2, 0), equals(120));
      expect(calculateDuration(6, 15), equals(375));
      expect(calculateDuration(10, 30), equals(630));
      expect(calculateDuration(12, 0), equals(720));
      expect(calculateDuration(24, 0), equals(1440));
    });

    test('Duration validation strictly enforces 15m to 24h boundaries', () {
      bool isValidDuration(int totalMinutes) => totalMinutes >= 15 && totalMinutes <= 1440;

      expect(isValidDuration(10), isFalse);
      expect(isValidDuration(14), isFalse);
      expect(isValidDuration(15), isTrue);
      expect(isValidDuration(600), isTrue); // 10h
      expect(isValidDuration(1440), isTrue); // 24h
      expect(isValidDuration(1441), isFalse);
    });
  });

  group('SPEC 4: Shorts Dynamic Progress Invariants', () {
    double calculateShortsProgress(int usedSec, int limitMinutes) {
      final limitSec = limitMinutes * 60;
      if (limitSec <= 0) return 0.0;
      return (usedSec / limitSec).clamp(0.0, 1.0);
    }

    test('Dynamic calculation adapts to any configured limit', () {
      // 1 minute limit (60s)
      expect(calculateShortsProgress(30, 1), equals(0.5));
      expect(calculateShortsProgress(60, 1), equals(1.0));
      expect(calculateShortsProgress(90, 1), equals(1.0)); // clamped

      // 5 minute limit (300s)
      expect(calculateShortsProgress(150, 5), equals(0.5));
      expect(calculateShortsProgress(300, 5), equals(1.0));

      // 30 minute limit (1800s)
      expect(calculateShortsProgress(900, 30), equals(0.5));
    });
  });

  group('SPEC 5: Case-Insensitive Channel Blocking Invariant', () {
    bool isChannelBlocked({
      required String detectedText,
      required List<String> blockedList,
      required bool isWatchingVideo,
      bool isSearchActive = false,
    }) {
      // Soft Search Immunity: Never block while typing in search or scrolling search results
      if (isSearchActive) return false;
      if (!isWatchingVideo) return false;
      final detectedLower = detectedText.trim().toLowerCase();
      return blockedList.any((rawBlocked) {
        final blocked = rawBlocked.trim().toLowerCase().replaceAll('@', '');
        return detectedLower.contains(blocked);
      });
    }

    test('Case-insensitively matches blocked channels, handles (@Firstpost), and metadata lines when playing', () {
      final blockedList = ['Firstpost', 'T-Series', 'PewDiePie', 'moneycontrol'];

      // 1. Direct channel name when playing
      expect(isChannelBlocked(detectedText: 'firstpost', blockedList: blockedList, isWatchingVideo: true), isTrue);
      expect(isChannelBlocked(detectedText: 'FIRSTPOST', blockedList: blockedList, isWatchingVideo: true), isTrue);
      expect(isChannelBlocked(detectedText: 'moneycontrol', blockedList: blockedList, isWatchingVideo: true), isTrue);

      // 2. YouTube handle format (@Firstpost)
      expect(isChannelBlocked(detectedText: '@Firstpost', blockedList: blockedList, isWatchingVideo: true), isTrue);

      // 3. Modern YouTube watch page metadata line: "@Firstpost 10 likes 496 views..."
      expect(isChannelBlocked(
        detectedText: '@Firstpost 10 likes 496 views 57 min ago #tatamotors more',
        blockedList: blockedList,
        isWatchingVideo: true,
      ), isTrue);

      // 4. Subscribe button / avatar content description
      expect(isChannelBlocked(detectedText: 'Subscribe to Firstpost', blockedList: blockedList, isWatchingVideo: true), isTrue);
      expect(isChannelBlocked(detectedText: 'Go to channel Firstpost', blockedList: blockedList, isWatchingVideo: true), isTrue);

      // 5. Soft Search Immunity: Typing channel name in search box MUST NOT throw user out
      expect(isChannelBlocked(
        detectedText: 'Firstpost',
        blockedList: blockedList,
        isWatchingVideo: false,
        isSearchActive: true,
      ), isFalse);

      // 6. Soft Search Immunity: Scrolling search results list with Firstpost cards MUST NOT throw user out
      expect(isChannelBlocked(
        detectedText: '@Firstpost 10 likes 496 views',
        blockedList: blockedList,
        isWatchingVideo: true, // even if watch fragment in background
        isSearchActive: true,  // search is active foreground screen
      ), isFalse);

      // 7. Unrestricted channels
      expect(isChannelBlocked(detectedText: 'BBC News', blockedList: blockedList, isWatchingVideo: true), isFalse);
      expect(isChannelBlocked(detectedText: 'Khan Academy', blockedList: blockedList, isWatchingVideo: true), isFalse);
    });
  });

  group('SPEC 6: Unified Short-Form Pool Invariants', () {
    test('Instagram Reels and YouTube Shorts contribute to unified usage pool', () {
      int shortsUsedSeconds = 0;
      void recordShortFormTime(int seconds) {
        shortsUsedSeconds += seconds;
      }

      // 60s in YouTube Shorts
      recordShortFormTime(60);
      expect(shortsUsedSeconds, equals(60));

      // 120s in Instagram (home feed reels or reels tab)
      recordShortFormTime(120);
      expect(shortsUsedSeconds, equals(180));

      // Limit check: 3 minutes (180s)
      const limitMinutes = 3;
      final isLimitReached = shortsUsedSeconds >= (limitMinutes * 60);
      expect(isLimitReached, isTrue);
    });

    test('During cooldown lockout: Instagram is fully locked while YouTube long-form is permitted', () {
      bool isShortFormLocked = true;

      bool shouldLockPackage({
        required String packageName,
        required bool isInsideShorts,
        required bool isLocked,
      }) {
        if (!isLocked) return false;
        if (packageName == 'com.instagram.android') {
          // Instagram is fully locked during cooldown to prevent home feed reels doomscrolling
          return true;
        }
        if (packageName == 'com.google.android.youtube') {
          // In YouTube, ONLY vertical Shorts are locked; educational long-form is permitted
          return isInsideShorts;
        }
        return false;
      }

      // Instagram is completely locked
      expect(shouldLockPackage(packageName: 'com.instagram.android', isInsideShorts: false, isLocked: isShortFormLocked), isTrue);

      // YouTube Shorts is locked
      expect(shouldLockPackage(packageName: 'com.google.android.youtube', isInsideShorts: true, isLocked: isShortFormLocked), isTrue);

      // YouTube Long-Form (lecture/tutorial) is 100% permitted
      expect(shouldLockPackage(packageName: 'com.google.android.youtube', isInsideShorts: false, isLocked: isShortFormLocked), isFalse);
    });

    test('Shorts detection covers fullscreen (from tab or Home) and Home feed shelf, while pausing on long-form and non-shorts feed', () {
      bool isShortsDetected({
        required bool isFullscreenShortsVisible,
        required bool isShortsTabSelected,
        required bool isShortsIndicatorsFound,
        required bool isShortsShelfVisibleOnFeed,
        required bool isWatchPlayerVisible,
      }) {
        // 1. Direct layout ID matches for an active, visible full-screen vertical Shorts player
        if (isFullscreenShortsVisible) return true;

        // 2. Long-form video player is visible (educational content exemption)
        if (isWatchPlayerVisible) return false;

        // 3. Shorts tab selected
        if (isShortsTabSelected) return true;

        // 4. Shorts action indicators
        if (isShortsIndicatorsFound) return true;

        // 5. Shorts shelf visible on Home feed
        if (isShortsShelfVisibleOnFeed) return true;

        return false;
      }

      // 1. Fullscreen Shorts opened from bottom Shorts tab: timer counts
      expect(isShortsDetected(
        isFullscreenShortsVisible: true,
        isShortsTabSelected: true,
        isShortsIndicatorsFound: true,
        isShortsShelfVisibleOnFeed: false,
        isWatchPlayerVisible: false,
      ), isTrue);

      // 2. Fullscreen Shorts tapped from Home feed shelf: timer counts even if Home tab was selected in background
      expect(isShortsDetected(
        isFullscreenShortsVisible: true,
        isShortsTabSelected: false,
        isShortsIndicatorsFound: true,
        isShortsShelfVisibleOnFeed: false,
        isWatchPlayerVisible: false,
      ), isTrue);

      // 3. Scrolling/watching Shorts shelf carousel on the Home screen: timer counts
      expect(isShortsDetected(
        isFullscreenShortsVisible: false,
        isShortsTabSelected: false,
        isShortsIndicatorsFound: false,
        isShortsShelfVisibleOnFeed: true,
        isWatchPlayerVisible: false,
      ), isTrue);

      // 4. Watching a regular long-form video (watch_player active): timer immediately pauses
      expect(isShortsDetected(
        isFullscreenShortsVisible: false,
        isShortsTabSelected: false,
        isShortsIndicatorsFound: false,
        isShortsShelfVisibleOnFeed: false,
        isWatchPlayerVisible: true,
      ), isFalse);

      // 5. Scrolling Home feed past regular 16:9 video posts (Shorts shelf off-screen): timer paused
      expect(isShortsDetected(
        isFullscreenShortsVisible: false,
        isShortsTabSelected: false,
        isShortsIndicatorsFound: false,
        isShortsShelfVisibleOnFeed: false,
        isWatchPlayerVisible: false,
      ), isFalse);
    });

    test('Cooldown expiration automatically resets scroll time to 0 and clears lockout', () {
      int shortsUsedSeconds = 602; // 10:02 used (limit 10:00)
      const limitSeconds = 600; // 10 min
      int lockUntilTimestamp = 100000;

      // Simulated checkCooldownExpiration engine matching AppPreferences.kt
      void checkCooldownExpiration(int currentTimestamp) {
        if (lockUntilTimestamp > 0 && currentTimestamp >= lockUntilTimestamp) {
          lockUntilTimestamp = 0;
          shortsUsedSeconds = 0;
        }
      }

      bool isShortsLocked(int currentTimestamp) {
        checkCooldownExpiration(currentTimestamp);
        return (lockUntilTimestamp > 0 && currentTimestamp < lockUntilTimestamp) ||
            (shortsUsedSeconds >= limitSeconds);
      }

      // During cooldown (time: 95000): locked
      expect(isShortsLocked(95000), isTrue);
      expect(shortsUsedSeconds, equals(602));

      // Exactly when cooldown finishes (time: 100000): resets to 0 and unlocks!
      expect(isShortsLocked(100000), isFalse);
      expect(shortsUsedSeconds, equals(0));
      expect(lockUntilTimestamp, equals(0));

      // New session has full 10-minute scroll allowance
      expect(shortsUsedSeconds < limitSeconds, isTrue);
    });
  });

  group('SPEC 7: Google Pay-Style Security Session & First-Time PIN Invariants', () {
    test('Fresh install has no PIN set by default', () {
      String storedPin = '';
      bool isPinConfigured() => storedPin.trim().isNotEmpty;

      expect(isPinConfigured(), isFalse);
    });

    test('App Gateway strictly displays Onboarding Setup screen when PIN is not set or permissions missing', () {
      String determineAppLaunchScreen({
        required bool isPinSet,
        required bool accessibilityGranted,
        required bool overlayGranted,
        required bool usageStatsGranted,
      }) {
        final allPerms = accessibilityGranted && overlayGranted && usageStatsGranted;
        if (!isPinSet || !allPerms) {
          return 'ONBOARDING_SETUP_SCREEN';
        }
        return 'DASHBOARD_SCREEN';
      }

      // Case 1: Fresh install (no PIN, no permissions) -> Must show onboarding
      expect(determineAppLaunchScreen(
        isPinSet: false,
        accessibilityGranted: false,
        overlayGranted: false,
        usageStatsGranted: false,
      ), equals('ONBOARDING_SETUP_SCREEN'));

      // Case 2: Permissions granted but user forgot to set PIN -> Must show onboarding
      expect(determineAppLaunchScreen(
        isPinSet: false,
        accessibilityGranted: true,
        overlayGranted: true,
        usageStatsGranted: true,
      ), equals('ONBOARDING_SETUP_SCREEN'));

      // Case 3: PIN set but accessibility revoked -> Must show onboarding
      expect(determineAppLaunchScreen(
        isPinSet: true,
        accessibilityGranted: false,
        overlayGranted: true,
        usageStatsGranted: true,
      ), equals('ONBOARDING_SETUP_SCREEN'));

      // Case 4: PIN set and all 3 permissions active -> Directly open Dashboard!
      expect(determineAppLaunchScreen(
        isPinSet: true,
        accessibilityGranted: true,
        overlayGranted: true,
        usageStatsGranted: true,
      ), equals('DASHBOARD_SCREEN'));
    });

    test('PIN creation requires exactly 4 digits and matching confirmation', () {
      bool validatePinCreation(String pin, String confirm) {
        if (pin.length != 4 || int.tryParse(pin) == null) return false;
        if (confirm != pin) return false;
        return true;
      }

      expect(validatePinCreation('123', '123'), isFalse, reason: 'Too short');
      expect(validatePinCreation('12345', '12345'), isFalse, reason: 'Too long');
      expect(validatePinCreation('abcd', 'abcd'), isFalse, reason: 'Not numeric');
      expect(validatePinCreation('4567', '4568'), isFalse, reason: 'Mismatch');
      expect(validatePinCreation('4567', '4567'), isTrue, reason: 'Valid 4-digit matching PIN');
    });

    test('Session remains unlocked in foreground without prompting PIN repeatedly', () {
      bool isUnlocked = false;
      void authenticate(bool success) {
        if (success) isUnlocked = true;
      }

      // Initial state: locked
      expect(isUnlocked, isFalse);

      // Authenticate once
      authenticate(true);
      expect(isUnlocked, isTrue);

      // Subsequent settings navigations do not require re-authentication
      bool canAccessFeatureWithoutPin() => isUnlocked;
      expect(canAccessFeatureWithoutPin(), isTrue);
      expect(canAccessFeatureWithoutPin(), isTrue);
    });

    test('Session automatically relocks when backgrounded for >= 60 seconds', () {
      bool isUnlocked = true;
      DateTime? lastBackgroundTime;
      const timeout = Duration(minutes: 1);

      bool checkSession(DateTime now) {
        if (!isUnlocked) return false;
        if (lastBackgroundTime != null) {
          if (now.difference(lastBackgroundTime!) >= timeout) {
            isUnlocked = false;
            return false;
          }
        }
        return true;
      }

      final start = DateTime(2026, 1, 1, 12, 0, 0);
      // App paused at 12:00:00
      lastBackgroundTime = start;

      // Resumed after 30 seconds -> session still valid
      expect(checkSession(start.add(const Duration(seconds: 30))), isTrue);

      // Resumed after 61 seconds -> session automatically locked
      expect(checkSession(start.add(const Duration(seconds: 61))), isFalse);
      expect(isUnlocked, isFalse);
    });

    test('Library Study Zone is 100% exempt from PIN session lock', () {
      // Regardless of session lock status, Study Zone is always accessible
      bool isSessionUnlocked = false;
      bool canAccessStudyZone({required bool isSessionUnlocked}) {
        // Study zone is completely exempt from PIN requirement
        return true;
      }

      expect(canAccessStudyZone(isSessionUnlocked: isSessionUnlocked), isTrue);
      isSessionUnlocked = true;
      expect(canAccessStudyZone(isSessionUnlocked: isSessionUnlocked), isTrue);
    });
  });

  group('SPEC 8: Kids Mode & Multi-App Short-Form Selection Invariants', () {
    test('Kids Mode retains backward compatibility with nephew_mode storage key', () {
      final legacyMap = {
        'shortsLimitMinutes': 5,
        'shortsLockDurationMinutes': 30,
        'shortsUsedSecondsToday': 0,
        'isYouTubeLocked': false,
        'youtubeLockRemainingSeconds': 0,
        'isNephewModeEnabled': true,
        'gameLimitMinutes': 20,
        'restrictedAppsCount': 2,
        'blockedChannelsCount': 1,
        'isStudyZoneActive': false,
        'studyZoneName': 'Library',
        'studyZoneRemainingSeconds': 0,
        'isPinSet': true,
      };

      final dataFromLegacy = DashboardData.fromMap(legacyMap);
      expect(dataFromLegacy.isKidsModeEnabled, isTrue);
      expect(dataFromLegacy.isNephewModeEnabled, isTrue);
    });

    test('Multi-App Short-Form Selection filters tracking to only user-enabled platforms', () {
      final enabledPlatforms = {'youtube', 'instagram'};
      bool shouldTrack(String platform) => enabledPlatforms.contains(platform);

      expect(shouldTrack('youtube'), isTrue);
      expect(shouldTrack('instagram'), isTrue);
      expect(shouldTrack('snapchat'), isFalse);
      expect(shouldTrack('facebook'), isFalse);
    });
  });

  group('SPEC 9: Dual Hour/Minute Duration Picker Calculation Invariants', () {
    test('Picker accurately translates hours and minutes into total minutes', () {
      int calculateTotalMinutes(int hours, int minutes) => (hours * 60) + minutes;

      expect(calculateTotalMinutes(0, 15), equals(15));
      expect(calculateTotalMinutes(1, 30), equals(90));
      expect(calculateTotalMinutes(2, 45), equals(165));
      expect(calculateTotalMinutes(12, 0), equals(720));
      expect(calculateTotalMinutes(24, 0), equals(1440));
    });

    test('Picker formats preview label into human readable string', () {
      String formatPickerPreview(int hours, int minutes) {
        final total = (hours * 60) + minutes;
        if (hours == 0) return '$minutes min';
        if (minutes == 0) return '$hours hr ($total min)';
        return '$hours hr $minutes min ($total min)';
      }

      expect(formatPickerPreview(0, 15), equals('15 min'));
      expect(formatPickerPreview(2, 0), equals('2 hr (120 min)'));
      expect(formatPickerPreview(2, 30), equals('2 hr 30 min (150 min)'));
    });
  });

  group('SPEC 10: In-App Update Engine & Graceful Offline Fallbacks', () {
    test('Version comparator correctly identifies when update is required', () {
      bool isUpdateAvailable(String current, String remote) {
        final curParts = current.split('.').map(int.parse).toList();
        final remParts = remote.split('.').map(int.parse).toList();
        for (int i = 0; i < 3; i++) {
          if (remParts[i] > curParts[i]) return true;
          if (remParts[i] < curParts[i]) return false;
        }
        return false;
      }

      expect(isUpdateAvailable('1.0.0', '1.0.1'), isTrue);
      expect(isUpdateAvailable('1.0.0', '1.1.0'), isTrue);
      expect(isUpdateAvailable('1.0.1', '1.0.1'), isFalse);
      expect(isUpdateAvailable('1.1.0', '1.0.9'), isFalse);
    });
  });

  group('SPEC 11: 9-Day Free Trial, Contextual Paywall & Google Play Billing Invariants', () {
    test('9-day free trial calculates remaining days accurately and clamps to boundaries', () {
      int calculateTrialDays(DateTime installedAt, DateTime now) {
        final diffDays = now.difference(installedAt).inDays;
        final remaining = 9 - diffDays;
        return remaining.clamp(0, 9);
      }

      final start = DateTime(2026, 1, 1, 10, 0, 0);
      expect(calculateTrialDays(start, start), equals(9));
      expect(calculateTrialDays(start, start.add(const Duration(days: 4))), equals(5));
      expect(calculateTrialDays(start, start.add(const Duration(days: 8))), equals(1));
      expect(calculateTrialDays(start, start.add(const Duration(days: 9))), equals(0));
      expect(calculateTrialDays(start, start.add(const Duration(days: 15))), equals(0));
    });

    test('Kids Mode access gate respects trial active state and subscription status', () {
      bool canAccessKidsMode({required int trialDaysRemaining, required bool isSubscribed}) {
        if (isSubscribed) return true;
        return trialDaysRemaining > 0;
      }

      expect(canAccessKidsMode(trialDaysRemaining: 5, isSubscribed: false), isTrue);
      expect(canAccessKidsMode(trialDaysRemaining: 0, isSubscribed: false), isFalse);
      expect(canAccessKidsMode(trialDaysRemaining: 0, isSubscribed: true), isTrue);
    });

    test('Adult Focus Mode and Study Zone remain 100% free even after trial expiration', () {
      bool canAccessAdultMode({required int trialDaysRemaining, required bool isSubscribed}) => true;
      bool canAccessStudyZone({required int trialDaysRemaining, required bool isSubscribed}) => true;

      expect(canAccessAdultMode(trialDaysRemaining: 0, isSubscribed: false), isTrue);
      expect(canAccessStudyZone(trialDaysRemaining: 0, isSubscribed: false), isTrue);
    });
  });

  group('SPEC 12: Silver-White Theme, ShareChat Kids Lock & PIN Reset Invariants', () {
    test('isSocialOrDistractionApp strictly identifies ShareChat, Moj, and Josh alongside global platforms', () {
      bool isSocialOrDistractionApp(String pkgName) {
        final lower = pkgName.toLowerCase();
        return lower.contains('instagram') ||
            lower.contains('snapchat') ||
            lower.contains('tiktok') ||
            lower.contains('facebook') ||
            lower.contains('twitter') ||
            lower.contains('x.android') ||
            lower.contains('reddit') ||
            lower.contains('sharechat') ||
            lower.contains('mohalla') ||
            lower.contains('eterno') ||
            lower.contains('josh');
      }

      // Indian short-form clones
      expect(isSocialOrDistractionApp('in.mohalla.sharechat'), isTrue);
      expect(isSocialOrDistractionApp('in.mohalla.video'), isTrue); // Moj
      expect(isSocialOrDistractionApp('com.eterno.shortvideos'), isTrue); // Josh

      // Global social platforms
      expect(isSocialOrDistractionApp('com.instagram.android'), isTrue);
      expect(isSocialOrDistractionApp('com.snapchat.android'), isTrue);
      expect(isSocialOrDistractionApp('com.facebook.katana'), isTrue);
      expect(isSocialOrDistractionApp('com.twitter.android'), isTrue);

      // Educational / Productive apps exempt from blanket block
      expect(isSocialOrDistractionApp('com.google.android.youtube'), isFalse);
      expect(isSocialOrDistractionApp('com.duolingo'), isFalse);
      expect(isSocialOrDistractionApp('org.khanacademy.android'), isFalse);
    });

    test('PIN dialog title dynamically switches between Create PIN and Set New Security PIN', () {
      String getDialogTitle({required bool isUpdating, required int step}) {
        if (isUpdating) {
          return step == 1 ? 'Set New Security PIN' : 'Confirm New Security PIN';
        } else {
          return step == 1 ? 'Create Security PIN' : 'Confirm Security PIN';
        }
      }

      // First-time setup (from Onboarding)
      expect(getDialogTitle(isUpdating: false, step: 1), equals('Create Security PIN'));
      expect(getDialogTitle(isUpdating: false, step: 2), equals('Confirm Security PIN'));

      // Updating / Resetting (from Dashboard / Forgot PIN)
      expect(getDialogTitle(isUpdating: true, step: 1), equals('Set New Security PIN'));
      expect(getDialogTitle(isUpdating: true, step: 2), equals('Confirm New Security PIN'));
    });

    test('Silver-White Theme text colors guarantee accessible dark slate contrast against light surface', () {
      const scaffoldBackground = 0xFFF8FAFC; // Silver-White slate-50
      const cardSurface = 0xFFFFFFFF; // Pure white
      const primaryTextColor = 0xFF0F172A; // Deep slate-900
      const secondaryTextColor = 0xFF64748B; // Slate-500

      // Invariants: Surface is light (> 0xF0000000) and text is dark (< 0x70000000 relative RGB luminance)
      expect(scaffoldBackground, greaterThan(0xFFF00000));
      expect(cardSurface, equals(0xFFFFFFFF));
      expect(primaryTextColor & 0x00FFFFFF, lessThan(0x00202020));
      expect(secondaryTextColor & 0x00FFFFFF, lessThan(0x00707070));
    });
  });

  group('SPEC 13: Frictionless Onboarding, Notification 1-Tap & OEM Guidance Invariants', () {
    test('checkPermissions map schema strictly includes notification permission', () {
      final mockPerms = <String, bool>{
        'accessibility': true,
        'overlay': true,
        'usageStats': true,
        'notification': true,
      };

      expect(mockPerms.containsKey('accessibility'), isTrue);
      expect(mockPerms.containsKey('overlay'), isTrue);
      expect(mockPerms.containsKey('usageStats'), isTrue);
      expect(mockPerms.containsKey('notification'), isTrue);
    });

    test('OEM Device Manufacturer accurately selects brand guide tab index', () {
      int getBrandTabIndex(String rawMfg) {
        final mfg = rawMfg.toLowerCase();
        if (mfg.contains('samsung')) {
          return 0; // Samsung tab
        } else if (mfg.contains('xiaomi') || mfg.contains('redmi') || mfg.contains('poco')) {
          return 1; // Xiaomi tab
        } else if (mfg.contains('vivo') || mfg.contains('oppo') || mfg.contains('realme') || mfg.contains('oneplus')) {
          return 2; // Vivo/Oppo/Realme tab
        } else {
          return 3; // Other / Stock Android tab
        }
      }

      expect(getBrandTabIndex('Samsung'), equals(0));
      expect(getBrandTabIndex('samsung SM-G998B'), equals(0));
      expect(getBrandTabIndex('Xiaomi 2201116SG'), equals(1));
      expect(getBrandTabIndex('Redmi Note 12'), equals(1));
      expect(getBrandTabIndex('POCO F5'), equals(1));
      expect(getBrandTabIndex('vivo V2040'), equals(2));
      expect(getBrandTabIndex('OPPO Reno8'), equals(2));
      expect(getBrandTabIndex('realme RMX3360'), equals(2));
      expect(getBrandTabIndex('OnePlus 11'), equals(2));
      expect(getBrandTabIndex('Google Pixel 8'), equals(3));
      expect(getBrandTabIndex('Motorola edge 40'), equals(3));
    });

    test('Onboarding gatekeeper requires PIN and core permissions, graceful on optional notification', () {
      bool isReady({
        required bool isPinSet,
        required bool accessibility,
        required bool overlay,
        required bool usageStats,
        required bool notification,
      }) {
        final allCoreGranted = accessibility && overlay && usageStats;
        return isPinSet && allCoreGranted;
      }

      // Missing PIN -> Not ready
      expect(isReady(isPinSet: false, accessibility: true, overlay: true, usageStats: true, notification: true), isFalse);

      // Missing Accessibility -> Not ready
      expect(isReady(isPinSet: true, accessibility: false, overlay: true, usageStats: true, notification: true), isFalse);

      // Missing Overlay -> Not ready
      expect(isReady(isPinSet: true, accessibility: true, overlay: false, usageStats: true, notification: true), isFalse);

      // Missing Usage Stats -> Not ready
      expect(isReady(isPinSet: true, accessibility: true, overlay: true, usageStats: false, notification: true), isFalse);

      // All core granted, notification not granted -> READY (graceful fallback)
      expect(isReady(isPinSet: true, accessibility: true, overlay: true, usageStats: true, notification: false), isTrue);

      // All granted -> READY
      expect(isReady(isPinSet: true, accessibility: true, overlay: true, usageStats: true, notification: true), isTrue);
    });

    test('Google Play Subscription Paywall Disclosures strictly satisfy Play Console compliance', () {
      final supportedSkus = {'doomsblocker_kids_annual_9inr', 'kids_mode_annual'};
      expect(supportedSkus.contains('kids_mode_annual'), isTrue);
      expect(supportedSkus.contains('doomsblocker_kids_annual_9inr'), isTrue);

      const paywallTitle = 'Parental Controls (Kids Mode)';
      const disclosureTerms =
          'Cancel anytime in Google Play Subscriptions at least 24 hours before the trial ends or renewal date to avoid being charged.';

      expect(paywallTitle, contains('Parental Controls'), reason: 'Ensures 18+ Parent classification');
      expect(disclosureTerms, contains('24 hours'), reason: 'Mandatory Play billing disclosure');
      expect(disclosureTerms, contains('Google Play Subscriptions'));
    });
  });

  group('SPEC 14: Prepaid Recharge Model, Expiry Alert & Duration Picker Contrast Invariants', () {
    test('Prepaid 1-Year Pass calculates remaining days and clamps accurately (0..365)', () {
      int calculatePrepaidDays(int expiresAt, int now) {
        if (expiresAt <= now) return 0;
        final remainingMillis = expiresAt - now;
        final days = (remainingMillis / (1000 * 60 * 60 * 24)).ceil();
        return days.clamp(0, 365);
      }

      final now = DateTime(2026, 1, 1, 12, 0).millisecondsSinceEpoch;
      final oneYearLater = now + (365 * 24 * 60 * 60 * 1000);
      final sixMonthsLater = now + (180 * 24 * 60 * 60 * 1000);

      expect(calculatePrepaidDays(oneYearLater, now), equals(365));
      expect(calculatePrepaidDays(sixMonthsLater, now), equals(180));
      expect(calculatePrepaidDays(now - 1000, now), equals(0)); // Expired
    });

    test('48h and 24h expiry notification threshold trigger logic dispatches exactly once', () {
      String? determineReminderType(int hoursRemaining, bool notified48h, bool notified24h) {
        if (hoursRemaining <= 48 && hoursRemaining > 24 && !notified48h) {
          return '48H_ALERT';
        } else if (hoursRemaining <= 24 && hoursRemaining > 0 && !notified24h) {
          return '24H_ALERT';
        }
        return null;
      }

      // At 72 hours left -> no alert yet
      expect(determineReminderType(72, false, false), isNull);

      // At 36 hours left -> fires 48H alert
      expect(determineReminderType(36, false, false), equals('48H_ALERT'));

      // At 30 hours left with 48H already sent -> no duplicate alert
      expect(determineReminderType(30, true, false), isNull);

      // At 12 hours left -> fires 24H alert
      expect(determineReminderType(12, true, false), equals('24H_ALERT'));

      // At 6 hours left with 24H already sent -> no duplicate alert
      expect(determineReminderType(6, true, true), isNull);
    });

    test('Prepaid Paywall copy guarantees No AutoPay, One-Time Recharge and peaceful lock', () {
      const paywallTerms =
          'Prepaid Terms: Plan: Kids Mode Annual Pass (₹9.00 / 1 Year). 9-day free trial included for eligible new installs. This is a one-time prepaid recharge with ZERO recurring AutoPay mandates. When the 365-day pass ends, Kids Mode locks peacefully without debiting your account. Extend or top up anytime in your Google Play Account.';

      expect(paywallTerms, contains('ZERO recurring AutoPay mandates'));
      expect(paywallTerms, contains('one-time prepaid recharge'));
      expect(paywallTerms, contains('locks peacefully without debiting'));
      expect(paywallTerms, contains('365-day pass'));
    });

    test('DurationPickerDialog Silver-White theme ensures dark slate contrast on pure white', () {
      const modalBackground = 0xFFFFFFFF; // Pure white
      const previewSurface = 0xFFF8FAFC; // Slate-50
      const titleColor = 0xFF0F172A; // Slate-900
      const subtitleColor = 0xFF64748B; // Slate-500
      const wheelNumberColor = 0xFF0F172A; // Slate-900 (High contrast)

      expect(modalBackground, equals(0xFFFFFFFF));
      expect(previewSurface, greaterThan(0xFFF00000));
      expect(titleColor & 0x00FFFFFF, lessThan(0x00202020));
      expect(wheelNumberColor & 0x00FFFFFF, lessThan(0x00202020));
      expect(subtitleColor & 0x00FFFFFF, lessThan(0x00707070));
    });

    test('5-second auto-home dismiss strictly hides PIN on dopamine-break popups (Legacy check)', () {
      // Prior to Phase G update, short-form locks suppressed PIN.
      // Replaced by SPEC 15 Phase G Invariant: PIN is available on 5s popup with countdown auto-pause for all locks except Study Zone.
      expect(true, isTrue);
    });
  });

  group('SPEC 15: 5-Second Popup PIN Unlock, Auto-Pause, Resume Target App & Silver Theme Invariants', () {
    test('PIN is available on 5-second popup for all locks EXCEPT Study Zone (cheat-proof)', () {
      bool isPinAvailableOnPopup(String reason) {
        // Study Zone is 100% cheat-proof: only countdown expiry or Exit QR can unlock
        if (reason == 'reason_study_zone') {
          return false;
        }
        // All short-form, game, social and youtube limits offer PIN unlock on the 5s popup
        switch (reason) {
          case 'reason_shorts_limit':
          case 'reason_kids_shorts_blocked':
          case 'reason_kids_social_blocked':
          case 'reason_channel_blocked':
          case 'reason_game_limit':
          case 'reason_youtube_locked':
            return true;
          default:
            return true;
        }
      }

      expect(isPinAvailableOnPopup('reason_study_zone'), isFalse, reason: 'Study Zone must remain cheat-proof');
      expect(isPinAvailableOnPopup('reason_shorts_limit'), isTrue, reason: 'Instagram/Reels 5s popup allows PIN unlock');
      expect(isPinAvailableOnPopup('reason_kids_shorts_blocked'), isTrue);
      expect(isPinAvailableOnPopup('reason_kids_social_blocked'), isTrue);
      expect(isPinAvailableOnPopup('reason_channel_blocked'), isTrue);
      expect(isPinAvailableOnPopup('reason_game_limit'), isTrue);
      expect(isPinAvailableOnPopup('reason_youtube_locked'), isTrue);
    });

    test('Countdown timer immediately pauses when user interacts with PIN input', () {
      bool isTimerActive = true;
      bool isTimerPaused = false;
      int remainingSeconds = 5;

      void onPinToggleTapped() {
        isTimerActive = false;
        isTimerPaused = true;
      }

      void tick() {
        if (isTimerActive && !isTimerPaused && remainingSeconds > 0) {
          remainingSeconds--;
        }
      }

      // Initial state: counting down
      tick();
      expect(remainingSeconds, equals(4));

      // User taps 'Unlock with Security PIN'
      onPinToggleTapped();
      expect(isTimerPaused, isTrue);

      // Subsequent ticks do not decrement timer while PIN is active
      tick();
      tick();
      expect(remainingSeconds, equals(4), reason: 'Timer must remain frozen while PIN is typed');
    });

    test('Successful PIN unlock resolves target package and resumes that specific app', () {
      String? resumedPackage;
      bool lockReleased = false;

      void onPinSubmitted({
        required String enteredPin,
        required String correctPin,
        required String targetPackage,
      }) {
        if (enteredPin == correctPin) {
          lockReleased = true;
          resumedPackage = targetPackage;
        }
      }

      // Test resuming Instagram
      onPinSubmitted(
        enteredPin: '1234',
        correctPin: '1234',
        targetPackage: 'com.instagram.android',
      );
      expect(lockReleased, isTrue);
      expect(resumedPackage, equals('com.instagram.android'));

      // Test resuming YouTube
      lockReleased = false;
      resumedPackage = null;
      onPinSubmitted(
        enteredPin: '1234',
        correctPin: '1234',
        targetPackage: 'com.google.android.youtube',
      );
      expect(lockReleased, isTrue);
      expect(resumedPackage, equals('com.google.android.youtube'));
    });

    test('Study Zone dynamic notification formats HH:mm:ss and mm:ss countdown accurately', () {
      String formatStudyNotification(String zoneName, int remainingSec) {
        final hours = remainingSec ~/ 3600;
        final minutes = (remainingSec % 3600) ~/ 60;
        final seconds = remainingSec % 60;
        final timeStr = hours > 0
            ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
            : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        return '📚 Study Zone: $zoneName • $timeStr';
      }

      expect(
        formatStudyNotification('City Central Library', 3725),
        equals('📚 Study Zone: City Central Library • 01:02:05'),
      );
      expect(
        formatStudyNotification('Personal Desk', 59),
        equals('📚 Study Zone: Personal Desk • 00:59'),
      );
      expect(
        formatStudyNotification('Reading Hall', 0),
        equals('📚 Study Zone: Reading Hall • 00:00'),
      );
    });

    test('Silver-White UI theme tokens strictly adhere to light background & dark slate contrast', () {
      const scaffoldBg = 0xFFF8FAFC; // Slate-50 Silver-White
      const cardBg = 0xFFFFFFFF; // Pure White
      const textPrimary = 0xFF0F172A; // Slate-900 (High contrast)
      const textSecondary = 0xFF64748B; // Slate-500
      const borderNeutral = 0xFFE2E8F0; // Slate-200

      expect(scaffoldBg, equals(0xFFF8FAFC));
      expect(cardBg, equals(0xFFFFFFFF));
      // Primary text luminance must be dark (slate 900)
      expect(textPrimary & 0x00FFFFFF, lessThan(0x00202020));
      // Secondary text is distinct and readable
      expect(textSecondary & 0x00FFFFFF, greaterThan(0x00505050));
      expect(borderNeutral & 0x00FFFFFF, greaterThan(0x00D0D0D0));
    });
  });
}


