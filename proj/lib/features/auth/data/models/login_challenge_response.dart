class LoginChallengeResponse {
  const LoginChallengeResponse({
    required this.challengeId,
    required this.destination,
  });

  final String challengeId;
  final String destination;

  factory LoginChallengeResponse.fromJson(Map<String, dynamic> json) {
    if (json['otp_required'] != true || json['challenge_id'] is! String) {
      throw const FormatException('The login response did not include an OTP challenge.');
    }

    return LoginChallengeResponse(
      challengeId: json['challenge_id'] as String,
      destination: json['destination'] as String? ?? 'your registered email',
    );
  }
}
