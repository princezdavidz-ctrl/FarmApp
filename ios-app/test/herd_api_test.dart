import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/features/herd/data/herd_api.dart';

void main() {
  test('animal updates omit absent non-nullable fields', () async {
    Map<String, dynamic>? sentData;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com/api/v1'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sentData = Map<String, dynamic>.from(options.data as Map);
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': {
                    'id': '1',
                    'tag': 'PIG-1',
                    'type': 'sow',
                    'sex': 'female',
                    'status': 'active',
                  },
                },
              ),
            );
          },
        ),
      );

    await HerdApi(dio).updateAnimal(farmId: '25', animalId: '102');

    expect(sentData, isNot(contains('tag')));
    expect(sentData, isNot(contains('status')));
    expect(sentData, isNot(contains('sex')));
    expect(sentData, isNot(contains('is_pregnant')));
  });

  test(
    'animal image update uploads multipart data and resolves image URL',
    () async {
      final imageBytes = Uint8List.fromList([1, 2, 3, 4]);
      RequestOptions? request;
      FormData? formData;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com/api/v1'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              request = options;
              formData = options.data as FormData;
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'data': {
                      'id': '102',
                      'tag': 'PIG-102',
                      'type': 'sow',
                      'sex': 'female',
                      'status': 'active',
                      'image_url':
                          'http://localhost:8000/storage/animal-images/pig.jpg',
                    },
                  },
                ),
              );
            },
          ),
        );

      final animal = await HerdApi(dio).updateAnimal(
        farmId: '25',
        animalId: '102',
        tag: 'PIG-102',
        status: 'active',
        isPregnant: false,
        imageBytes: imageBytes,
        imageName: 'pig.jpg',
      );

      expect(request?.method, 'POST');
      expect(request?.path, '/farms/25/animals/102');
      expect(
        formData?.fields.any(
          (field) => field.key == '_method' && field.value == 'PATCH',
        ),
        isTrue,
      );
      expect(
        formData?.fields.any(
          (field) => field.key == 'tag' && field.value == 'PIG-102',
        ),
        isTrue,
      );
      expect(
        formData?.fields.any(
          (field) => field.key == 'status' && field.value == 'active',
        ),
        isTrue,
      );
      expect(
        formData?.fields.any(
          (field) => field.key == 'is_pregnant' && field.value == '0',
        ),
        isTrue,
      );
      expect(formData?.files, hasLength(1));
      expect(formData?.files.single.key, 'image');
      expect(formData?.files.single.value.filename, 'pig.jpg');
      expect(formData?.files.single.value.length, imageBytes.length);
      expect(
        animal.imageUrl,
        'https://api.example.com/storage/animal-images/pig.jpg',
      );
    },
  );
}
