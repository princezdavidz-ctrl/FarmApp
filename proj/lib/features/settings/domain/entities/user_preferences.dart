class UserPreferences {
  const UserPreferences({
    required this.language,
    required this.isDarkMode,
    required this.weightUnit,
    required this.dateFormat,
    required this.currency,
    required this.notifications,
    required this.notificationChannels,
    required this.notificationSound,
  });

  final String language; // 'en', 'sw'
  final bool isDarkMode;
  final String weightUnit; // 'kg', 'lb'
  final String dateFormat; // 'dd/MM/yyyy', 'MM/dd/yyyy'
  final String currency; // 'KES', 'USD'
  final Map<String, bool> notifications;
  final Map<String, bool> notificationChannels;
  final String notificationSound;

  UserPreferences copyWith({
    String? language,
    bool? isDarkMode,
    String? weightUnit,
    String? dateFormat,
    String? currency,
    Map<String, bool>? notifications,
    Map<String, bool>? notificationChannels,
    String? notificationSound,
  }) => UserPreferences(
    language: language ?? this.language,
    isDarkMode: isDarkMode ?? this.isDarkMode,
    weightUnit: weightUnit ?? this.weightUnit,
    dateFormat: dateFormat ?? this.dateFormat,
    currency: currency ?? this.currency,
    notifications: notifications ?? this.notifications,
    notificationChannels: notificationChannels ?? this.notificationChannels,
    notificationSound: notificationSound ?? this.notificationSound,
  );

  Map<String, dynamic> toJson() => {
    'language': language,
    'isDarkMode': isDarkMode,
    'weightUnit': weightUnit,
    'dateFormat': dateFormat,
    'currency': currency,
    'notifications': notifications,
    'notificationChannels': notificationChannels,
    'notificationSound': notificationSound,
  };

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      UserPreferences(
        language: json['language'] as String? ?? 'en',
        isDarkMode: json['isDarkMode'] as bool? ?? false,
        weightUnit: json['weightUnit'] as String? ?? 'kg',
        dateFormat: json['dateFormat'] as String? ?? 'dd/MM/yyyy',
        currency: json['currency'] as String? ?? 'KES',
        notifications: Map<String, bool>.from(
          json['notifications'] as Map<dynamic, dynamic>? ?? {},
        ),
        notificationChannels: Map<String, bool>.from(
          json['notificationChannels'] as Map<dynamic, dynamic>? ??
              const {'push': true, 'sms': false, 'email': true},
        ),
        notificationSound: json['notificationSound'] as String? ?? 'default',
      );

  factory UserPreferences.defaults() => const UserPreferences(
    language: 'en',
    isDarkMode: false,
    weightUnit: 'kg',
    dateFormat: 'dd/MM/yyyy',
    currency: 'KES',
    notifications: {
      'vaccinations': true,
      'feeding': true,
      'breeding': true,
      'lowStock': true,
      'sales': true,
      'payments': true,
    },
    notificationChannels: {'push': true, 'sms': false, 'email': true},
    notificationSound: 'default',
  );
}
