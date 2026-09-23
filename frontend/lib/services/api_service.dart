import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final _storage = const FlutterSecureStorage();
  String _baseUrl = 'http://192.168.29.101:8000'; // Connect to laptop over WiFi
  
  set baseUrl(String url) => _baseUrl = url;

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final token = await _storage.read(key: 'jwt_token');

    return http.post(
      Uri.parse('$_baseUrl$endpoint'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
  }

  Future<http.Response> patch(String endpoint, Map<String, dynamic> body) async {
    final token = await _storage.read(key: 'jwt_token');

    return http.patch(
      Uri.parse('$_baseUrl$endpoint'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
  }

  Future<http.Response> delete(String endpoint) async {
    final token = await _storage.read(key: 'jwt_token');

    return http.delete(
      Uri.parse('$_baseUrl$endpoint'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  }

  Future<http.Response> get(String endpoint, {Map<String, String>? queryParameters}) async {
    final token = await _storage.read(key: 'jwt_token');

    final uri = Uri.parse('$_baseUrl$endpoint').replace(queryParameters: queryParameters);

    return http.get(
      uri,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  }

  Future<http.Response> updateStockKarat(String id, String newKarat, {String? reason}) {
    return post('/api/v1/stock/$id/karat', {
      'new_karat': newKarat,
      if (reason != null) 'reason': reason,
    });
  }

  Future<http.Response> updateStockVersion(String id, String newKarat, {String? reason}) {
    return post('/api/v1/stock/$id/version', {
      'new_karat': newKarat,
      if (reason != null) 'reason': reason,
    });
  }

  Future<http.Response> updateStockPrice(String id, String newPrice, {String? reason}) {
    return post('/api/v1/stock/$id/price', {
      'new_price_per_karat': newPrice,
      if (reason != null) 'reason': reason,
    });
  }

  Future<http.Response> getStockReport({
    String? stockCategory,
    String? stockType,
    String? productTag,
    String? stockTag,
  }) {
    final queryParams = <String, String>{};
    if (stockCategory != null && stockCategory.toUpperCase() != 'ALL') queryParams['stock_category'] = stockCategory;
    if (stockType != null && stockType.toUpperCase() != 'ALL') queryParams['stock_type'] = stockType;
    if (productTag != null && productTag.toUpperCase() != 'ALL') queryParams['product_tag'] = productTag;
    if (stockTag != null) queryParams['stock_tag'] = stockTag;
    
    final uri = Uri(path: '/api/v1/reports/stock', queryParameters: queryParams.isNotEmpty ? queryParams : null);
    return get(uri.toString());
  }

  Future<http.Response> getRejectionReport({
    String? stockCategory,
    String? stockType,
    String? productTag,
    String? stockTag,
  }) {
    final queryParams = <String, String>{};
    if (stockCategory != null && stockCategory.toUpperCase() != 'ALL') queryParams['stock_category'] = stockCategory;
    if (stockType != null && stockType.toUpperCase() != 'ALL') queryParams['stock_type'] = stockType;
    if (productTag != null && productTag.toUpperCase() != 'ALL') queryParams['product_tag'] = productTag;
    if (stockTag != null) queryParams['stock_tag'] = stockTag;
    
    final uri = Uri(path: '/api/v1/reports/rejection', queryParameters: queryParams.isNotEmpty ? queryParams : null);
    return get(uri.toString());
  }

  Future<http.Response> getStockHistory(String id) {
    return get('/api/v1/stock/$id/history');
  }

  Future<http.Response> getStock(String id) {
    return get('/api/v1/stock/$id');
  }

  Future<http.Response> getDailyHistory(String date) {
    return get('/api/v1/stock/history', queryParameters: {'date': date});
  }

  Future<http.Response> getLogs() {
    return get('/api/v1/stock/logs');
  }
}

final apiService = ApiService();
