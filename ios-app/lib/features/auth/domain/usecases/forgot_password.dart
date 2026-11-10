import '../repositories/auth_repository.dart';

class ForgotPassword {
  const ForgotPassword(this.repository);
  final AuthRepository repository;
  Future<void> call(String email) => repository.forgotPassword(email);
}
