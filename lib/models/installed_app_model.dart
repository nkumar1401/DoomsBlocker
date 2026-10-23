class InstalledAppModel {
  final String name;
  final String packageName;
  final bool isRestricted;
  final int usedMinutes;
  final bool isGame;

  InstalledAppModel({
    required this.name,
    required this.packageName,
    required this.isRestricted,
    required this.usedMinutes,
    this.isGame = false,
  });

  factory InstalledAppModel.fromMap(Map<dynamic, dynamic> map) {
    return InstalledAppModel(
      name: map['name'] as String? ?? 'Unknown App',
      packageName: map['packageName'] as String? ?? '',
      isRestricted: map['isRestricted'] as bool? ?? false,
      usedMinutes: (map['usedMinutes'] as num?)?.toInt() ?? 0,
      isGame: map['isGame'] as bool? ?? false,
    );
  }
}
