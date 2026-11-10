import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Signs the user into Firebase with their Google account.
///
/// The Farm App API must exchange the resulting Firebase ID token for its own
/// session before this can be used as an application login.
class GoogleSignInService {
  GoogleSignInService({FirebaseAuth? firebaseAuth})
    : _providedFirebaseAuth = firebaseAuth;

  final FirebaseAuth? _providedFirebaseAuth;

  static const String _defaultWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );
  static Future<void>? _initialization;

  static String get webClientId => _defaultWebClientId;

  static void validateConfiguration(String clientId) {
    final normalized = clientId.trim();
    if (normalized.isEmpty) {
      return;
    }

    if (!normalized.contains('googleusercontent.com')) {
      throw const GoogleSignInConfigurationException(
        'Google sign-in is not configured correctly. The Firebase web client ID must contain a googleusercontent.com domain.',
      );
    }
  }

  Future<String> signIn() async {
    // Firebase is only needed for the optional Google login flow. Initializing
    // it here keeps an unavailable platform/configuration from blocking app
    // startup before the first screen can render.
    try {
      await _ensureInitialized();

      final account = await GoogleSignIn.instance.authenticate();
      final authentication = account.authentication;
      final idToken = authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google did not return an ID token for sign-in.');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final firebaseAuth = _providedFirebaseAuth ?? FirebaseAuth.instance;
      final userCredential = await firebaseAuth.signInWithCredential(
        credential,
      );
      final firebaseIdToken = await userCredential.user?.getIdToken();
      if (firebaseIdToken == null) {
        throw StateError('Google did not return an authentication token.');
      }
      return firebaseIdToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const GoogleSignInCancelledException();
      }
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw const GoogleSignInConfigurationException(
          'Google sign-in is not configured for this app yet. Ensure Firebase is set up and the Google web client is available.',
        );
      }
      rethrow;
    }
  }

  Future<void> _ensureInitialized() async {
    final pending = _initialization ??= _initialize();
    try {
      await pending;
    } on Object {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    validateConfiguration(webClientId);
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    if (webClientId.isNotEmpty) {
      await GoogleSignIn.instance.initialize(serverClientId: webClientId);
    } else {
      await GoogleSignIn.instance.initialize();
    }
  }
}

class GoogleSignInConfigurationException implements Exception {
  const GoogleSignInConfigurationException([this.message = '']);

  final String message;

  @override
  String toString() =>
      message.isEmpty ? 'GoogleSignInConfigurationException' : message;
}

class GoogleSignInCancelledException implements Exception {
  const GoogleSignInCancelledException();
}
