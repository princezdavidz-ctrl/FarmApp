import 'package:dio/dio.dart';

import '../../../../core/errors/error_handler.dart';
import '../../../../security/authorization/permissions.dart';
import '../../../../security/authorization/roles.dart';
import '../domain/entities/farm_member.dart';

/// Talks to `farms/{farm}/members` so the farm owner can see who has access
/// to the farm and control the policies granted to farm managers/workers.
class FarmMembersApi {
  FarmMembersApi(this._dio);

  final Dio _dio;

  Future<List<FarmMember>> fetchMembers(String farmId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/members',
      );
      final data = response.data?['data'] as List<dynamic>? ?? [];
      return data
          .map((json) => _fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<FarmMember> updatePermissions(
    String farmId,
    String userId,
    Set<AppPermission> permissions,
  ) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/farms/$farmId/members/$userId',
        data: {
          'permissions': permissions
              .map((permission) => permission.name)
              .toList(),
        },
      );
      return _fromJson(response.data?['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> removeMember(String farmId, String userId) async {
    try {
      await _dio.delete<void>('/farms/$farmId/members/$userId');
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  FarmMember _fromJson(Map<String, dynamic> json) {
    final role = parseUserRole(json['role']);
    final overrides = json['permissions'] as List<dynamic>?;
    final permissions = overrides == null
        ? RolePermissions.all[role] ?? const <AppPermission>{}
        : <AppPermission>{
            for (final name in overrides)
              for (final permission in AppPermission.values)
                if (permission.name == name) permission,
          };
    return FarmMember(
      id: '${json['id']}',
      name: '${json['name'] ?? ''}',
      email: '${json['email'] ?? ''}',
      role: role,
      identityNumber: '${json['id']}',
      permissions: permissions,
    );
  }
}
