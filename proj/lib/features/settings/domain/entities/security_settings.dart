class SecuritySettings {
  const SecuritySettings({
    required this.hasTwoFactorAuth,
    required this.hasBiometricEnabled,
    required this.biometricTypes,
    required this.lastPasswordChange,
  });

  final bool hasTwoFactorAuth;
  final bool hasBiometricEnabled;
  final List<String> biometricTypes; // 'fingerprint', 'face'
  final DateTime? lastPasswordChange;

  SecuritySettings copyWith({
    bool? hasTwoFactorAuth,
    bool? hasBiometricEnabled,
    List<String>? biometricTypes,
    DateTime? lastPasswordChange,
  }) => SecuritySettings(
    hasTwoFactorAuth: hasTwoFactorAuth ?? this.hasTwoFactorAuth,
    hasBiometricEnabled: hasBiometricEnabled ?? this.hasBiometricEnabled,
    biometricTypes: biometricTypes ?? this.biometricTypes,
    lastPasswordChange: lastPasswordChange ?? this.lastPasswordChange,
  );

  Map<String, dynamic> toJson() => {
    'hasTwoFactorAuth': hasTwoFactorAuth,
    'hasBiometricEnabled': hasBiometricEnabled,
    'biometricTypes': biometricTypes,
    'lastPasswordChange': lastPasswordChange?.toIso8601String(),
  };

  factory SecuritySettings.fromJson(Map<String, dynamic> json) =>
      SecuritySettings(
        hasTwoFactorAuth: json['hasTwoFactorAuth'] as bool? ?? false,
        hasBiometricEnabled: json['hasBiometricEnabled'] as bool? ?? false,
        biometricTypes: List<String>.from(
          json['biometricTypes'] as List<dynamic>? ?? [],
        ),
        lastPasswordChange: json['lastPasswordChange'] != null
            ? DateTime.parse(json['lastPasswordChange'] as String)
            : null,
      );

  factory SecuritySettings.defaults() => const SecuritySettings(
    hasTwoFactorAuth: false,
    hasBiometricEnabled: false,
    biometricTypes: [],
    lastPasswordChange: null,
  );
}
