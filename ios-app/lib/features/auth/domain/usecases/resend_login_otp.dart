import '../entities/login_challenge.dart';
import '../repositories/auth_repository.dart';

class ResendLoginOtp {
  const ResendLoginOtp(this.repository);

  final AuthRepository repository;

  Future<LoginChallenge> call(String challengeId) =>
      repository.resendLoginOtp(challengeId);
}
