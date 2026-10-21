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
  });

  factory DashboardData.fromMap(Map<dynamic, dynamic> map) {
    return DashboardData(
      shortsLimitMinutes: (map['shortsLimitMinutes'] as num?)?.toInt() ?? 2,
      shortsLockDurationMinutes: (map['shortsLockDurationMinutes'] as num?)?.toInt() ?? 30,
      shortsUsedSecondsToday: (map['shortsUsedSecondsToday'] as num?)?.toInt() ?? 0,
      isYouTubeLocked: map['isYouTubeLocked'] as bool? ?? false,
      youtubeLockRemainingSeconds: (map['youtubeLockRemainingSeconds'] as num?)?.toInt() ?? 0,
      isNephewModeEnabled: map['isNephewModeEnabled'] as bool? ?? false,
      gameLimitMinutes: (map['gameLimitMinutes'] as num?)?.toInt() ?? 20,
      restrictedAppsCount: (map['restrictedAppsCount'] as num?)?.toInt() ?? 0,
      blockedChannelsCount: (map['blockedChannelsCount'] as num?)?.toInt() ?? 0,
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
    );
  }
}
