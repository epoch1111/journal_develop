import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show File;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart' as dio;

/// 统一 HTTP 客户端。所有 API 调用都经过这里。
///
/// 响应格式约定：
/// - 单条对象：直接返回 Map
/// - 列表（无分页）：统一包装为 {'data': [...]}
/// - 分页列表：{'items': [...], 'has_more': bool, 'total': int}
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  http.Client _httpClient;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _baseUrl;
  String? _token;

  /// Override the HTTP client for testing.
  static void injectHttpClient(http.Client? client) {
    _instance._httpClient = client ?? http.Client();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('server_url') ?? 'http://10.0.2.2:8000';
    _token = await _secureStorage.read(key: 'echo_token');
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url);
  }

  String get baseUrl => _baseUrl ?? 'http://10.0.2.2:8000';

  Future<void> setToken(String? token) async {
    _token = token;
    if (token != null) {
      await _secureStorage.write(key: 'echo_token', value: token);
    } else {
      await _secureStorage.delete(key: 'echo_token');
    }
  }

  String? get token => _token;

  Map<String, String> _headers({bool auth = true}) {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth && _token != null) {
      h['Authorization'] = 'Bearer $_token';
    }
    return h;
  }

  Future<Map<String, dynamic>> get(String path,
      {bool auth = true, Map<String, String>? queryParams}) async {
    var uri = Uri.parse('$baseUrl$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    final response = await _httpClient.get(uri, headers: _headers(auth: auth));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _httpClient.post(uri,
        headers: _headers(auth: auth),
        body: body != null ? jsonEncode(body) : null);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _httpClient.put(uri,
        headers: _headers(auth: auth),
        body: body != null ? jsonEncode(body) : null);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(String path, {bool auth = true}) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _httpClient.delete(uri, headers: _headers(auth: auth));
    return _handleResponse(response);
  }

  /// 上传文件：使用 dio（比 http 库的 MultipartFile 更可靠）。
  /// 参考 Web 端 fetch + FormData 的上传方式。
  Future<Map<String, dynamic>> uploadFile(String path, String filePath,
      {String filename = 'image.jpg',
      String mime = 'image/jpeg',
      String fieldName = 'file'}) async {
    final d = dio.Dio();
    d.options.connectTimeout = const Duration(seconds: 30);
    d.options.receiveTimeout = const Duration(seconds: 30);
    d.options.sendTimeout = const Duration(seconds: 60);

    final formData = dio.FormData.fromMap({
      fieldName: dio.MultipartFile.fromFileSync(filePath,
          filename: filename, contentType: dio.DioMediaType.parse(mime)),
    });

    final options = dio.Options(
      method: 'POST',
      headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    );

    final fullUrl = '$baseUrl$path';
    final response = await d.post(fullUrl, data: formData, options: options);

    if (response.data is Map) {
      return response.data as Map<String, dynamic>;
    }
    return {'ok': true};
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      _token = null;
      _secureStorage.delete(key: 'echo_token');
      throw AuthException('登录已过期，请重新登录');
    }
    if (response.statusCode >= 400) {
      String message = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          message = (decoded['detail'] ?? decoded['message'] ?? response.body).toString();
        }
      } catch (_) {}
      throw ApiException(message);
    }
    if (response.body.isEmpty) return {'ok': true};
    final decoded = jsonDecode(response.body);
    // 列表统一包装，方便服务层统一解析
    if (decoded is List) return {'data': decoded};
    return decoded as Map<String, dynamic>;
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}
