import '../client.dart';

class NotificationEndpoints {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> getNotifications({int page = 1, bool unreadOnly = false}) async {
    final params = <String, String>{'page': page.toString()};
    if (unreadOnly) params['unread_only'] = 'true';
    return await _client.get('/api/notifications', queryParams: params);
  }

  Future<Map<String, dynamic>> getUnreadCount() async {
    return await _client.get('/api/notifications/unread-count');
  }

  Future<Map<String, dynamic>> markRead(int id) async {
    return await _client.post('/api/notifications/$id/read');
  }

  Future<Map<String, dynamic>> markAllRead() async {
    return await _client.post('/api/notifications/read-all');
  }

  Future<Map<String, dynamic>> delete(int id) async {
    return await _client.delete('/api/notifications/$id');
  }
}
