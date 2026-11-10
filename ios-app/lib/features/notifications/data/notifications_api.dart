import 'package:dio/dio.dart';

import '../../../core/errors/error_handler.dart';

class FarmNotification {
  const FarmNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.severity,
    required this.createdAt,
    this.readAt,
    this.actionRoute,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String severity;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? actionRoute;

  bool get isRead => readAt != null;

  factory FarmNotification.fromJson(Map<String, dynamic> json) =>
      FarmNotification(
        id: '${json['id']}',
        type: '${json['type'] ?? 'general'}',
        title: '${json['title'] ?? ''}'.replaceAll(
          'Farm App CRM',
          'Farm App Support',
        ),
        body: '${json['body'] ?? ''}',
        severity: '${json['severity'] ?? 'info'}',
        createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
        readAt: json['read_at'] == null
            ? null
            : DateTime.tryParse('${json['read_at']}'),
        actionRoute: json['action_route'] as String?,
      );
}

class NotificationsApi {
  NotificationsApi(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>?> fetchSupportConversation(String farmId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/support-conversation',
      );
      final data = response.data?['data'];
      return data is Map<String, dynamic> ? data : null;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return _fetchLegacySupportConversation(farmId);
      }
      throw ErrorHandler.from(error);
    }
  }

  Future<bool> fetchSupportPresence(String farmId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/support-presence',
      );
      return response.data?['data']?['online'] as bool? ?? false;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return false;
      throw ErrorHandler.from(error);
    }
  }

  Future<void> markSupportConversationRead(String farmId) async {
    try {
      await _dio.patch<void>('/farms/$farmId/support-conversation/read');
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        final conversation = await _fetchLegacySupportConversation(farmId);
        final messages =
            conversation?['messages'] as List<dynamic>? ?? const [];
        for (final message in messages.whereType<Map<String, dynamic>>()) {
          if (message['sender_role'] == 'crm') {
            await markAsRead(
              farmId: farmId,
              notificationId: '${message['id']}',
            );
          }
        }
        return;
      }
      throw ErrorHandler.from(error);
    }
  }

  Future<Map<String, dynamic>?> _fetchLegacySupportConversation(
    String farmId,
  ) async {
    final notifications = await fetch(farmId);
    final messages =
        notifications
            .where(
              (notification) =>
                  notification.type == 'crm_message' ||
                  notification.type == 'crm_message_sent',
            )
            .toList()
          ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    if (messages.isEmpty) return null;

    return {
      'id': 'legacy-$farmId',
      'farm_id': farmId,
      'status': 'open',
      'assigned_agent': null,
      'messages': messages
          .map(
            (message) => {
              'id': message.id,
              'sender_role': message.type == 'crm_message' ? 'crm' : 'app',
              'sender_name': message.type == 'crm_message'
                  ? (message.title.isEmpty ? 'Customer Support' : message.title)
                  : 'You',
              'body': message.body,
              'created_at': message.createdAt.toIso8601String(),
            },
          )
          .toList(),
    };
  }

  Future<List<FarmNotification>> fetch(String farmId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/notifications',
      );
      final data = response.data?['data'] as List<dynamic>? ?? [];
      return data
          .map(
            (item) => FarmNotification.fromJson(
              item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<FarmNotification> markAsRead({
    required String farmId,
    required String notificationId,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/farms/$farmId/notifications/$notificationId/read',
      );
      return FarmNotification.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<FarmNotification> sendMessage({
    required String farmId,
    required String message,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/farms/$farmId/support-conversation/messages',
        data: {'message': message},
      );
      return FarmNotification.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        try {
          final legacyResponse = await _dio.post<Map<String, dynamic>>(
            '/farms/$farmId/notifications/messages',
            data: {'message': message},
          );
          return FarmNotification.fromJson(
            legacyResponse.data!['data'] as Map<String, dynamic>,
          );
        } on DioException catch (legacyError) {
          throw ErrorHandler.from(legacyError);
        }
      }
      throw ErrorHandler.from(error);
    }
  }
}
