class BackupSettings {
  const BackupSettings({
    required this.cloudSyncEnabled,
    required this.automaticBackupEnabled,
    required this.backupFrequency,
    required this.lastBackupDate,
    required this.offlineModeEnabled,
  });

  final bool cloudSyncEnabled;
  final bool automaticBackupEnabled;
  final String backupFrequency; // 'daily', 'weekly', 'monthly'
  final DateTime? lastBackupDate;
  final bool offlineModeEnabled;

  BackupSettings copyWith({
    bool? cloudSyncEnabled,
    bool? automaticBackupEnabled,
    String? backupFrequency,
    DateTime? lastBackupDate,
    bool? offlineModeEnabled,
  }) => BackupSettings(
    cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
    automaticBackupEnabled:
        automaticBackupEnabled ?? this.automaticBackupEnabled,
    backupFrequency: backupFrequency ?? this.backupFrequency,
    lastBackupDate: lastBackupDate ?? this.lastBackupDate,
    offlineModeEnabled: offlineModeEnabled ?? this.offlineModeEnabled,
  );

  Map<String, dynamic> toJson() => {
    'cloudSyncEnabled': cloudSyncEnabled,
    'automaticBackupEnabled': automaticBackupEnabled,
    'backupFrequency': backupFrequency,
    'lastBackupDate': lastBackupDate?.toIso8601String(),
    'offlineModeEnabled': offlineModeEnabled,
  };

  factory BackupSettings.fromJson(Map<String, dynamic> json) => BackupSettings(
    cloudSyncEnabled: json['cloudSyncEnabled'] as bool? ?? false,
    automaticBackupEnabled: json['automaticBackupEnabled'] as bool? ?? false,
    backupFrequency: json['backupFrequency'] as String? ?? 'daily',
    lastBackupDate: json['lastBackupDate'] != null
        ? DateTime.parse(json['lastBackupDate'] as String)
        : null,
    offlineModeEnabled: json['offlineModeEnabled'] as bool? ?? false,
  );

  factory BackupSettings.defaults() => const BackupSettings(
    cloudSyncEnabled: false,
    automaticBackupEnabled: false,
    backupFrequency: 'daily',
    lastBackupDate: null,
    offlineModeEnabled: false,
  );
}
