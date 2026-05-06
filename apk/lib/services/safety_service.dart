import '../models/user.dart';
import 'api_client.dart';

class SafetyService {
  final ApiClient _client = ApiClient();

  Future<void> blockUser(int userId) async {
    await _client.post('/api/users/$userId/block');
  }

  Future<void> unblockUser(int userId) async {
    await _client.delete('/api/users/$userId/block');
  }

  Future<Map<String, dynamic>> fetchBlockStatus(int userId) async {
    return await _client.get('/api/users/$userId/block-status');
  }

  Future<List<User>> fetchBlockedUsers() async {
    final data = await _client.get('/api/me/blocked-users');
    final list = data['data'] as List? ?? [];
    return list.map((u) => User.fromJson(u)).toList();
  }

  Future<void> createReport({
    required String reportType,
    required int targetId,
    required String reason,
  }) async {
    await _client.post('/api/reports', body: {
      'report_type': reportType,
      'target_id': targetId,
      'reason': reason,
    });
  }

  Future<List<Map<String, dynamic>>> fetchMyReports() async {
    final data = await _client.get('/api/reports/my');
    final list = data['data'] as List? ?? [];
    return list.map((r) => r as Map<String, dynamic>).toList();
  }
}
