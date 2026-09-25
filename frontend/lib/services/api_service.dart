import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  final _storage = const FlutterSecureStorage();
  String _customBaseUrl = '';
  
  set baseUrl(String url) => _customBaseUrl = url;

  /// Returns the production API Base URL from .env or fallback
  String get baseUrl {
    if (_customBaseUrl.isNotEmpty) {
      String url = _customBaseUrl.trim();
      if (url.endsWith('/')) url = url.substring(0, url.length - 1);
      return url;
    }
    final envUrl = dotenv.env['API_BASE_URL'];
    if (envUrl != null && envUrl.trim().isNotEmpty) {
      String url = envUrl.trim();
      if (url.endsWith('/')) url = url.substring(0, url.length - 1);
      return url;
    }
    return 'https://sp-ddc-cd.onrender.com';
  }

  /// Checks lightweight GET /health endpoint to verify backend connectivity
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && body['status'] == 'ok') {
          return true;
        }
      }
      // Non-500 HTTP responses mean the server is running & reachable
      if (response.statusCode < 500) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Helper wrapper that executes HTTP requests and handles network/socket exceptions
  Future<http.Response> _safeRequest(Future<http.Response> Function() req) async {
    try {
      final response = await req().timeout(const Duration(seconds: 60));
      debugPrint('ApiService [${response.statusCode}]: ${response.request?.url}');
      return response;
    } on SocketException catch (e) {
      debugPrint('ApiService SocketException: $e');
      throw Exception('Network Connectivity Error: No internet or Wi-Fi connection. Please check your network settings.');
    } on TimeoutException catch (e) {
      debugPrint('ApiService TimeoutException: $e');
      throw Exception('Network Error: Connection timed out. Server is taking too long to respond. Please retry.');
    } on http.ClientException catch (e) {
      debugPrint('ApiService ClientException: $e');
      throw Exception('Network Error: Cannot connect to server. Please ensure Wi-Fi or network connection is active.');
    } catch (e) {
      debugPrint('ApiService Exception (${e.runtimeType}): $e');
      final str = e.toString().toLowerCase();
      if (str.contains('socketexception') || 
          str.contains('connection refused') || 
          str.contains('clientexception') ||
          str.contains('network is unreachable')) {
        throw Exception('Network Connectivity Error: Unable to reach server. Please verify Wi-Fi/Internet connection.');
      }
      rethrow;
    }
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final token = await _storage.read(key: 'jwt_token');

    return _safeRequest(() => http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    ));
  }

  Future<http.Response> patch(String endpoint, Map<String, dynamic> body) async {
    final token = await _storage.read(key: 'jwt_token');

    return _safeRequest(() => http.patch(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    ));
  }

  Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
    final token = await _storage.read(key: 'jwt_token');

    return _safeRequest(() => http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    ));
  }

  Future<http.Response> delete(String endpoint) async {
    final token = await _storage.read(key: 'jwt_token');

    return _safeRequest(() => http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ));
  }

  Future<http.Response> get(String endpoint, {Map<String, String>? queryParameters}) async {
    final token = await _storage.read(key: 'jwt_token');
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParameters);

    return _safeRequest(() => http.get(
      uri,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ));
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

  Future<http.Response> reorderStocks(List<String> stockIds) {
    return put('/api/v1/stock/reorder', {
      'stock_ids': stockIds,
    });
  }

  Future<http.Response> deleteStock(String id) {
    return delete('/api/v1/stock/$id');
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

  /// Converts any exception or http response into clean, user-friendly natural language message
  static String extractErrorMessage(dynamic input) {
    if (input is http.Response) {
      try {
        final data = jsonDecode(input.body);
        if (data is Map && data.containsKey('detail')) {
          final detail = data['detail'];
          if (detail is String) return detail;
          if (detail is List && detail.isNotEmpty) {
            final first = detail[0];
            if (first is Map && first.containsKey('msg')) return first['msg'].toString();
          }
        }
      } catch (_) {}
      if (input.statusCode == 401) return 'Session expired or invalid credentials. Please log in again.';
      if (input.statusCode == 403) return 'Access denied. You do not have permission to perform this action.';
      if (input.statusCode == 404) return 'Requested item or server endpoint not found.';
      if (input.statusCode >= 500) return 'Server error (${input.statusCode}). Please try again later.';
      return 'Request failed (${input.statusCode}).';
    }

    String msg = input.toString();
    if (msg.contains('Exception: ')) {
      msg = msg.replaceAll('Exception: ', '');
    }
    final lower = msg.toLowerCase();
    if (lower.contains('socketexception') || lower.contains('connection refused') || lower.contains('clientexception') || lower.contains('network is unreachable')) {
      return 'Network Connectivity Error: No internet or Wi-Fi connection. Please check network settings.';
    }
    return msg;
  }
}

final apiService = ApiService();
