import '../../domain/entities/session.dart';
import 'farm_model.dart';
import 'user_model.dart';

class LoginResponse {
  const LoginResponse({required this.accessToken, required this.refreshToken, required this.user, required this.farms});

  final String accessToken;
  final String refreshToken;
  final UserModel user;
  final List<FarmModel> farms;

  Session toEntity() => Session(accessToken: accessToken, refreshToken: refreshToken, user: user, farms: farms);

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        accessToken: '${json['access_token']}',
        refreshToken: '${json['refresh_token']}',
        user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
        farms: (json['farms'] as List<dynamic>? ?? []).map((item) => FarmModel.fromJson(item as Map<String, dynamic>)).toList(),
      );
}
