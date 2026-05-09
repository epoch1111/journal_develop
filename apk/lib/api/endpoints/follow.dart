import '../client.dart';

class FollowEndpoints {
  final ApiClient _client = ApiClient();

  Future<void> follow(int userId) async {
    await _client.post('/api/users/$userId/follow');
  }

  Future<void> unfollow(int userId) async {
    await _client.delete('/api/users/$userId/follow');
  }

  Future<Map<String, dynamic>> getFollowStatus(int userId) async {
    return await _client.get('/api/users/$userId/follow-status', auth: false);
  }

  Future<Map<String, dynamic>> getFollowing() async {
    return await _client.get('/api/me/following');
  }

  Future<Map<String, dynamic>> getFollowers() async {
    return await _client.get('/api/me/followers');
  }

  Future<Map<String, dynamic>> getFollowingFeed({int page = 1}) async {
    return await _client.get('/api/me/following-feed',
        queryParams: {'page': page.toString()});
  }
}
