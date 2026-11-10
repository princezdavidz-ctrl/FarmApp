import 'package:flutter_test/flutter_test.dart';
import 'package:proj/features/auth/data/models/login_challenge_response.dart';

void main() {
  group('LoginChallengeResponse', () {
    test('parses challenge details and defaults destination', () {
      final challenge = LoginChallengeResponse.fromJson({
        'otp_required': true,
        'challenge_id': 'challenge-123',
      });

      expect(challenge.challengeId, 'challenge-123');
      expect(challenge.destination, 'your registered email');
    });

    test('parses a masked delivery destination', () {
      final challenge = LoginChallengeResponse.fromJson({
        'otp_required': true,
        'challenge_id': 'challenge-123',
        'destination': 'm***@example.com',
      });

      expect(challenge.destination, 'm***@example.com');
    });

    test('rejects responses without a valid OTP challenge', () {
      expect(
        () => LoginChallengeResponse.fromJson({
          'otp_required': false,
          'challenge_id': 'challenge-123',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}