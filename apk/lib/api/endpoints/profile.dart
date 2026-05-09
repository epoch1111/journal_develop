import '../client.dart';

class ProfileEndpoints {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> getMyProfile() async {
    return await _client.get('/api/profile/me');
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    return await _client.put('/api/profile/me', body: data);
  }

  Future<Map<String, dynamic>> getUserProfile(int userId) async {
    return await _client.get('/api/profile/$userId', auth: false);
  }
}
