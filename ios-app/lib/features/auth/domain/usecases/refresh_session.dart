import '../entities/session.dart';
import '../repositories/auth_repository.dart';

class RefreshSession {
  const RefreshSession(this.repository);
  final AuthRepository repository;
  Future<Session?> call() => repository.refreshSession();
}
