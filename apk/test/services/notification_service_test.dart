import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_journal/services/api_client.dart';
import 'package:echo_journal/services/notification_service.dart';
import 'test_helper.dart';

void main() {
  group('NotificationService', () {
    late NotificationService service;

    setUp(() {
      service = NotificationService();
    });

    tearDown(() {
      ApiClient.injectHttpClient(null);
    });

    test('fetchNotifications reads data["items"]', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode({
        'items': [
          {'id': 1, 'type': 'follow', 'content': 'Alice started following you',
           'entity_id': null, 'is_read': 0, 'created_at': '2025-01-16'},
          {'id': 2, 'type': 'public_diary_like', 'content': 'Bob liked your diary',
           'entity_id': 5, 'is_read': 1, 'created_at': '2025-01-16'},
        ],
        'has_more': false,
      })));

      final notifications = await service.fetchNotifications();
      expect(notifications.length, 2);
      expect(notifications[0].message, 'Alice started following you');
      expect(notifications[0].type, 'follow');
      expect(notifications[1].message, 'Bob liked your diary');
      expect(notifications[1].type, 'public_diary_like');
      expect(notifications[1].relatedId, '5');
    });

    test('fetchNotifications falls back to title when content missing', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode({
        'items': [
          {'id': 1, 'type': 'follow', 'title': 'Someone followed you',
           'is_read': 0, 'created_at': ''},
          {'id': 2, 'type': 'like', 'content': 'has content', 'title': 'backup',
           'is_read': 0, 'created_at': ''},
        ],
      })));

      final notifications = await service.fetchNotifications();
      expect(notifications[0].message, 'Someone followed you');
      expect(notifications[1].message, 'has content');
    });

    test('fetchNotifications empty', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode({'items': [], 'has_more': false})));
      final notifications = await service.fetchNotifications();
      expect(notifications, isEmpty);
    });

    test('fetchUnreadCount reads unread_count', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode({'unread_count': 3})));
      final count = await service.fetchUnreadCount();
      expect(count, 3);
    });
  });
}
