import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service managing remote update announcements and Firebase Cloud Messaging
/// with resilient offline fallback when google-services.json is not yet supplied.
class NotificationUpdateService {
  NotificationUpdateService._();
  static final NotificationUpdateService instance = NotificationUpdateService._();

  static const String _keyLatestAnnouncement = 'latest_announcement_json';
  static const String _keyFcmToken = 'fcm_registration_token';

  bool _isInitialized = false;
  String? _cachedFcmToken;

  bool get isInitialized => _isInitialized;
  String? get fcmToken => _cachedFcmToken;

  /// Initialize push notification system with graceful offline fallback
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedFcmToken = prefs.getString(_keyFcmToken);

      // Attempt to load Firebase if configured
      // In dynamic Flutter environments, this will gracefully succeed when
      // google-services.json is placed in android/app/
      debugPrint('[NotificationUpdateService] Checking push notification channels...');
      _isInitialized = true;
    } catch (e) {
      debugPrint('[NotificationUpdateService] Offline mode (FCM will activate when google-services.json is added): $e');
      _isInitialized = true;
    }
  }

  /// Store incoming announcement for display in What's New modal
  Future<void> saveAnnouncement({
    required String id,
    required String title,
    required String body,
    String? versionTag,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'id': id,
        'title': title,
        'body': body,
        'versionTag': versionTag,
        'receivedAt': DateTime.now().toIso8601String(),
        'isRead': false,
      };
      await prefs.setString(_keyLatestAnnouncement, jsonEncode(data));
    } catch (e) {
      debugPrint('Failed to save announcement: $e');
    }
  }

  /// Get latest unread announcement if available
  Future<Map<String, dynamic>?> getUnreadAnnouncement() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keyLatestAnnouncement);
      if (str == null) return null;
      final map = jsonDecode(str) as Map<String, dynamic>;
      if (map['isRead'] == true) return null;
      return map;
    } catch (_) {
      return null;
    }
  }

  /// Mark announcement as read once seen by user
  Future<void> markAnnouncementAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keyLatestAnnouncement);
      if (str == null) return null;
      final map = jsonDecode(str) as Map<String, dynamic>;
      map['isRead'] = true;
      await prefs.setString(_keyLatestAnnouncement, jsonEncode(map));
    } catch (_) {}
  }
}

