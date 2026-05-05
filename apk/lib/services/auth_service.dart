import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> register(
      String username, String password) async {
    final data = await _client.post('/api/auth/register',
        body: {'username': username, 'password': password}, auth: false);
    if (data['access_token'] != null) {
      await _client.setToken(data['access_token']);
    }
    return data;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final data = await _client.post('/api/auth/login',
        body: {'username': username, 'password': password}, auth: false);
    if (data['access_token'] != null) {
      await _client.setToken(data['access_token']);
    }
    return data;
  }

  Future<User> fetchCurrentUser() async {
    final data = await _client.get('/api/auth/me');
    return User.fromJson(data);
  }

  Future<void> logout() async {
    await _client.setToken(null);
  }

  bool get isLoggedIn => _client.token != null;
}
