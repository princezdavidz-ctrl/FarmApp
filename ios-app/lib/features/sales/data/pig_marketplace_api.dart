import 'package:dio/dio.dart';

import '../../../../core/errors/error_handler.dart';
import '../../../../core/network/api_asset_url.dart';
import 'pig_listing.dart';

class PigMarketplaceApi {
  PigMarketplaceApi(this._dio);

  final Dio _dio;

  Future<List<PigListing>> fetchFarmListings(String farmId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/farms/$farmId/pig-listings',
      );
      final rows = response.data?['data'] as List<dynamic>? ?? const [];
      return rows
          .map((row) => _parseListing(row as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> createListing(String farmId, Map<String, dynamic> data) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/farms/$farmId/pig-listings',
        data: data,
      );
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> updateListingStatus(
    String farmId,
    String listingId,
    String status,
  ) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/farms/$farmId/pig-listings/$listingId',
        data: {'status': status},
      );
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  Future<void> updateInquiryStatus(
    String farmId,
    String listingId,
    String inquiryId,
    String status,
  ) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/farms/$farmId/pig-listings/$listingId/inquiries/$inquiryId',
        data: {'status': status},
      );
    } on DioException catch (error) {
      throw ErrorHandler.from(error);
    }
  }

  PigListing _parseListing(Map<String, dynamic> json) => PigListing.fromJson({
    ...json,
    'image_url': resolveApiAssetUrl(
      json['image_url'] as String?,
      apiBaseUrl: _dio.options.baseUrl,
    ),
  });
}
