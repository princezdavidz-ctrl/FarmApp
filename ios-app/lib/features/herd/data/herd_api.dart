import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/errors/error_handler.dart';
import '../../../../core/network/api_asset_url.dart';
import '../domain/entities/animal.dart';

class HerdApi {
  HerdApi(this._dio);

  final Dio _dio;

  Future<List<Animal>> fetchAnimals(String farmId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/animals',
      );
      final data = response.data?['data'] as List<dynamic>? ?? [];
      return data
          .map((item) => _parseAnimal(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<Animal> createAnimal({
    required String farmId,
    required String tag,
    required String type,
    required String sex,
    DateTime? birthDate,
    double? weightKg,
    bool isPregnant = false,
    String? notes,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    try {
      final trimmedNotes = notes?.trim();
      final data = {
        'tag': tag,
        'type': type,
        'sex': sex,
        'birth_date': ?birthDate?.toIso8601String().split('T').first,
        'weight_kg': ?weightKg,
        'is_pregnant': isPregnant,
        'notes': ?(trimmedNotes?.isNotEmpty == true ? trimmedNotes : null),
      };
      final response = imageBytes == null
          ? await _dio.post<Map<String, dynamic>>(
              '/farms/$farmId/animals',
              data: data,
            )
          : await _dio.post<Map<String, dynamic>>(
              '/farms/$farmId/animals',
              data: FormData.fromMap({
                ...data,
                'is_pregnant': isPregnant ? '1' : '0',
                'image': MultipartFile.fromBytes(
                  imageBytes,
                  filename: imageName ?? 'animal.jpg',
                ),
              }),
              options: Options(contentType: 'multipart/form-data'),
            );
      return _parseAnimal(response.data?['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<Animal> fetchAnimal({
    required String farmId,
    required String animalId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/animals/$animalId',
      );
      return _parseAnimal(response.data?['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<Animal> updateAnimal({
    required String farmId,
    required String animalId,
    String? tag,
    String? status,
    DateTime? birthDate,
    double? weightKg,
    bool? isPregnant,
    String? notes,
    Uint8List? imageBytes,
    String? imageName,
  }) async {
    try {
      final data = {
        if (tag != null) 'tag': tag.trim(),
        if (status != null) 'status': status,
        'birth_date': birthDate?.toIso8601String().split('T').first,
        'weight_kg': weightKg,
        'is_pregnant': ?isPregnant,
        'notes': notes?.trim(),
      };
      final response = imageBytes == null
          ? await _dio.patch<Map<String, dynamic>>(
              '/farms/$farmId/animals/$animalId',
              data: data,
            )
          : await _dio.post<Map<String, dynamic>>(
              '/farms/$farmId/animals/$animalId',
              data: FormData.fromMap({
                ...data,
                if (isPregnant != null) 'is_pregnant': isPregnant ? '1' : '0',
                '_method': 'PATCH',
                'image': MultipartFile.fromBytes(
                  imageBytes,
                  filename: imageName ?? 'animal.jpg',
                ),
              }),
              options: Options(contentType: 'multipart/form-data'),
            );
      return _parseAnimal(response.data?['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<Animal> archiveAnimal({
    required String farmId,
    required String animalId,
  }) async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        '/farms/$farmId/animals/$animalId',
      );
      return _parseAnimal(response.data?['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Animal _parseAnimal(Map<String, dynamic> json) => Animal.fromJson({
    ...json,
    'image_url': resolveApiAssetUrl(
      json['image_url'] as String?,
      apiBaseUrl: _dio.options.baseUrl,
    ),
  });
}
