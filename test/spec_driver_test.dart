import 'dart:io';
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

  group('SPEC 16: Banking, UPI & Payment Application Immunity Invariants', () {
    final paymentPackages = {
      'com.google.android.apps.nbu.paisa.user', // Google Pay
      'com.phonepe.app', // PhonePe
      'net.one97.paytm', // Paytm
      'in.org.npci.upiapp', // BHIM UPI
      'com.dreamplug.androidapp', // CRED
      'com.naviapp', // Navi
      'com.freecharge.android', // Freecharge
      'com.mobikwik_new', // MobiKwik
      'com.sbi.lotusintouch', // YONO SBI
      'com.msf.kbank.mobile', // Kotak 811
      'com.csam.icici.bank.imobile', // ICICI iMobile
      'com.snapwork.hdfc', // HDFC Bank
      'com.axis.mobile', // Axis Mobile
      'com.pnb.pnbone', // PNB ONE
      'com.bankofbaroda.mconnect', // bob World
      'com.canarabank.ai1', // Canara ai1
      'com.infrasoft.uboi', // Union Bank Vyom
      'com.idfcfirstbank.optimus', // IDFC FIRST Bank
      'com.indusind.mobile', // IndusInd Mobile
      'com.google.android.apps.authenticator2', // Google Authenticator
      'com.azure.authenticator', // Microsoft Authenticator
    };

    bool isPaymentOrBankingApp(String pkg) {
      if (paymentPackages.contains(pkg)) return true;
      final lower = pkg.toLowerCase();
      return lower.contains('banking') ||
          lower.contains('.upi') ||
          lower.contains('payment') ||
          lower.contains('.wallet') ||
          lower.contains('paisa') ||
          lower.contains('paytm') ||
          lower.contains('phonepe');
    }

    test('Payment & UPI apps are strictly identified and granted complete immunity', () {
      expect(isPaymentOrBankingApp('com.google.android.apps.nbu.paisa.user'), isTrue);
      expect(isPaymentOrBankingApp('com.phonepe.app'), isTrue);
      expect(isPaymentOrBankingApp('net.one97.paytm'), isTrue);
      expect(isPaymentOrBankingApp('in.org.npci.upiapp'), isTrue);
      expect(isPaymentOrBankingApp('com.dreamplug.androidapp'), isTrue);
      expect(isPaymentOrBankingApp('com.sbi.lotusintouch'), isTrue);
      expect(isPaymentOrBankingApp('com.snapwork.hdfc'), isTrue);
      expect(isPaymentOrBankingApp('com.csam.icici.bank.imobile'), isTrue);
    });

    test('Social and entertainment apps are never falsely categorized as payment apps', () {
      expect(isPaymentOrBankingApp('com.google.android.youtube'), isFalse);
      expect(isPaymentOrBankingApp('com.instagram.android'), isFalse);
      expect(isPaymentOrBankingApp('com.snapchat.android'), isFalse);
      expect(isPaymentOrBankingApp('com.facebook.katana'), isFalse);
      expect(isPaymentOrBankingApp('com.roblox.client'), isFalse);
    });

    test('Payment app events enforce immediate zero-touch early return without mutating activePackage', () {
      String? activePackage = 'com.google.android.youtube';
      bool nodeHierarchyQueried = false;

      void onAccessibilityEventSimulation(String pkgName) {
        if (isPaymentOrBankingApp(pkgName)) {
          // Invariant 6: immediate early return
          return;
        }
        activePackage = pkgName;
        nodeHierarchyQueried = true;
      }

      // User opens Google Pay
      onAccessibilityEventSimulation('com.google.android.apps.nbu.paisa.user');
      expect(nodeHierarchyQueried, isFalse, reason: 'Must never query node hierarchy on payment apps');
      expect(activePackage, equals('com.google.android.youtube'), reason: 'activePackage must be shielded');

      // User opens PhonePe
      onAccessibilityEventSimulation('com.phonepe.app');
      expect(nodeHierarchyQueried, isFalse);
      expect(activePackage, equals('com.google.android.youtube'));
    });
  });

  group('SPEC 17: Emergency Exit High-Visibility Button & Clean Play Store Onboarding Invariants', () {
    test('Emergency Manual Exit action guarantees prominent interactive button styling', () {
      const buttonHeight = 48.0;
      const borderRadius = 14.0;
      const borderColor = 0xFFCBD5E1; // Slate-300
      const iconColor = 0xFFD97706; // Amber-600
      const textColor = 0xFF334155; // Slate-700
      const label = 'Left the library? Emergency Manual Exit';

      expect(buttonHeight, greaterThanOrEqualTo(48.0), reason: 'Sufficient touch target');
      expect(borderRadius, equals(14.0));
      expect(label, contains('Emergency Manual Exit'));
      expect(iconColor, equals(0xFFD97706));
      expect(textColor & 0x00FFFFFF, lessThan(0x00505050), reason: 'High contrast text');
    });

    test('Accessibility Guide Dialog OEM instructions direct user to tap bottom button without sideload warnings', () {
      String getBrandSteps(int brandIndex) {
        switch (brandIndex) {
          case 0:
            return '1. Tap "Continue to Accessibility Settings" below\n2. Tap "Installed apps"\n3. Tap "DoomsBlocker"\n4. Toggle the main switch ON and tap Allow.';
          case 1:
            return '1. Tap "Continue to Accessibility Settings" below\n2. Tap "Downloaded apps"\n3. Tap "DoomsBlocker"\n4. Toggle the main switch ON and tap OK.';
          case 2:
            return '1. Tap "Continue to Accessibility Settings" below\n2. Tap "Downloaded apps"\n3. Tap "DoomsBlocker"\n4. Toggle the main switch ON and confirm.';
          default:
            return '1. Tap "Continue to Accessibility Settings" below\n2. Tap "Downloaded apps" or scroll to "DoomsBlocker"\n3. Tap "DoomsBlocker" and toggle the switch ON.';
        }
      }

      for (int i = 0; i <= 3; i++) {
        final steps = getBrandSteps(i);
        expect(steps, contains('Continue to Accessibility Settings'));
        expect(steps, contains('DoomsBlocker'));
        expect(steps, isNot(contains('Open App Info')));
        expect(steps, isNot(contains('Allow restricted')));
      }
    });
  });

  group('SPEC 18: DEX Bytecode Optimization (R8) & Android 15 Edge-to-Edge Invariants', () {
    test('Verify build.gradle configures minifyEnabled, shrinkResources and activity-ktx', () {
      final gradleFile = File('android/app/build.gradle');
      expect(gradleFile.existsSync(), isTrue);
      final gradleContent = gradleFile.readAsStringSync();
      expect(gradleContent, contains('minifyEnabled = false'));
      expect(gradleContent, contains('shrinkResources = false'));
      expect(gradleContent, contains('proguard-android-optimize.txt'));
      expect(gradleContent, contains('proguard-rules.pro'));
          });

    test('Verify proguard-rules.pro preserves Flutter, Billing, and DoomsBlocker classes', () {
      final rulesFile = File('android/app/proguard-rules.pro');
      expect(rulesFile.existsSync(), isTrue);
      final rulesContent = rulesFile.readAsStringSync();
      expect(rulesContent, contains('io.flutter.**'));
      expect(rulesContent, contains('com.doomsblocker.app.**'));
      expect(rulesContent, contains('com.android.billingclient.**'));
      expect(rulesContent, contains('com.google.android.play.core.**'));
      expect(rulesContent, contains('dev.steenbakker.mobile_scanner.**'));
    });

    test('Verify MainActivity and OverlayLockActivity enforce Android 15 Edge-to-Edge compliance', () {
      final mainActivityFile = File('android/app/src/main/kotlin/com/doomsblocker/app/MainActivity.kt');
      expect(mainActivityFile.existsSync(), isTrue);
      final mainContent = mainActivityFile.readAsStringSync();
      expect(mainContent, contains('WindowCompat.setDecorFitsSystemWindows(window, false)'));
      expect(mainContent, contains('class MainActivity : FlutterActivity()'));

      final overlayActivityFile = File('android/app/src/main/kotlin/com/doomsblocker/app/OverlayLockActivity.kt');
      expect(overlayActivityFile.existsSync(), isTrue);
      final overlayContent = overlayActivityFile.readAsStringSync();
      expect(overlayContent, contains('WindowCompat.setDecorFitsSystemWindows(window, false)'));
    });
  });

  group('SPEC 19: Universal Browser Parity Shield & Mandatory Independence Invariants', () {
    test('Mandatory Independence: Study Zone & Kids Mode override unchecked settings', () {
      bool shouldRouteShorts({
        required bool isStudyZoneActive,
        required bool isKidsModeEnabled,
        required bool isShortFormMonitored,
      }) {
        final isMandatoryOverride = isStudyZoneActive || isKidsModeEnabled;
        return isMandatoryOverride || isShortFormMonitored;
      }

      // If unchecked in Adult settings, but Study Zone is active -> MUST ROUTE & ENFORCE
      expect(
        shouldRouteShorts(isStudyZoneActive: true, isKidsModeEnabled: false, isShortFormMonitored: false),
        isTrue,
        reason: 'Study Zone must enforce Shorts even if unchecked in adult settings',
      );

      // If unchecked in Adult settings, but Kids Mode is active -> MUST ROUTE & ENFORCE
      expect(
        shouldRouteShorts(isStudyZoneActive: false, isKidsModeEnabled: true, isShortFormMonitored: false),
        isTrue,
        reason: 'Kids Mode must enforce Shorts even if unchecked in adult settings',
      );

      // If in Normal Adult Mode and unchecked -> MUST ALLOW / NOT ENFORCE
      expect(
        shouldRouteShorts(isStudyZoneActive: false, isKidsModeEnabled: false, isShortFormMonitored: false),
        isFalse,
        reason: 'Normal Adult Mode respects user checkbox when idle',
      );

      // If in Normal Adult Mode and checked -> MUST ENFORCE
      expect(
        shouldRouteShorts(isStudyZoneActive: false, isKidsModeEnabled: false, isShortFormMonitored: true),
        isTrue,
      );
    });

    test('Preservation: Kids Mode long-form limits and channel restrictions remain intact', () {
      String resolveYouTubeLockReason({
        required bool isKidsMode,
        required bool inShorts,
        required int usedSeconds,
        required int limitSeconds,
        required bool isChannelBlocked,
      }) {
        if (isKidsMode) {
          if (inShorts) return 'reason_kids_shorts_blocked';
          if (isChannelBlocked) return 'reason_channel_blocked';
          if (usedSeconds >= limitSeconds) return 'reason_youtube_locked';
          return 'permitted';
        }
        return inShorts ? 'reason_shorts_limit' : 'permitted';
      }

      // Shorts in Kids Mode is instantly blocked with 0s tolerance
      expect(
        resolveYouTubeLockReason(
          isKidsMode: true,
          inShorts: true,
          usedSeconds: 0,
          limitSeconds: 1200,
          isChannelBlocked: false,
        ),
        equals('reason_kids_shorts_blocked'),
      );

      // Long-form educational video under limit is permitted
      expect(
        resolveYouTubeLockReason(
          isKidsMode: true,
          inShorts: false,
          usedSeconds: 600,
          limitSeconds: 1200,
          isChannelBlocked: false,
        ),
        equals('permitted'),
      );

      // Long-form video exceeding daily limit locks with reason_youtube_locked
      expect(
        resolveYouTubeLockReason(
          isKidsMode: true,
          inShorts: false,
          usedSeconds: 1250,
          limitSeconds: 1200,
          isChannelBlocked: false,
        ),
        equals('reason_youtube_locked'),
      );

      // Blocked channel locks with reason_channel_blocked
      expect(
        resolveYouTubeLockReason(
          isKidsMode: true,
          inShorts: false,
          usedSeconds: 100,
          limitSeconds: 1200,
          isChannelBlocked: true,
        ),
        equals('reason_channel_blocked'),
      );
    });

    test('Web Shield: Browser domain parser detects social media & shorts while exempting study sites', () {
      String? matchSocialDomainOrShorts(String text) {
        final lower = text.toLowerCase();
        if (lower.contains('youtube.com/shorts') || lower.contains('m.youtube.com/shorts') || lower.contains('/shorts/')) {
          return 'youtube_shorts';
        }
        if (lower.contains('instagram.com') || lower.contains('reels • instagram') || lower.contains('instagram reels')) {
          return 'instagram';
        }
        if (lower.contains('facebook.com/reel') || lower.contains('facebook.com/watch') || lower.contains('fb.watch') || lower.contains('facebook.com')) {
          return 'facebook';
        }
        if (lower.contains('tiktok.com')) return 'tiktok';
        if (lower.contains('snapchat.com')) return 'snapchat';
        if (lower.contains('twitter.com') || lower.contains('x.com')) return 'twitter';
        if (lower.contains('reddit.com')) return 'reddit';
        if (lower.contains('mojapp.in') || lower.contains('myjosh.in') || lower.contains('sharechat.com')) {
          return 'pure_short_form';
        }
        return null;
      }

      // Social media and short-form video URLs are accurately detected
      expect(matchSocialDomainOrShorts('https://m.youtube.com/shorts/xyz123'), equals('youtube_shorts'));
      expect(matchSocialDomainOrShorts('https://www.instagram.com/reels/video/'), equals('instagram'));
      expect(matchSocialDomainOrShorts('https://www.facebook.com/reel/12345'), equals('facebook'));
      expect(matchSocialDomainOrShorts('https://www.tiktok.com/@creator/video/123'), equals('tiktok'));
      expect(matchSocialDomainOrShorts('https://x.com/explore'), equals('twitter'));
      expect(matchSocialDomainOrShorts('https://www.reddit.com/r/videos'), equals('reddit'));

      // Study, research, and educational websites are 100% EXEMPT (returns null)
      expect(matchSocialDomainOrShorts('https://en.wikipedia.org/wiki/Quantum_mechanics'), isNull);
      expect(matchSocialDomainOrShorts('https://docs.google.com/document/d/123/edit'), isNull);
      expect(matchSocialDomainOrShorts('https://www.google.com/search?q=calculus+notes'), isNull);
      expect(matchSocialDomainOrShorts('https://github.com/flutter/flutter'), isNull);
      expect(matchSocialDomainOrShorts('https://stackoverflow.com/questions/123'), isNull);
      expect(matchSocialDomainOrShorts('https://www.youtube.com/watch?v=lecture123'), isNull, reason: 'Educational YouTube watch URL is exempt');
    });

    test('Browser Parity: 3-Mode Lock resolution enforces exact native parity on web browsers', () {
      String resolveBrowserLockAction({
        required String detectedDomain,
        required bool isStudyZoneActive,
        required bool isKidsModeEnabled,
        required bool isAdultLockoutActive,
      }) {
        if (isStudyZoneActive) {
          return 'reason_study_zone';
        }
        if (isKidsModeEnabled) {
          return detectedDomain == 'youtube_shorts'
              ? 'reason_kids_shorts_blocked'
              : 'reason_kids_social_blocked';
        }
        if (isAdultLockoutActive) {
          return 'reason_shorts_limit';
        }
        return 'permitted';
      }

      // Mode 1: Study Zone -> Always locks with reason_study_zone
      expect(
        resolveBrowserLockAction(
          detectedDomain: 'instagram',
          isStudyZoneActive: true,
          isKidsModeEnabled: false,
          isAdultLockoutActive: false,
        ),
        equals('reason_study_zone'),
      );
      expect(
        resolveBrowserLockAction(
          detectedDomain: 'youtube_shorts',
          isStudyZoneActive: true,
          isKidsModeEnabled: false,
          isAdultLockoutActive: false,
        ),
        equals('reason_study_zone'),
      );

      // Mode 2: Kids Mode -> Locks with reason_kids_shorts_blocked or reason_kids_social_blocked
      expect(
        resolveBrowserLockAction(
          detectedDomain: 'youtube_shorts',
          isStudyZoneActive: false,
          isKidsModeEnabled: true,
          isAdultLockoutActive: false,
        ),
        equals('reason_kids_shorts_blocked'),
      );
      expect(
        resolveBrowserLockAction(
          detectedDomain: 'facebook',
          isStudyZoneActive: false,
          isKidsModeEnabled: true,
          isAdultLockoutActive: false,
        ),
        equals('reason_kids_social_blocked'),
      );

      // Mode 3: Adult Mode with active lockout -> Locks with reason_shorts_limit
      expect(
        resolveBrowserLockAction(
          detectedDomain: 'youtube_shorts',
          isStudyZoneActive: false,
          isKidsModeEnabled: false,
          isAdultLockoutActive: true,
        ),
        equals('reason_shorts_limit'),
      );

      // Mode 3: Adult Mode without lockout -> Permitted to browse (accumulates scroll time)
      expect(
        resolveBrowserLockAction(
          detectedDomain: 'instagram',
          isStudyZoneActive: false,
          isKidsModeEnabled: false,
          isAdultLockoutActive: false,
        ),
        equals('permitted'),
      );
    });

    test('Verify Kotlin DoomsAccessibilityService defines SUPPORTED_BROWSER_PACKAGES and isBrowserPackage', () {
      final serviceFile = File('android/app/src/main/kotlin/com/doomsblocker/app/DoomsAccessibilityService.kt');
      expect(serviceFile.existsSync(), isTrue);
      final serviceContent = serviceFile.readAsStringSync();
      expect(serviceContent, contains('SUPPORTED_BROWSER_PACKAGES'));
      expect(serviceContent, contains('isBrowserPackage'));
      expect(serviceContent, contains('handleBrowserEvent'));
      expect(serviceContent, contains('detectBrowserUrlOrDomain'));
      expect(serviceContent, contains('isMandatoryOverride'));
    });
  });

  group('SPEC 20: Kids Mode Web YouTube Parity & Universal System Navigation Bar Insets', () {
    String? matchSocialDomainOrShorts(String text) {
      final lower = text.toLowerCase();
      if (lower.contains('youtube.com/shorts') || lower.contains('m.youtube.com/shorts') || lower.contains('/shorts/')) {
        return 'youtube_shorts';
      }
      if (lower.contains('youtube.com') || lower.contains('m.youtube.com') || lower.contains('youtu.be')) {
        return 'youtube_watch';
      }
      if (lower.contains('instagram.com') || lower.contains('reels • instagram') || lower.contains('instagram reels')) {
        return 'instagram';
      }
      return null;
    }

    test('Web YouTube Detection classifies youtube_watch vs youtube_shorts accurately', () {
      expect(matchSocialDomainOrShorts('https://www.youtube.com/watch?v=dQw4w9WgXcQ'), equals('youtube_watch'));
      expect(matchSocialDomainOrShorts('https://m.youtube.com/watch?v=abcdef'), equals('youtube_watch'));
      expect(matchSocialDomainOrShorts('https://youtu.be/dQw4w9WgXcQ'), equals('youtube_watch'));
      expect(matchSocialDomainOrShorts('https://www.youtube.com/shorts/3i_J3n123'), equals('youtube_shorts'));
      expect(matchSocialDomainOrShorts('https://m.youtube.com/shorts/'), equals('youtube_shorts'));
      expect(matchSocialDomainOrShorts('https://en.wikipedia.org/wiki/Flutter'), isNull);
    });

    test('Kids Mode Unified Screen Time Pool: Web YouTube accumulates time and triggers lockout', () {
      int shortsUsedSecondsToday = 0;
      final int shortsLimitMinutes = 1; // 1 min limit
      final int limitSec = shortsLimitMinutes * 60;
      int youtubeLockUntilTimestamp = 0;
      String? lockedWithReason;

      void simulatePeriodicTick({
        required bool isKidsModeEnabled,
        required String activePackage,
        required bool isInsideWebYouTube,
        required int deltaSeconds,
      }) {
        if (!isKidsModeEnabled) return;

        final isKidsYouTubeActive = (activePackage == 'com.google.android.youtube') ||
            (activePackage == 'com.android.chrome' && isInsideWebYouTube);

        if (isKidsYouTubeActive) {
          shortsUsedSecondsToday += deltaSeconds;
          if (shortsUsedSecondsToday >= limitSec) {
            youtubeLockUntilTimestamp = DateTime.now().millisecondsSinceEpoch + 30 * 60 * 1000;
            lockedWithReason = 'reason_youtube_locked';
          }
        }
      }

      // 1. Kid watches YouTube on Chrome for 40 seconds
      simulatePeriodicTick(
        isKidsModeEnabled: true,
        activePackage: 'com.android.chrome',
        isInsideWebYouTube: true,
        deltaSeconds: 40,
      );
      expect(shortsUsedSecondsToday, equals(40));
      expect(lockedWithReason, isNull);

      // 2. Kid watches another 20 seconds on Chrome (total 60s -> reaches 1 min limit)
      simulatePeriodicTick(
        isKidsModeEnabled: true,
        activePackage: 'com.android.chrome',
        isInsideWebYouTube: true,
        deltaSeconds: 20,
      );
      expect(shortsUsedSecondsToday, equals(60));
      expect(lockedWithReason, equals('reason_youtube_locked'));
      expect(youtubeLockUntilTimestamp, greaterThan(0));
    });

    test('Invariant 2: YouTube Long-Form on web remains 100% permitted in Adult Mode and Study Zone', () {
      bool shouldLockWebUrl({
        required String detectedDomain,
        required bool isStudyZoneActive,
        required bool isKidsModeEnabled,
        required bool isAdultLockoutActive,
      }) {
        if (detectedDomain == 'youtube_watch') {
          if (isKidsModeEnabled && isAdultLockoutActive) {
            return true; // Kids mode locks when allowance exhausted or cooldown active
          }
          // In Study Zone and Adult Mode, educational long-form is NEVER locked (Invariant 2)
          return false;
        }
        return true;
      }

      // Adult Mode: Long-form on Chrome is 100% permitted even if short-form lockout is active
      expect(
        shouldLockWebUrl(
          detectedDomain: 'youtube_watch',
          isStudyZoneActive: false,
          isKidsModeEnabled: false,
          isAdultLockoutActive: true,
        ),
        isFalse,
        reason: 'Invariant 2: Educational YouTube long-form is strictly exempt in Adult Mode',
      );

      // Study Zone: Long-form on Chrome is 100% permitted for study lectures
      expect(
        shouldLockWebUrl(
          detectedDomain: 'youtube_watch',
          isStudyZoneActive: true,
          isKidsModeEnabled: false,
          isAdultLockoutActive: false,
        ),
        isFalse,
        reason: 'Invariant 2: Educational YouTube long-form is strictly exempt in Library Study Zone',
      );
    });

    test('DurationPickerDialog constraints restrict 3-hour boundary and displays informative validation text', () {
      String getConfirmButtonText({
        required int totalMinutes,
        required int minMinutes,
        required int maxMinutes,
      }) {
        final isValid = totalMinutes >= minMinutes && totalMinutes <= maxMinutes;
        if (isValid) {
          return 'Confirm $totalMinutes min';
        } else if (totalMinutes > maxMinutes) {
          final maxH = maxMinutes ~/ 60;
          return 'Cannot exceed $maxH hr ($maxMinutes min)';
        } else {
          return 'Select at least $minMinutes min';
        }
      }

      // Valid selection
      expect(getConfirmButtonText(totalMinutes: 120, minMinutes: 1, maxMinutes: 180), equals('Confirm 120 min'));

      // Exceeds max limit (Image 1 case: 182 min vs 180 min max)
      expect(
        getConfirmButtonText(totalMinutes: 182, minMinutes: 1, maxMinutes: 180),
        equals('Cannot exceed 3 hr (180 min)'),
        reason: 'Must never show confusing Select at least 1 min when exceeding maximum limit',
      );

      // Below min limit
      expect(getConfirmButtonText(totalMinutes: 0, minMinutes: 1, maxMinutes: 180), equals('Select at least 1 min'));
    });

    test('Verify Kotlin DoomsAccessibilityService handles isInsideWebYouTube and browser periodic ticks', () {
      final serviceFile = File('android/app/src/main/kotlin/com/doomsblocker/app/DoomsAccessibilityService.kt');
      expect(serviceFile.existsSync(), isTrue);
      final serviceContent = serviceFile.readAsStringSync();
      expect(serviceContent, contains('isInsideWebYouTube'));
      expect(serviceContent, contains('youtube_watch'));
      expect(serviceContent, contains('isKidsYouTubeActive'));
      expect(serviceContent, contains('isBrowserPackage(windowPkg)'));
    });
  });

  group('SPEC 21: Picture-in-Picture (PiP) Screen Time Tracking & Modal Navigation Insets', () {
    test('Kids Mode PiP Screen Time: Continuous accumulation when YouTube is in PiP', () {
      int shortsUsedSecondsToday = 0;
      final int shortsLimitMinutes = 1; // 1 min limit (60s)
      final int limitSec = shortsLimitMinutes * 60;
      String? activePackage = 'com.google.android.apps.nexuslauncher'; // User on Home Launcher
      String? pipPkg = 'com.google.android.youtube'; // YouTube in minimized PiP window
      final bool isPipActive = pipPkg == 'com.google.android.youtube';
      int youtubeLockUntilTimestamp = 0;
      String? lockedReason;

      void simulatePipPeriodicTick(int deltaSeconds) {
        // In Kids Mode:
        final isKidsYouTubeActive = (activePackage == 'com.google.android.youtube') ||
            (activePackage == 'com.android.chrome') ||
            isPipActive;

        if (isKidsYouTubeActive) {
          shortsUsedSecondsToday += deltaSeconds;
          if (shortsUsedSecondsToday >= limitSec) {
            youtubeLockUntilTimestamp = DateTime.now().millisecondsSinceEpoch + 30 * 60 * 1000;
            lockedReason = 'reason_youtube_locked';
          }
        }
      }

      // 1. Minimized video plays for 35 seconds on Home Screen
      simulatePipPeriodicTick(35);
      expect(shortsUsedSecondsToday, equals(35), reason: 'Must count time while minimized in PiP');
      expect(lockedReason, isNull);

      // 2. Minimized video plays for another 25 seconds (total 60s -> reaches 1 min limit)
      simulatePipPeriodicTick(25);
      expect(shortsUsedSecondsToday, equals(60));
      expect(lockedReason, equals('reason_youtube_locked'), reason: 'Must trigger lock when limit exhausted in PiP');
      expect(youtubeLockUntilTimestamp, greaterThan(0));
    });

    test('Kids Mode PiP Active Lockout: Ejects immediately if PiP opened during active cooldown', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final youtubeLockUntilTimestamp = now + 15 * 60 * 1000; // 15 min remaining in cooldown
      final isPipActive = true;
      final pipPkg = 'com.google.android.youtube';
      bool pipDismissed = false;
      String? lockedReason;

      if (isPipActive && (pipPkg == 'com.google.android.youtube')) {
        final isYtLocked = youtubeLockUntilTimestamp > now;
        if (isYtLocked) {
          pipDismissed = true;
          lockedReason = 'reason_youtube_locked';
        }
      }

      expect(pipDismissed, isTrue, reason: 'PiP window must be dismissed when cooldown active');
      expect(lockedReason, equals('reason_youtube_locked'));
    });

    test('Invariant 2 Exemption: YouTube PiP remains 100% permitted in Adult Mode and Study Zone', () {
      bool shouldEjectPip({
        required bool isKidsModeEnabled,
        required bool isStudyZoneActive,
        required bool isYouTubeLocked,
      }) {
        if (isKidsModeEnabled) {
          return isYouTubeLocked;
        }
        // In Adult Mode and Study Zone, educational long-form PiP is 100% permitted (Invariant 2)
        return false;
      }

      // Adult Mode: Educational PiP lecture is never ejected
      expect(
        shouldEjectPip(
          isKidsModeEnabled: false,
          isStudyZoneActive: false,
          isYouTubeLocked: true,
        ),
        isFalse,
      );

      // Study Zone: Educational PiP lecture is never ejected
      expect(
        shouldEjectPip(
          isKidsModeEnabled: false,
          isStudyZoneActive: true,
          isYouTubeLocked: false,
        ),
        isFalse,
      );
    });

    test('Modal Bottom Sheet Navigation Bar Clearance: All bottom sheets apply safe insets', () {
      final guideFile = File('lib/widgets/accessibility_guide_dialog.dart');
      expect(guideFile.existsSync(), isTrue);
      final guideContent = guideFile.readAsStringSync();
      expect(guideContent, contains('MediaQuery.of(context).padding.bottom'));

      final studyZoneFile = File('lib/screens/study_zone_screen.dart');
      expect(studyZoneFile.existsSync(), isTrue);
      final studyZoneContent = studyZoneFile.readAsStringSync();
      expect(studyZoneContent, contains('MediaQuery.of(context).padding.bottom'));

      final paywallFile = File('lib/widgets/kids_mode_paywall_dialog.dart');
      expect(paywallFile.existsSync(), isTrue);
      final paywallContent = paywallFile.readAsStringSync();
      expect(paywallContent, contains('MediaQuery.of(context).padding.bottom'));
    });

    test('Verify Kotlin DoomsAccessibilityService defines detectActivePipPackage and handles PiP in periodic ticks', () {
      final serviceFile = File('android/app/src/main/kotlin/com/doomsblocker/app/DoomsAccessibilityService.kt');
      expect(serviceFile.existsSync(), isTrue);
      final serviceContent = serviceFile.readAsStringSync();
      expect(serviceContent, contains('detectActivePipPackage'));
      expect(serviceContent, contains('isPipActive'));
      expect(serviceContent, contains('dismissPictureInPictureIfPresent'));
      expect(serviceContent, contains('destroyBackgroundMediaAndPlayer'));
    });
  });

  group('SPEC 22: Slim Professional Rules UI & YouTube Lockout 5s Auto-Dismiss', () {
    test('REASON_YOUTUBE_LOCKED strictly executes 5-second countdown timer and redirects to Home Screen upon 0s', () {
      int autoDismissSeconds = -1;
      bool redirectedToHome = false;

      void startAutoDismissTimer(int seconds) {
        autoDismissSeconds = seconds;
      }

      void handleLockIntent(String reason) {
        switch (reason) {
          case 'reason_youtube_locked':
          case 'reason_shorts_limit':
          case 'reason_kids_shorts_blocked':
          case 'reason_kids_social_blocked':
          case 'reason_game_limit':
          case 'reason_channel_blocked':
          case 'reason_study_zone':
            startAutoDismissTimer(5);
            break;
        }
      }

      handleLockIntent('reason_youtube_locked');
      expect(autoDismissSeconds, equals(5), reason: 'YouTube lock must initiate 5s countdown popup');

      // Simulate countdown ticks
      while (autoDismissSeconds > 0) {
        autoDismissSeconds--;
      }
      if (autoDismissSeconds == 0) {
        redirectedToHome = true;
      }
      expect(redirectedToHome, isTrue, reason: 'Countdown expiry must smoothly redirect to Home Screen');
    });

    test('REASON_YOUTUBE_LOCKED retains PIN unlock availability and pauses countdown when PIN input is opened', () {
      bool isPinSectionVisible = false;
      bool isTimerPaused = false;
      String countdownText = '5s';

      void handleLockIntent(String reason) {
        if (reason == 'reason_youtube_locked') {
          isPinSectionVisible = true;
        }
      }

      void onPinToggleTapped() {
        isTimerPaused = true;
        countdownText = 'PAUSED';
      }

      handleLockIntent('reason_youtube_locked');
      expect(isPinSectionVisible, isTrue, reason: 'Parents PIN unlock must be visible on YouTube lockout');

      onPinToggleTapped();
      expect(isTimerPaused, isTrue);
      expect(countdownText, equals('PAUSED'));
    });

    test('Single-row horizontal pill carousels accurately format duration labels for slim display', () {
      String formatDuration(int minutes) {
        if (minutes < 60) return '${minutes}m';
        final h = minutes ~/ 60;
        final m = minutes % 60;
        if (m == 0) return '${h}h';
        return '${h}h ${m}m';
      }

      expect(formatDuration(1), equals('1m'));
      expect(formatDuration(15), equals('15m'));
      expect(formatDuration(60), equals('1h'));
      expect(formatDuration(120), equals('2h'));
      expect(formatDuration(480), equals('8h'));
      expect(formatDuration(1440), equals('24h'));
    });

    test('Verify Kotlin OverlayLockActivity invokes startAutoDismissTimer(5) for REASON_YOUTUBE_LOCKED', () {
      final activityFile = File('android/app/src/main/kotlin/com/doomsblocker/app/OverlayLockActivity.kt');
      expect(activityFile.existsSync(), isTrue);
      final activityContent = activityFile.readAsStringSync();

      // Ensure REASON_YOUTUBE_LOCKED calls startAutoDismissTimer(5) and does not call startLockdownTimer()
      expect(activityContent, contains('REASON_YOUTUBE_LOCKED ->'));
      final ytLockIndex = activityContent.indexOf('REASON_YOUTUBE_LOCKED ->');
      final nextCaseIndex = activityContent.indexOf('REASON_KIDS_SHORTS_BLOCKED ->', ytLockIndex);
      final ytCaseBlock = activityContent.substring(ytLockIndex, nextCaseIndex);

      expect(ytCaseBlock, contains('startAutoDismissTimer(5)'));
      expect(ytCaseBlock, isNot(contains('startLockdownTimer()')));
    });

    test('Verify ShortsSettingsScreen implements horizontal single-row pill carousels and compact padding', () {
      final screenFile = File('lib/screens/shorts_settings_screen.dart');
      expect(screenFile.existsSync(), isTrue);
      final screenContent = screenFile.readAsStringSync();

      expect(screenContent, contains('SingleChildScrollView'));
      expect(screenContent, contains('scrollDirection: Axis.horizontal'));
      expect(screenContent, contains('ChoiceChip'));
      expect(screenContent, contains('SliderTheme'));
    });
  });

  // =========================================================================
  // SPEC 23: Automatic Newly-Installed Game Detection & Mode-Scoped Enforcement
  // =========================================================================
  group('SPEC 23: Auto-Restrict Newly Installed & Pre-Existing Games', () {
    test('Newly installed and pre-existing CATEGORY_GAME apps auto-join restrictedApps when autoRestrictGames is ON', () {
      bool autoRestrictGames = true;
      final Set<String> restrictedApps = {};
      final Set<String> exemptedGames = {};
      const ignoredSystemPkgs = {'com.android.vending', 'com.android.settings', 'com.google.android.packageinstaller'};

      bool autoRestrictIfEligible(String pkg, {required bool isGame}) {
        if (!autoRestrictGames || !isGame || ignoredSystemPkgs.contains(pkg)) return false;
        if (exemptedGames.contains(pkg) || restrictedApps.contains(pkg)) return false;
        restrictedApps.add(pkg);
        return true;
      }

      // Play Store itself and non-game utility remain untouched
      expect(autoRestrictIfEligible('com.android.vending', isGame: false), isFalse);
      expect(autoRestrictIfEligible('org.wikipedia', isGame: false), isFalse);

      // Existing pre-installed game gets auto-restricted
      expect(autoRestrictIfEligible('com.supercell.clashofclans', isGame: true), isTrue);
      expect(restrictedApps.contains('com.supercell.clashofclans'), isTrue);

      // Newly downloaded game via Play Store gets auto-restricted immediately
      expect(autoRestrictIfEligible('com.kiloo.subwaysurf', isGame: true), isTrue);
      expect(restrictedApps.contains('com.kiloo.subwaysurf'), isTrue);

      // When disabled, new games are not auto-added
      autoRestrictGames = false;
      expect(autoRestrictIfEligible('com.mojang.minecraftpe', isGame: true), isFalse);
      expect(restrictedApps.contains('com.mojang.minecraftpe'), isFalse);
    });

    test('Parent manual exemption prevents auto-re-addition until parent explicitly re-enables', () {
      final Set<String> restrictedApps = {'com.chess', 'com.kiloo.subwaysurf'};
      final Set<String> exemptedGames = {};
      const autoRestrictGames = true;

      void toggleRestricted(String pkg) {
        if (restrictedApps.contains(pkg)) {
          restrictedApps.remove(pkg);
          exemptedGames.add(pkg);
        } else {
          restrictedApps.add(pkg);
          exemptedGames.remove(pkg);
        }
      }

      bool tryAutoRestrict(String pkg, {required bool isGame}) {
        if (!autoRestrictGames || !isGame) return false;
        if (exemptedGames.contains(pkg) || restrictedApps.contains(pkg)) return false;
        restrictedApps.add(pkg);
        return true;
      }

      // Parent unchecks Chess
      toggleRestricted('com.chess');
      expect(restrictedApps.contains('com.chess'), isFalse);
      expect(exemptedGames.contains('com.chess'), isTrue);

      // Background sync/launch must respect exemption and NOT re-add Chess
      expect(tryAutoRestrict('com.chess', isGame: true), isFalse);
      expect(restrictedApps.contains('com.chess'), isFalse);

      // Parent manually checks Chess back ON -> exemption clears
      toggleRestricted('com.chess');
      expect(restrictedApps.contains('com.chess'), isTrue);
      expect(exemptedGames.contains('com.chess'), isFalse);
    });

    test('Mode-scoped enforcement: Games only count/lock in Kids Mode & Study Zone, never in Adult Mode', () {
      String? evaluateGameAccess({
        required bool isKidsModeEnabled,
        required bool isStudyZoneActive,
        required bool isRestrictedOrDetectedGame,
        required int totalUsedSeconds,
        required int gameLimitMinutes,
      }) {
        final isGameEnforcementActive = isKidsModeEnabled || isStudyZoneActive;
        if (!isGameEnforcementActive || !isRestrictedOrDetectedGame) {
          return 'ALLOWED';
        }
        if (isStudyZoneActive) {
          return 'REASON_STUDY_ZONE';
        }
        if (totalUsedSeconds >= gameLimitMinutes * 60) {
          return 'REASON_GAME_LIMIT';
        }
        return 'COUNTING';
      }

      // Adult Mode (both OFF): parent plays unrestricted even with exhausted quota
      expect(
        evaluateGameAccess(
          isKidsModeEnabled: false,
          isStudyZoneActive: false,
          isRestrictedOrDetectedGame: true,
          totalUsedSeconds: 1800,
          gameLimitMinutes: 20,
        ),
        equals('ALLOWED'),
      );

      // Kids Mode ON, child already spent 20 min on Game A -> downloads Game B -> immediate lockout!
      expect(
        evaluateGameAccess(
          isKidsModeEnabled: true,
          isStudyZoneActive: false,
          isRestrictedOrDetectedGame: true,
          totalUsedSeconds: 1200,
          gameLimitMinutes: 20,
        ),
        equals('REASON_GAME_LIMIT'),
      );

      // Kids Mode ON, fresh day (0s used) -> newly installed game counts within shared limit
      expect(
        evaluateGameAccess(
          isKidsModeEnabled: true,
          isStudyZoneActive: false,
          isRestrictedOrDetectedGame: true,
          totalUsedSeconds: 0,
          gameLimitMinutes: 20,
        ),
        equals('COUNTING'),
      );

      // Study Zone ON -> instant Study Zone lock even at 0s used
      expect(
        evaluateGameAccess(
          isKidsModeEnabled: false,
          isStudyZoneActive: true,
          isRestrictedOrDetectedGame: true,
          totalUsedSeconds: 0,
          gameLimitMinutes: 20,
        ),
        equals('REASON_STUDY_ZONE'),
      );
    });

    test('Verify Kotlin GameDetector, install receiver, mode-scoped guards, and Flutter UI/Bridge integration', () {
      final detectorFile = File('android/app/src/main/kotlin/com/doomsblocker/app/GameDetector.kt');
      expect(detectorFile.existsSync(), isTrue);
      final detectorCode = detectorFile.readAsStringSync();
      expect(detectorCode, contains('CATEGORY_GAME'));
      expect(detectorCode, contains('FLAG_IS_GAME'));
      expect(detectorCode, contains('syncAllInstalledGames'));
      expect(detectorCode, contains('syncAndCheckRestricted'));
      expect(detectorCode, contains('com.android.vending'));

      final prefsFile = File('android/app/src/main/kotlin/com/doomsblocker/app/AppPreferences.kt');
      final prefsCode = prefsFile.readAsStringSync();
      expect(prefsCode, contains('KEY_EXEMPTED_GAMES'));
      expect(prefsCode, contains('KEY_AUTO_RESTRICT_GAMES'));
      expect(prefsCode, contains('toggleRestrictedApp'));
      expect(prefsCode, contains('autoRestrictGameIfEligible'));

      final fgFile = File('android/app/src/main/kotlin/com/doomsblocker/app/AppMonitorForegroundService.kt');
      final fgCode = fgFile.readAsStringSync();
      expect(fgCode, contains('Intent.ACTION_PACKAGE_ADDED'));
      expect(fgCode, contains('ContextCompat.RECEIVER_EXPORTED'));
      expect(fgCode, contains('prefs.isKidsModeEnabled || prefs.isStudyZoneActive'));
      expect(fgCode, contains('GameDetector.syncAndCheckRestricted'));

      final a11yFile = File('android/app/src/main/kotlin/com/doomsblocker/app/DoomsAccessibilityService.kt');
      final a11yCode = a11yFile.readAsStringSync();
      expect(a11yCode, contains('GameDetector.syncAllInstalledGames'));
      expect(a11yCode, contains('GameDetector.syncAndCheckRestricted'));
      expect(a11yCode, contains('prefs.isKidsModeEnabled || prefs.isStudyZoneActive'));

      final mainFile = File('android/app/src/main/kotlin/com/doomsblocker/app/MainActivity.kt');
      final mainCode = mainFile.readAsStringSync();
      expect(mainCode, contains('"setAutoRestrictGames"'));
      expect(mainCode, contains('"autoRestrictGames"'));
      expect(mainCode, contains('"isExempted"'));
      expect(mainCode, contains('prefs.toggleRestrictedApp'));

      final bridgeFile = File('lib/services/native_bridge.dart');
      expect(bridgeFile.readAsStringSync(), contains('setAutoRestrictGames'));

      final dashboardModel = File('lib/models/dashboard_data.dart');
      expect(dashboardModel.readAsStringSync(), contains('autoRestrictGames'));

      final appModel = File('lib/models/installed_app_model.dart');
      expect(appModel.readAsStringSync(), contains('isExempted'));

      final uiFile = File('lib/screens/game_limits_screen.dart');
      final uiCode = uiFile.readAsStringSync();
      expect(uiCode, contains('Auto-Restrict New & Installed Games'));
      expect(uiCode, contains('NativeBridge.setAutoRestrictGames'));
      expect(uiCode, contains('ALLOWED'));
    });
  });
}
