import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'storage_service.dart';

class TrackingApiService {
  String get _baseUrl => AppConfig.apiBaseUrl;
  
  Map<String, String> _getHeaders() {
    final token = storageService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> getTrackedItems() async {
    final token = storageService.getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/track'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> addTrackedItem(String productId, {double? targetPrice}) async {
    final token = storageService.getToken();
    if (token == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/track'),
        headers: _getHeaders(),
        body: jsonEncode({
          'product_id': productId,
          'target_price': targetPrice,
        }),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateTargetPrice(String productId, double? targetPrice) async {
    final token = storageService.getToken();
    if (token == null) return false;

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/track/$productId/target'),
        headers: _getHeaders(),
        body: jsonEncode({
          'target_price': targetPrice,
        }),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeTrackedItem(String productId) async {
    final token = storageService.getToken();
    if (token == null) return false;

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/track/$productId'),
        headers: _getHeaders(),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

final trackingApiService = TrackingApiService();
