import '../entities/session.dart';
import '../repositories/auth_repository.dart';

class VerifyLoginOtp {
  const VerifyLoginOtp(this.repository);

  final AuthRepository repository;

  Future<Session> call(String challengeId, String code) =>
      repository.verifyLoginOtp(challengeId, code);
}
