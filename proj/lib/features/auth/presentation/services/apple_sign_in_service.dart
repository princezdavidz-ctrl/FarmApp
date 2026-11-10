import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AppleSignInService {
  AppleSignInService({FirebaseAuth? firebaseAuth})
    : _providedFirebaseAuth = firebaseAuth;

  final FirebaseAuth? _providedFirebaseAuth;

  Future<String> signIn() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      final firebaseAuth = _providedFirebaseAuth ?? FirebaseAuth.instance;
      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      final userCredential = await firebaseAuth.signInWithProvider(provider);
      final token = await userCredential.user?.getIdToken();
      if (token == null || token.isEmpty) {
        throw const AppleSignInConfigurationException(
          'Apple sign-in did not return a Firebase ID token.',
        );
      }
      return token;
    } on FirebaseAuthException catch (error) {
      if (const {
        'web-context-cancelled',
        'user-cancelled',
        'canceled',
      }.contains(error.code)) {
        throw const AppleSignInCancelledException();
      }
      if (error.code == 'operation-not-allowed' ||
          error.code == 'missing-client-identifier') {
        throw const AppleSignInConfigurationException(
          'Enable Apple sign-in in Firebase Authentication and the iOS app capability.',
        );
      }
      rethrow;
    }
  }
}

class AppleSignInConfigurationException implements Exception {
  const AppleSignInConfigurationException(this.message);

  final String message;
}

class AppleSignInCancelledException implements Exception {
  const AppleSignInCancelledException();
}
