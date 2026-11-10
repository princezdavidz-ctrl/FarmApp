import 'package:dio/dio.dart';

import '../../../../core/errors/error_handler.dart';
import '../models/login_request.dart';
import '../models/login_challenge_response.dart';
import '../models/login_response.dart';
import '../models/register_request.dart';
import 'auth_remote_datasource.dart';

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<LoginChallengeResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: request.toJson(),
      );
      return LoginChallengeResponse.fromJson(response.data!);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  @override
  Future<LoginChallengeResponse> resendLoginOtp(String challengeId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/resend-otp',
        data: {'challenge_id': challengeId},
      );
      return LoginChallengeResponse.fromJson(response.data!);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  @override
  Future<LoginResponse> verifyLoginOtp(String challengeId, String code) =>
      _postForSession('/auth/verify-otp', {
        'challenge_id': challengeId,
        'code': code,
      });

  @override
  Future<LoginResponse> loginWithGoogle(String idToken) =>
      _postForSession('/auth/google', {'id_token': idToken});

  @override
  Future<LoginResponse> loginWithApple(String idToken) =>
      _postForSession('/auth/firebase', {'id_token': idToken});

  @override
  Future<LoginResponse> register(RegisterRequest request) =>
      _postForSession('/auth/register', request.toJson());

  @override
  Future<LoginResponse> refresh(String refreshToken) =>
      _postForSession('/auth/refresh', {'refresh_token': refreshToken});

  @override
  Future<void> logout(String accessToken) async {
    try {
      await _dio.post<void>('/auth/logout');
    } on DioException {
      // Best-effort: the local session is cleared by the caller regardless of server-side revocation.
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post<void>(
        '/auth/forgot-password',
        data: {'email': email},
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<LoginResponse> _postForSession(
    String path,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: data);
      return LoginResponse.fromJson(response.data!);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }
}
