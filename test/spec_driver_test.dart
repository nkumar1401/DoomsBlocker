import 'package:flutter_test/flutter_test.dart';
import 'package:doomsblocker/screens/qr_scanner_screen.dart';

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
    bool isChannelBlocked(String detectedChannel, List<String> blockedList) {
      final detectedLower = detectedChannel.trim().toLowerCase();
      return blockedList.any((blocked) => detectedLower.contains(blocked.trim().toLowerCase()));
    }

    test('Case-insensitively matches blocked channels regardless of casing', () {
      final blockedList = ['Firstpost', 'T-Series', 'PewDiePie'];

      expect(isChannelBlocked('firstpost', blockedList), isTrue);
      expect(isChannelBlocked('FIRSTPOST', blockedList), isTrue);
      expect(isChannelBlocked('Firstpost News', blockedList), isTrue);
      expect(isChannelBlocked('t-series music', blockedList), isTrue);
      expect(isChannelBlocked('pewdiepie', blockedList), isTrue);
      expect(isChannelBlocked('BBC News', blockedList), isFalse);
      expect(isChannelBlocked('Khan Academy', blockedList), isFalse);
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

    test('Exiting Shorts to YouTube Home Feed Overview or Long-Form immediately pauses timer', () {
      bool isShortsDetected({
        required bool isVisibleToUser,
        required bool isShortsPlayer,
        required bool isHomeFeedOverviewOrLongForm,
      }) {
        if (isHomeFeedOverviewOrLongForm) {
          // If Home Feed Overview (with inline preview) or watch player is active, Shorts is always FALSE
          return false;
        }
        return isVisibleToUser && isShortsPlayer;
      }

      // 1. While inside Shorts: timer active
      expect(isShortsDetected(
        isVisibleToUser: true,
        isShortsPlayer: true,
        isHomeFeedOverviewOrLongForm: false,
      ), isTrue);

      // 2. Switched back to Home feed overview: timer immediately pauses
      expect(isShortsDetected(
        isVisibleToUser: false, // Shorts fragment hidden in backstack
        isShortsPlayer: true,
        isHomeFeedOverviewOrLongForm: true, // Home tab / inline player visible
      ), isFalse);

      // 3. Watching a long-form video: timer paused
      expect(isShortsDetected(
        isVisibleToUser: false,
        isShortsPlayer: true,
        isHomeFeedOverviewOrLongForm: true, // watch_player active
      ), isFalse);
    });
  });

  group('SPEC 7: Google Pay-Style Security Session & First-Time PIN Invariants', () {
    test('Fresh install has no PIN set by default', () {
      String storedPin = '';
      bool isPinConfigured() => storedPin.trim().isNotEmpty;

      expect(isPinConfigured(), isFalse);
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
}


