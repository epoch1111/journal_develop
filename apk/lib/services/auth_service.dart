import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> register(
      String username, String password) async {
    final data = await _client.post('/api/auth/register',
        body: {'username': username, 'password': password}, auth: false);
    final token = data['access_token'] ?? data['token'];
    if (token != null) {
      await _client.setToken(token.toString());
    }
    return data;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final data = await _client.post('/api/auth/login',
        body: {'username': username, 'password': password}, auth: false);
    final token = data['access_token'] ?? data['token'];
    if (token != null) {
      await _client.setToken(token.toString());
    }
    return data;
  }

  Future<User> fetchCurrentUser() async {
    final data = await _client.get('/api/auth/me');
    // 后端返回 {"ok": true, "user": {...}} 或直接用户dict
    final userData = data['user'] ?? data;
    return User.fromJson(Map<String, dynamic>.from(userData));
  }

  Future<void> logout() async {
    await _client.setToken(null);
  }

  bool get isLoggedIn => _client.token != null;
}
