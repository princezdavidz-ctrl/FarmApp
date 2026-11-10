import '../entities/session.dart';
import '../repositories/auth_repository.dart';

class LoginWithApple {
  const LoginWithApple(this.repository);

  final AuthRepository repository;

  Future<Session> call(String idToken) => repository.loginWithApple(idToken);
}
