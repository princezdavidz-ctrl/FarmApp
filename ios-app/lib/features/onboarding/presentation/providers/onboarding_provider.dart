import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../security/authorization/roles.dart';
import '../../data/onboarding_storage.dart';

final onboardingStorageProvider = Provider<OnboardingStorage>(
  (ref) => OnboardingStorage(),
);

final onboardingCompletedProvider = FutureProvider<bool>(
  (ref) => ref.watch(onboardingStorageProvider).completed,
);

class OnboardingState {
  const OnboardingState({
    this.notifications = false,
    this.location = false,
    this.biometric = false,
    this.language = 'English',
    this.languageCode = 'en',
    this.country,
    this.roles = const {},
    this.motherPigCount = 0,
    this.pigletGroups = const [],
    this.pregnantPigCount,
  });

  final bool notifications;
  final bool location;
  final bool biometric;
  final String language;
  final String languageCode;
  final String? country;
  final Set<UserRole> roles;
  final int motherPigCount;
  final List<PigletGroup> pigletGroups;
  final int? pregnantPigCount;

  OnboardingState copyWith({
    bool? notifications,
    bool? location,
    bool? biometric,
    String? language,
    String? languageCode,
    String? country,
    Set<UserRole>? roles,
    int? motherPigCount,
    List<PigletGroup>? pigletGroups,
    int? pregnantPigCount,
  }) => OnboardingState(
    notifications: notifications ?? this.notifications,
    location: location ?? this.location,
    biometric: biometric ?? this.biometric,
    language: language ?? this.language,
    languageCode: languageCode ?? this.languageCode,
    country: country ?? this.country,
    roles: roles ?? this.roles,
    motherPigCount: motherPigCount ?? this.motherPigCount,
    pigletGroups: pigletGroups ?? this.pigletGroups,
    pregnantPigCount: pregnantPigCount ?? this.pregnantPigCount,
  );
}

class PigletGroup {
  const PigletGroup({required this.count, required this.ageMonths});

  final int count;
  final int ageMonths;

  Map<String, dynamic> toJson() => {'count': count, 'age_months': ageMonths};
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(
      OnboardingNotifier.new,
    );

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  void setPermissions({required bool notifications, required bool location}) =>
      state = state.copyWith(notifications: notifications, location: location);
  void setBiometric(bool enabled) => state = state.copyWith(biometric: enabled);
  void setLanguage({required String name, required String code}) =>
      state = state.copyWith(language: name, languageCode: code);
  void setCountry(String country) => state = state.copyWith(country: country);
  void toggleRole(UserRole role, bool selected) {
    state = state.copyWith(roles: selected ? {role} : <UserRole>{});
  }

  void setHerdSetup({
    required int motherPigCount,
    required List<PigletGroup> pigletGroups,
    int? pregnantPigCount,
  }) {
    state = state.copyWith(
      motherPigCount: motherPigCount,
      pigletGroups: pigletGroups,
      pregnantPigCount: pregnantPigCount,
    );
  }
}
