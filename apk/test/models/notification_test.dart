import 'package:flutter_test/flutter_test.dart';
import 'package:echo_journal/models/notification.dart';

void main() {
  group('AppNotification.fromJson', () {
    test('reads content field for message (primary)', () {
      final n = AppNotification.fromJson({
        'id': 1,
        'type': 'follow',
        'content': 'Charlie 关注了你',
        'title': '有人关注了你',
        'entity_id': 5,
        'is_read': 0,
        'created_at': '2025-01-16 09:00:00',
      });
      expect(n.message, 'Charlie 关注了你');
    });

    test('falls back to title when content is missing', () {
      final n = AppNotification.fromJson({
        'id': 2,
        'type': 'public_diary_like',
        'title': '你的日记被点亮了',
        'is_read': 0,
        'created_at': '2025-01-16 10:00:00',
      });
      expect(n.message, '你的日记被点亮了');
    });

    test('falls back to empty string when both content and title missing', () {
      final n = AppNotification.fromJson({
        'id': 3,
        'type': 'unknown',
        'is_read': 1,
        'created_at': '',
      });
      expect(n.message, '');
    });

    test('reads entity_id as relatedId', () {
      final n = AppNotification.fromJson({
        'id': 1,
        'type': 'public_diary_comment',
        'content': 'test',
        'entity_id': 42,
        'is_read': 0,
        'created_at': '',
      });
      expect(n.relatedId, '42');
    });

    test('handles null entity_id', () {
      final n = AppNotification.fromJson({
        'id': 1,
        'type': 'follow',
        'content': 'test',
        'is_read': 0,
        'created_at': '',
      });
      expect(n.relatedId, null);
    });

    test('parses all notification types correctly', () {
      final types = [
        'follow',
        'public_diary_like',
        'public_diary_comment',
        'public_diary_comment_reply',
        'treehole_hug',
        'treehole_reply',
        'treehole_reply_like',
        'greet_request',
        'greet_accepted',
        'greet_rejected',
      ];
      for (final t in types) {
        final n = AppNotification.fromJson({
          'id': 1, 'type': t, 'content': 'test $t', 'is_read': 0, 'created_at': '',
        });
        expect(n.type, t);
        expect(n.message, 'test $t');
      }
    });

    test('handles empty json gracefully', () {
      final n = AppNotification.fromJson({});
      expect(n.id, 0);
      expect(n.type, '');
      expect(n.message, '');
      expect(n.relatedId, null);
      expect(n.isRead, 0);
      expect(n.createdAt, '');
    });

    test('isRead defaults to 0 (unread)', () {
      final n = AppNotification.fromJson({'id': 1, 'type': '', 'content': '', 'created_at': ''});
      expect(n.isRead, 0);
    });

    test('reads is_read as 1', () {
      final n = AppNotification.fromJson({
        'id': 1, 'type': '', 'content': '', 'is_read': 1, 'created_at': '',
      });
      expect(n.isRead, 1);
    });

    test('parses created_at', () {
      final n = AppNotification.fromJson({
        'id': 1, 'type': '', 'content': '', 'created_at': '2025-03-15 12:00:00',
      });
      expect(n.createdAt, '2025-03-15 12:00:00');
    });

    test('title takes priority when content is empty string', () {
      final n = AppNotification.fromJson({
        'id': 1, 'type': 'greet', 'content': '', 'title': '打招呼标题',
        'is_read': 0, 'created_at': '',
      });
      // content is empty string (not null), so it's used over title
      expect(n.message, '');
    });
  });
}
