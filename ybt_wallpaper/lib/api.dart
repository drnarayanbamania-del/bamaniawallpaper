import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

/// YBT Wallpaper — All API calls in one file.
/// Auto-attaches JWT. Global 401 handler triggers logout callback.

class Api {
  static VoidCallback? onUnauthorized;

  // ── Token Management ──────────────────────────
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static Future<bool> hasToken() async {
    final token = await _getToken();
    return token != null && token.isNotEmpty;
  }

  // ── HTTP Helper ───────────────────────────────
  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> _handleResponse(
      http.Response response) async {
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 401) {
      await clearToken();
      onUnauthorized?.call();
      throw ApiException('Session expired. Please login again.');
    }

    if (response.statusCode >= 400) {
      throw ApiException(data['error'] ?? 'Request failed');
    }

    return data;
  }

  // ── Auth ──────────────────────────────────────
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final response = await http.post(
      Uri.parse('${Config.baseUrl}/api/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'confirm_password': confirmPassword,
      }),
    );
    final data = await _handleResponse(response);
    if (data['token'] != null) {
      await saveToken(data['token']);
    }
    return data;
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${Config.baseUrl}/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    final data = await _handleResponse(response);
    if (data['token'] != null) {
      await saveToken(data['token']);
    }
    return data;
  }

  static Future<Map<String, dynamic>> getMe() async {
    final response = await http.get(
      Uri.parse('${Config.baseUrl}/api/me'),
      headers: await _headers(),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updateMe(String name) async {
    final response = await http.patch(
      Uri.parse('${Config.baseUrl}/api/me'),
      headers: await _headers(),
      body: jsonEncode({'name': name}),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updateMeToPro() async {
    final response = await http.post(
      Uri.parse('${Config.baseUrl}/api/me/upgrade'),
      headers: await _headers(),
    );
    return _handleResponse(response);
  }

  // ── Wallpapers ────────────────────────────────
  static Future<Map<String, dynamic>> getWallpapers({
    int page = 1,
    int? categoryId,
    String? search,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': Config.paginationLimit.toString(),
    };
    if (categoryId != null) params['category_id'] = categoryId.toString();
    if (search != null && search.isNotEmpty) params['search'] = search;

    final uri = Uri.parse('${Config.baseUrl}/api/wallpapers')
        .replace(queryParameters: params);

    final response = await http.get(uri, headers: await _headers());
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> getWallpaper(int id) async {
    final response = await http.get(
      Uri.parse('${Config.baseUrl}/api/wallpapers/$id'),
      headers: await _headers(),
    );
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> downloadWallpaper(int id) async {
    final response = await http.post(
      Uri.parse('${Config.baseUrl}/api/wallpapers/$id/download'),
      headers: await _headers(),
    );
    return _handleResponse(response);
  }

  // ── Categories ────────────────────────────────
  static Future<Map<String, dynamic>> getCategories() async {
    final response = await http.get(
      Uri.parse('${Config.baseUrl}/api/categories'),
      headers: await _headers(),
    );
    return _handleResponse(response);
  }
}

/// Custom exception for API errors.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

/// Typedef for void callbacks (avoiding dart:ui import).
typedef VoidCallback = void Function();
