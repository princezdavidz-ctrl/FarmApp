import 'package:dio/dio.dart';

import '../../../../core/errors/error_handler.dart';
import '../../../../security/authorization/roles.dart';
import '../../auth/data/models/farm_model.dart';
import '../domain/entities/farm_join_request.dart';

class FarmTeamApi {
  FarmTeamApi(this._dio);

  final Dio _dio;

  Future<FarmJoinRequest> requestToJoin({
    required String inviteCode,
    String? message,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/farm-join-requests',
        data: {
          'invite_code': inviteCode,
          if (message?.trim().isNotEmpty ?? false) 'message': message!.trim(),
        },
      );
      return _fromJson(response.data!['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<List<FarmJoinRequest>> fetchMyRequests() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/auth/join-requests',
      );
      return _listFrom(response.data);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<List<FarmJoinRequest>> fetchFarmRequests(String farmId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/join-requests',
      );
      return _listFrom(response.data);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<FarmJoinRequest> reviewRequest({
    required String farmId,
    required String requestId,
    required bool accept,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/farms/$farmId/join-requests/$requestId',
        data: {'action': accept ? 'accept' : 'reject'},
      );
      return _fromJson(response.data!['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<FarmModel> createFarm(
    String name, {
    String? location,
    String farmingType = 'mixed',
    List<String> productionTypes = const [],
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/farms',
        data: {
          'name': name,
          if (location?.trim().isNotEmpty ?? false)
            'location': location!.trim(),
          'farming_type': farmingType,
          'production_types': productionTypes,
        },
      );
      return FarmModel.fromJson(response.data!['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  List<FarmJoinRequest> _listFrom(Map<String, dynamic>? data) =>
      (data?['data'] as List<dynamic>? ?? [])
          .map((item) => _fromJson(item as Map<String, dynamic>))
          .toList();

  FarmJoinRequest _fromJson(Map<String, dynamic> json) {
    final role = parseUserRole(json['requestedRole']);
    return FarmJoinRequest(
      id: '${json['id']}',
      farmId: '${json['farmId']}',
      farmName: json['farmName'] as String?,
      userId: '${json['userId']}',
      userName: json['userName'] as String?,
      userEmail: json['userEmail'] as String?,
      requestedRole: role,
      status: '${json['status'] ?? 'pending'}',
      message: json['message'] as String?,
      createdAt: DateTime.tryParse('${json['createdAt']}'),
    );
  }
}
