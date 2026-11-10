import '../repositories/auth_repository.dart';

class Logout {
  const Logout(this.repository);
  final AuthRepository repository;
  Future<void> call() => repository.logout();
}
