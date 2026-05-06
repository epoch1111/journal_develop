import '../models/user.dart';
import 'api_client.dart';

class ProfileService {
  final ApiClient _client = ApiClient();

  Future<User> fetchMyProfile() async {
    final data = await _client.get('/api/profile/me');
    // 后端返回 {"ok": true, "user": {...}}
    final userData = data['user'] ?? data;
    return User.fromJson(Map<String, dynamic>.from(userData));
  }

  Future<Map<String, dynamic>> updateProfile({
    String? nickname,
    String? avatar,
    String? bio,
    String? interests,
  }) async {
    final body = <String, dynamic>{};
    if (nickname != null) body['nickname'] = nickname;
    if (avatar != null) body['avatar'] = avatar;
    if (bio != null) body['bio'] = bio;
    if (interests != null) body['interests'] = interests;
    return await _client.put('/api/profile/me', body: body);
  }

  Future<User> fetchUserProfile(int userId) async {
    final data = await _client.get('/api/profile/$userId', auth: false);
    // 后端返回 {"ok": true, ...} 或直接用户dict
    final userData = data['user'] ?? data;
    return User.fromJson(Map<String, dynamic>.from(userData));
  }
}
