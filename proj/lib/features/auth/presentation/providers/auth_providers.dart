import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_handler.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../security/authentication/auth_service.dart';
import '../../../../security/session/session_manager.dart';
import '../../data/datasource/auth_local_datasource_impl.dart';
import '../../data/datasource/auth_remote_datasource_impl.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/forgot_password.dart';
import '../../domain/usecases/login.dart';
import '../../domain/usecases/login_with_google.dart';
import '../../domain/usecases/login_with_apple.dart';
import '../../domain/usecases/logout.dart';
import '../../domain/usecases/refresh_session.dart';
import '../../domain/usecases/register.dart';
import '../../domain/usecases/resend_login_otp.dart';
import '../../domain/usecases/select_farm.dart';
import '../../domain/usecases/verify_login_otp.dart';
import 'auth_provider.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final sessionManagerProvider = Provider<SessionManager>(
  (ref) => SessionManager(ref.watch(authServiceProvider)),
);

/// The server address the user configured in-app, falling back to the build-time default.
/// Lets the app be pointed at a different network (LAN IP, tunnel, or domain) without a rebuild.
final serverUrlProvider = FutureProvider<String>((ref) async {
  final saved = await ServerAddressStorage.read();
  if (saved == 'http://localhost/api/v1' ||
      saved == 'http://localhost:8000/api/v1' ||
      saved == 'http://10.0.2.2:8000/api/v1' ||
      saved == 'http://10.0.2.2/api/v1') {
    await ServerAddressStorage.write(ApiConfig.baseUrl);
    return ApiConfig.baseUrl;
  }
  return (saved == null || saved.isEmpty) ? ApiConfig.baseUrl : saved;
});

final dioProvider = Provider<Dio>((ref) {
  final authService = ref.watch(authServiceProvider);
  final dio = DioClient.create(
    authService: authService,
    onSessionExpired: () async {
      await authService.clearSession();
      ref.read(authProvider.notifier).clearSession();
    },
  );
  ref.listen(serverUrlProvider, (previous, next) {
    next.whenData((baseUrl) => dio.options.baseUrl = baseUrl);
  }, fireImmediately: true);
  return dio;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    remote: AuthRemoteDataSourceImpl(ref.watch(dioProvider)),
    local: AuthLocalDataSourceImpl(),
  ),
);

final loginUseCaseProvider = Provider(
  (ref) => Login(ref.watch(authRepositoryProvider)),
);
final resendLoginOtpUseCaseProvider = Provider(
  (ref) => ResendLoginOtp(ref.watch(authRepositoryProvider)),
);
final verifyLoginOtpUseCaseProvider = Provider(
  (ref) => VerifyLoginOtp(ref.watch(authRepositoryProvider)),
);
final loginWithGoogleUseCaseProvider = Provider(
  (ref) => LoginWithGoogle(ref.watch(authRepositoryProvider)),
);
final loginWithAppleUseCaseProvider = Provider(
  (ref) => LoginWithApple(ref.watch(authRepositoryProvider)),
);
final registerUseCaseProvider = Provider(
  (ref) => Register(ref.watch(authRepositoryProvider)),
);
final logoutUseCaseProvider = Provider(
  (ref) => Logout(ref.watch(authRepositoryProvider)),
);
final refreshSessionUseCaseProvider = Provider(
  (ref) => RefreshSession(ref.watch(authRepositoryProvider)),
);
final selectFarmUseCaseProvider = Provider(
  (ref) => SelectFarm(ref.watch(authRepositoryProvider)),
);
final forgotPasswordUseCaseProvider = Provider(
  (ref) => ForgotPassword(ref.watch(authRepositoryProvider)),
);

/// Restores a persisted session only after the server accepts and rotates its refresh token.
/// This also reloads the user's current farm memberships before the splash opens authenticated UI.
final sessionRestoreProvider = FutureProvider<Session?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final local = AuthLocalDataSourceImpl();
  if (!await authService.rememberMe) {
    await local.clear();
    return null;
  }
  final stored = await local.readSession();
  if (stored == null) {
    await local.clear();
    return null;
  }

  try {
    final refreshed = await ref.read(refreshSessionUseCaseProvider)();
    if (refreshed == null) {
      await local.clear();
      return null;
    }
    await ref.read(sessionManagerProvider).markActive();
    ref.read(authProvider.notifier).setSession(refreshed);
    return refreshed;
  } on ApiException catch (error) {
    if ([401, 403, 422].contains(error.statusCode)) {
      await local.clear();
    }
    return null;
  } on DioException catch (error) {
    // Preserve credentials on network/server failures so a later launch can retry.
    // These statuses mean the server rejected the refresh token itself.
    if ([401, 403, 422].contains(error.response?.statusCode)) {
      await local.clear();
    }
    return null;
  }
});
