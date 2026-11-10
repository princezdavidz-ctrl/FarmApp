import 'package:flutter_test/flutter_test.dart';
import 'package:proj/features/auth/data/models/login_request.dart';
import 'package:proj/features/auth/data/models/login_response.dart';
import 'package:proj/features/auth/data/models/register_request.dart';
import 'package:proj/security/authorization/roles.dart';

void main() {
  test('login sends the shared identifier contract', () {
    expect(
      const LoginRequest(
        identifier: '+15551234567',
        password: 'password123',
        rememberMe: true,
      ).toJson(),
      {
        'identifier': '+15551234567',
        'password': 'password123',
        'remember_me': true,
      },
    );
  });

  test('owner registration sends phone and owner setup', () {
    final payload = RegisterRequest(
      name: 'Owner',
      email: 'owner@example.com',
      phone: '+15551234567',
      password: 'password123',
      role: UserRole.farmOwner,
      farmName: 'Green Valley Farm',
      motherPigCount: 12,
    ).toJson();

    expect(payload['phone'], '+15551234567');
    expect(payload['farm_name'], 'Green Valley Farm');
    expect(payload['mother_pig_count'], 12);
    expect(payload['password_confirmation'], 'password123');
  });

  test('session response preserves phone, farms, and invite code', () {
    final response = LoginResponse.fromJson({
      'access_token': 'access',
      'refresh_token': 'refresh',
      'user': {
        'id': 1,
        'name': 'Owner',
        'email': 'owner@example.com',
        'phone': '+15551234567',
        'role': 'farmOwner',
      },
      'farms': [
        {'id': 2, 'name': 'Farm', 'invite_code': 'ABCD1234'},
      ],
    });

    expect(response.user.phone, '+15551234567');
    expect(response.farms.single.inviteCode, 'ABCD1234');
    expect(response.toEntity().farms.single.name, 'Farm');
  });
}
