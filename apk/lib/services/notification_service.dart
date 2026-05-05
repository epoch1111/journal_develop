import '../models/notification.dart';
import 'api_client.dart';

class NotificationService {
  final ApiClient _client = ApiClient();

  Future<List<AppNotification>> fetchNotifications({
    int page = 1,
    bool unreadOnly = false,
  }) async {
    final params = <String, String>{'page': page.toString()};
    if (unreadOnly) params['unread_only'] = 'true';
    final data =
        await _client.get('/api/notifications', queryParams: params);
    final list = data['notifications'] as List? ?? [];
    return list.map((n) => AppNotification.fromJson(n)).toList();
  }

  Future<int> fetchUnreadCount() async {
    final data = await _client.get('/api/notifications/unread-count');
    return data['unread_count'] ?? 0;
  }

  Future<void> markRead(int id) async {
    await _client.post('/api/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _client.post('/api/notifications/read-all');
  }

  Future<void> deleteNotification(int id) async {
    await _client.delete('/api/notifications/$id');
  }
}
