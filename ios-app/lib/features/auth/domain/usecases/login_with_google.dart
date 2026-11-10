import '../entities/session.dart';
import '../repositories/auth_repository.dart';

class LoginWithGoogle {
  const LoginWithGoogle(this.repository);

  final AuthRepository repository;

  Future<Session> call(String idToken) => repository.loginWithGoogle(idToken);
}
