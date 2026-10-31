class DashboardData {
  final int shortsLimitMinutes;
  final int shortsLockDurationMinutes;
  final int shortsUsedSecondsToday;
  final bool isYouTubeLocked;
  final int youtubeLockRemainingSeconds;
  final bool isNephewModeEnabled;
  final int gameLimitMinutes;
  final int restrictedAppsCount;
  final int blockedChannelsCount;
  final bool isStudyZoneActive;
  final String studyZoneName;
  final int studyZoneRemainingSeconds;
  final bool isPinSet;
  final List<String> enabledShortFormApps;

  bool get isKidsModeEnabled => isNephewModeEnabled;

  DashboardData({
    required this.shortsLimitMinutes,
    required this.shortsLockDurationMinutes,
    required this.shortsUsedSecondsToday,
    required this.isYouTubeLocked,
    required this.youtubeLockRemainingSeconds,
    required this.isNephewModeEnabled,
    required this.gameLimitMinutes,
    required this.restrictedAppsCount,
    required this.blockedChannelsCount,
    required this.isStudyZoneActive,
    required this.studyZoneName,
    required this.studyZoneRemainingSeconds,
    this.isPinSet = false,
    this.enabledShortFormApps = const [
      'com.google.android.youtube',
      'com.instagram.android',
    ],
  });

  factory DashboardData.fromMap(Map<dynamic, dynamic> map) {
    final rawApps = map['enabledShortFormApps'];
    List<String> apps = const [
      'com.google.android.youtube',
      'com.instagram.android',
    ];
    if (rawApps is List) {
      apps = rawApps.map((e) => e.toString()).toList();
    }

    return DashboardData(
      shortsLimitMinutes: (map['shortsLimitMinutes'] as num?)?.toInt() ?? 2,
      shortsLockDurationMinutes: (map['shortsLockDurationMinutes'] as num?)?.toInt() ?? 30,
      shortsUsedSecondsToday: (map['shortsUsedSecondsToday'] as num?)?.toInt() ?? 0,
      isYouTubeLocked: map['isYouTubeLocked'] as bool? ?? false,
      youtubeLockRemainingSeconds: (map['youtubeLockRemainingSeconds'] as num?)?.toInt() ?? 0,
      isNephewModeEnabled: map['isKidsModeEnabled'] as bool? ??
          map['isNephewModeEnabled'] as bool? ??
          false,
      gameLimitMinutes: (map['gameLimitMinutes'] as num?)?.toInt() ?? 20,
      restrictedAppsCount: (map['restrictedAppsCount'] as num?)?.toInt() ?? 0,
      blockedChannelsCount: (map['blockedChannelsCount'] as num?)?.toInt() ?? 0,
      isStudyZoneActive: map['isStudyZoneActive'] as bool? ?? false,
      studyZoneName: map['studyZoneName'] as String? ?? 'Library Study Zone',
      studyZoneRemainingSeconds: (map['studyZoneRemainingSeconds'] as num?)?.toInt() ?? 0,
      isPinSet: map['isPinSet'] as bool? ?? false,
      enabledShortFormApps: apps,
    );
  }

  factory DashboardData.initial() {
    return DashboardData(
      shortsLimitMinutes: 2,
      shortsLockDurationMinutes: 30,
      shortsUsedSecondsToday: 0,
      isYouTubeLocked: false,
      youtubeLockRemainingSeconds: 0,
      isNephewModeEnabled: false,
      gameLimitMinutes: 20,
      restrictedAppsCount: 0,
      blockedChannelsCount: 0,
      isStudyZoneActive: false,
      studyZoneName: 'Library Study Zone',
      studyZoneRemainingSeconds: 0,
      isPinSet: false,
      enabledShortFormApps: const [
        'com.google.android.youtube',
        'com.instagram.android',
      ],
    );
  }
}
