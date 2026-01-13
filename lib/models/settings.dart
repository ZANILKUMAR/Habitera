class AppSettings {
  final String theme; // 'light', 'dark', 'system'
  final bool notificationsEnabled;
  final DateTime? lastBackup;
  final String appVersion;

  AppSettings({
    this.theme = 'dark',
    this.notificationsEnabled = true,
    this.lastBackup,
    this.appVersion = '1.0.0',
  });

  AppSettings copyWith({
    String? theme,
    bool? notificationsEnabled,
    DateTime? lastBackup,
    String? appVersion,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      lastBackup: lastBackup ?? this.lastBackup,
      appVersion: appVersion ?? this.appVersion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'theme': theme,
      'notificationsEnabled': notificationsEnabled ? 1 : 0,
      'lastBackup': lastBackup?.toIso8601String(),
      'appVersion': appVersion,
    };
  }

  static AppSettings fromMap(Map<String, dynamic> map) {
    return AppSettings(
      theme: map['theme'] ?? 'dark',
      notificationsEnabled: (map['notificationsEnabled'] ?? 1) == 1,
      lastBackup:
          map['lastBackup'] != null ? DateTime.parse(map['lastBackup']) : null,
      appVersion: map['appVersion'] ?? '1.0.0',
    );
  }
}
