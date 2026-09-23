import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await apiService.post('/api/v1/auth/login', {
      'email': email,
      'password': password,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['access_token'];
      if (token != null) {
        await _storage.write(key: 'jwt_token', value: token);
        await _storage.write(key: 'login_time', value: DateTime.now().toIso8601String());
      }
      return data['user'];
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to login');
    }
  }

  Future<void> logout() async {
    try {
      await apiService.post('/api/v1/auth/logout', {});
    } catch (_) {}
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'login_time');
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) return null;

    final loginTimeStr = await _storage.read(key: 'login_time');
    if (loginTimeStr != null) {
      final loginTime = DateTime.tryParse(loginTimeStr);
      if (loginTime != null) {
        final elapsed = DateTime.now().difference(loginTime);
        if (elapsed.inDays >= 14) {
          await logout();
          return null;
        }
      }
    }

    final response = await apiService.get('/api/v1/auth/me');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      await _storage.delete(key: 'jwt_token');
      return null;
    }
  }
}

final authService = AuthService();
