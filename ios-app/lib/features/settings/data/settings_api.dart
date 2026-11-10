import 'package:dio/dio.dart';
import '../../../../core/errors/error_handler.dart';

/// API calls for user settings management.
class SettingsApi {
  SettingsApi(this._dio);

  final Dio _dio;

  Future<void> updateDisplayName(String name) async {
    try {
      await _dio.patch('/auth/profile', data: {'name': name});
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> renameFarm({
    required String farmId,
    required String name,
  }) async {
    try {
      await _dio.patch('/farms/$farmId', data: {'name': name});
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<Map<String, dynamic>> requestFarmNameChange({
    required String farmId,
    required String requestedName,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/farms/$farmId/name-change-requests',
        data: {'requested_name': requestedName},
      );
      return Map<String, dynamic>.from(response.data?['data'] as Map);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<List<Map<String, dynamic>>> farmNameChangeRequests(
    String farmId,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/name-change-requests',
      );
      return (response.data?['data'] as List<dynamic>? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<Map<String, dynamic>> updateFarmLocation({
    required String farmId,
    required String location,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/farms/$farmId',
        data: {
          'location': location,
          'latitude': latitude,
          'longitude': longitude,
        },
      );
      return Map<String, dynamic>.from(response.data?['data'] as Map);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  // Profile updates
  Future<void> updateProfile({
    required String farmId,
    String? farmName,
    String? farmLocation,
    String? phoneNumber,
    String? email,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (farmName != null) data['farm_name'] = farmName;
      if (farmLocation != null) data['location'] = farmLocation;
      if (phoneNumber != null) data['phone'] = phoneNumber;
      if (email != null) data['email'] = email;

      await _dio.patch('/farms/$farmId', data: data);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  // Change password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post(
        '/auth/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'new_password_confirmation': newPassword,
        },
      );
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> logoutAllSessions() async {
    try {
      await _dio.post<void>('/auth/logout-all');
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }
}
