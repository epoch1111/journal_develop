import '../models/user.dart';
import '../models/diary.dart';
import 'api_client.dart';

class FollowService {
  final ApiClient _client = ApiClient();

  Future<void> followUser(int userId) async {
    await _client.post('/api/users/$userId/follow');
  }

  Future<void> unfollowUser(int userId) async {
    await _client.delete('/api/users/$userId/follow');
  }

  Future<Map<String, dynamic>> fetchFollowStatus(int userId) async {
    return await _client.get('/api/users/$userId/follow-status', auth: false);
  }

  Future<List<User>> fetchFollowing() async {
    final data = await _client.get('/api/me/following');
    final list = data['data'] as List? ?? [];
    return list.map((u) => User.fromJson(u)).toList();
  }

  Future<List<User>> fetchFollowers() async {
    final data = await _client.get('/api/me/followers');
    final list = data['data'] as List? ?? [];
    return list.map((u) => User.fromJson(u)).toList();
  }

  Future<List<Diary>> fetchFollowingFeed({int page = 1}) async {
    final data = await _client.get('/api/me/following-feed',
        queryParams: {'page': page.toString()});
    final list = data['items'] as List? ?? [];
    return list.map((d) => Diary.fromJson(d)).toList();
  }
}
