import '../client.dart';

class AuthEndpoints {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> register(String username, String password) async {
    return await _client.post('/api/auth/register',
        body: {'username': username, 'password': password}, auth: false);
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    return await _client.post('/api/auth/login',
        body: {'username': username, 'password': password}, auth: false);
  }

  Future<Map<String, dynamic>> me() async {
    return await _client.get('/api/auth/me');
  }
}
