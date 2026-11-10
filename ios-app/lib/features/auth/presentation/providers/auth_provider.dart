import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/session.dart';

final authProvider = NotifierProvider<AuthNotifier, AsyncValue<Session?>>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AsyncValue<Session?>> {
  @override
  AsyncValue<Session?> build() => const AsyncData(null);

  void setSession(Session session) => state = AsyncData(session);
  void clearSession() => state = const AsyncData(null);
  bool get isAuthenticated => state.valueOrNull != null;
}
