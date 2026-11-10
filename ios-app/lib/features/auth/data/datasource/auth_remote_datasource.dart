import '../models/login_request.dart';
import '../models/login_challenge_response.dart';
import '../models/login_response.dart';
import '../models/register_request.dart';

abstract interface class AuthRemoteDataSource {
  Future<LoginChallengeResponse> login(LoginRequest request);
  Future<LoginChallengeResponse> resendLoginOtp(String challengeId);
  Future<LoginResponse> verifyLoginOtp(String challengeId, String code);
  Future<LoginResponse> loginWithGoogle(String idToken);
  Future<LoginResponse> loginWithApple(String idToken);
  Future<LoginResponse> register(RegisterRequest request);
  Future<LoginResponse> refresh(String refreshToken);
  Future<void> logout(String accessToken);
  Future<void> forgotPassword(String email);
}
