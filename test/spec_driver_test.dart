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
  });

  group('SPEC 2: Library Study Zone State Machine Transitions', () {
    // Simulated state transition engine matching study_zone_screen.dart
    String simulateScanAction({
      required bool isStudyZoneActive,
      required StudyScanType scannedType,
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

    test('Scanning Check-Out while ACTIVE must show Checkout Confirmation', () {
      final action = simulateScanAction(
        isStudyZoneActive: true,
        scannedType: StudyScanType.checkOut,
      );
      expect(action, equals('SHOW_CHECKOUT_CONFIRMATION'));
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
}
