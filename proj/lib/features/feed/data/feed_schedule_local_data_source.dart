import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FeedScheduleEntry {
  const FeedScheduleEntry({
    required this.id,
    required this.name,
    required this.minutesAfterMidnight,
    this.remindersEnabled = false,
    this.completed = false,
  });

  final String id;
  final String name;
  final int minutesAfterMidnight;
  final bool remindersEnabled;
  final bool completed;

  int get hour => minutesAfterMidnight ~/ 60;
  int get minute => minutesAfterMidnight % 60;

  FeedScheduleEntry copyWith({
    String? name,
    int? minutesAfterMidnight,
    bool? remindersEnabled,
    bool? completed,
  }) => FeedScheduleEntry(
    id: id,
    name: name ?? this.name,
    minutesAfterMidnight: minutesAfterMidnight ?? this.minutesAfterMidnight,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    completed: completed ?? this.completed,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'minutesAfterMidnight': minutesAfterMidnight,
    'remindersEnabled': remindersEnabled,
    'completed': completed,
  };

  factory FeedScheduleEntry.fromJson(Map<String, dynamic> json) {
    final minutes = json['minutesAfterMidnight'];
    if (json['id'] is! String ||
        json['name'] is! String ||
        minutes is! int ||
        minutes < 0 ||
        minutes >= 24 * 60) {
      throw const FormatException('Invalid stored feeding schedule entry.');
    }
    return FeedScheduleEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      minutesAfterMidnight: minutes,
      remindersEnabled: json['remindersEnabled'] as bool? ?? false,
      completed: json['completed'] as bool? ?? false,
    );
  }
}

class FeedScheduleLocalDataSource {
  FeedScheduleLocalDataSource({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const defaults = <FeedScheduleEntry>[
    FeedScheduleEntry(
      id: 'morning',
      name: 'Morning feeding',
      minutesAfterMidnight: 6 * 60 + 30,
    ),
    FeedScheduleEntry(
      id: 'midday',
      name: 'Midday feeding',
      minutesAfterMidnight: 13 * 60,
    ),
    FeedScheduleEntry(
      id: 'evening',
      name: 'Evening feeding',
      minutesAfterMidnight: 17 * 60 + 30,
    ),
  ];

  Future<List<FeedScheduleEntry>> read({
    required String userId,
    required String farmId,
  }) async {
    final raw = await _storage.read(key: _key(userId, farmId));
    if (raw == null) return defaults;
    final stored = jsonDecode(raw);
    if (stored is! Map<String, dynamic>) {
      throw const FormatException('Stored feeding schedule is not an object.');
    }
    final entries = stored['entries'];
    if (entries is! List<dynamic>) {
      final legacyCompleted = stored['completed'];
      if (legacyCompleted is Map<dynamic, dynamic>) {
        if (stored['date'] != _today()) return defaults;
        final completed = Map<String, dynamic>.from(legacyCompleted);
        return defaults
            .map(
              (entry) => entry.copyWith(
                completed:
                    completed[_legacyNameFor(entry.id)] as bool? ?? false,
              ),
            )
            .toList(growable: false);
      }
      throw const FormatException('Stored feeding schedule has no entries.');
    }
    final isToday = stored['date'] == _today();
    return entries
        .map((entry) {
          if (entry is! Map<String, dynamic>) {
            throw const FormatException(
              'Stored feeding schedule entry is not an object.',
            );
          }
          final parsed = FeedScheduleEntry.fromJson(entry);
          return isToday ? parsed : parsed.copyWith(completed: false);
        })
        .toList(growable: false);
  }

  Future<void> write({
    required String userId,
    required String farmId,
    required List<FeedScheduleEntry> entries,
  }) => _storage.write(
    key: _key(userId, farmId),
    value: jsonEncode({
      'date': _today(),
      'entries': entries.map((entry) => entry.toJson()).toList(),
    }),
  );

  Future<void> clearUser(String userId) async {
    final prefix = 'feed.schedule.${Uri.encodeComponent(userId)}.';
    final storedValues = await _storage.readAll();
    for (final key in storedValues.keys.where(
      (key) => key.startsWith(prefix),
    )) {
      await _storage.delete(key: key);
    }
  }

  String _key(String userId, String farmId) =>
      'feed.schedule.${Uri.encodeComponent(userId)}.${Uri.encodeComponent(farmId)}';

  String _legacyNameFor(String id) => switch (id) {
    'morning' => 'Morning',
    'midday' => 'Afternoon',
    'evening' => 'Evening',
    _ => id,
  };

  String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
