import '../models/user.dart';
import 'api_client.dart';

class ProfileService {
  final ApiClient _client = ApiClient();

  Future<User> fetchMyProfile() async {
    final data = await _client.get('/api/profile/me');
    return User.fromJson(data);
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
    return User.fromJson(data);
  }
}
