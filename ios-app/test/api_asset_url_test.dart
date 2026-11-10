import 'package:flutter_test/flutter_test.dart';
import 'package:proj/core/network/api_asset_url.dart';

void main() {
  test('resolves a relative storage path at the API origin', () {
    expect(
      resolveApiAssetUrl(
        '/storage/animal-images/pig.jpg',
        apiBaseUrl: 'https://api.example.com/api/v1',
      ),
      'https://api.example.com/storage/animal-images/pig.jpg',
    );
  });

  test('replaces backend localhost URLs with the configured API origin', () {
    expect(
      resolveApiAssetUrl(
        'http://localhost:8000/storage/animal-images/pig.jpg',
        apiBaseUrl: 'https://api.example.com/api/v1',
      ),
      'https://api.example.com/storage/animal-images/pig.jpg',
    );
  });

  test(
    'preserves absolute public image URLs and treats empty URLs as absent',
    () {
      expect(
        resolveApiAssetUrl(
          'https://cdn.example.com/pig.jpg',
          apiBaseUrl: 'https://api.example.com/api/v1',
        ),
        'https://cdn.example.com/pig.jpg',
      );
      expect(
        resolveApiAssetUrl(' ', apiBaseUrl: 'https://api.example.com/api/v1'),
        isNull,
      );
    },
  );
}
