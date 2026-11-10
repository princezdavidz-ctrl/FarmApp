import '../entities/login_challenge.dart';
import '../repositories/auth_repository.dart';

class Login {
  const Login(this.repository);
  final AuthRepository repository;
  Future<LoginChallenge> call(String email, String password, {bool rememberMe = false}) => repository.login(email, password, rememberMe: rememberMe);
}
