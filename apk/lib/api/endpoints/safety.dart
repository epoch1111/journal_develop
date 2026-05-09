import '../client.dart';

class SafetyEndpoints {
  final ApiClient _client = ApiClient();

  Future<void> blockUser(int userId) async {
    await _client.post('/api/users/$userId/block');
  }

  Future<void> unblockUser(int userId) async {
    await _client.delete('/api/users/$userId/block');
  }

  Future<Map<String, dynamic>> getBlockStatus(int userId) async {
    return await _client.get('/api/users/$userId/block-status');
  }

  Future<Map<String, dynamic>> getBlockedUsers() async {
    return await _client.get('/api/me/blocked-users');
  }

  Future<Map<String, dynamic>> createReport({
    required String targetType,
    required int targetId,
    required String reason,
    String? description,
    int? targetUserId,
  }) async {
    final body = <String, dynamic>{
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
    };
    if (description != null && description.isNotEmpty) body['description'] = description;
    if (targetUserId != null) body['target_user_id'] = targetUserId;
    return await _client.post('/api/reports', body: body);
  }

  Future<Map<String, dynamic>> getMyReports() async {
    return await _client.get('/api/reports/my');
  }
}
