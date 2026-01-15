class AppSettings {
  final String theme; // 'light', 'dark', 'system'
  final bool notificationsEnabled;
  final DateTime? lastBackup;
  final String appVersion;
  final bool notePromptOnTap; // When true: tap opens notes, long-press marks immediately
                              // When false: tap marks immediately, long-press opens notes

  AppSettings({
    this.theme = 'dark',
    this.notificationsEnabled = true,
    this.lastBackup,
    this.appVersion = '1.0.0',
    this.notePromptOnTap = false,
  });

  AppSettings copyWith({
    String? theme,
    bool? notificationsEnabled,
    DateTime? lastBackup,
    String? appVersion,
    bool? notePromptOnTap,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      lastBackup: lastBackup ?? this.lastBackup,
      appVersion: appVersion ?? this.appVersion,
      notePromptOnTap: notePromptOnTap ?? this.notePromptOnTap,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'theme': theme,
      'notificationsEnabled': notificationsEnabled ? 1 : 0,
      'lastBackup': lastBackup?.toIso8601String(),
      'appVersion': appVersion,
      'notePromptOnTap': notePromptOnTap ? 1 : 0,
    };
  }

  static AppSettings fromMap(Map<String, dynamic> map) {
    // Handle lastBackup - might be null, "null" string, or a valid date string
    DateTime? lastBackup;
    final lastBackupValue = map['lastBackup'];
    if (lastBackupValue != null && 
        lastBackupValue != 'null' && 
        lastBackupValue.toString().isNotEmpty) {
      try {
        lastBackup = DateTime.parse(lastBackupValue.toString());
      } catch (e) {
        lastBackup = null;
      }
    }

    return AppSettings(
      theme: map['theme']?.toString() ?? 'dark',
      notificationsEnabled: map['notificationsEnabled']?.toString() == '1',
      lastBackup: lastBackup,
      appVersion: map['appVersion']?.toString() ?? '1.0.0',
      notePromptOnTap: map['notePromptOnTap']?.toString() == '1',
    );
  }
}
