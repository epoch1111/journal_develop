import 'package:flutter_test/flutter_test.dart';
import 'package:echo_journal/models/message.dart';

void main() {
  group('ChatMessage.fromJson', () {
    test('parses all fields correctly', () {
      final m = ChatMessage.fromJson({
        'id': 1,
        'conversation_id': 5,
        'sender_id': 2,
        'content': '你好！',
        'created_at': '2025-01-16 12:00:00',
        'is_read': 0,
      });
      expect(m.id, 1);
      expect(m.conversationId, 5);
      expect(m.senderId, 2);
      expect(m.content, '你好！');
      expect(m.createdAt, '2025-01-16 12:00:00');
      expect(m.isRead, 0);
    });

    test('handles missing fields with defaults', () {
      final m = ChatMessage.fromJson({});
      expect(m.id, 0);
      expect(m.conversationId, 0);
      expect(m.senderId, 0);
      expect(m.content, '');
      expect(m.createdAt, '');
      expect(m.isRead, 0);
    });

    test('senderId is key for chat bubble alignment', () {
      final myMsg = ChatMessage.fromJson({
        'id': 1, 'conversation_id': 5, 'sender_id': 3, 'content': 'hi', 'created_at': '',
      });
      expect(myMsg.senderId, 3);

      final otherMsg = ChatMessage.fromJson({
        'id': 2, 'conversation_id': 5, 'sender_id': 7, 'content': 'hello', 'created_at': '',
      });
      expect(otherMsg.senderId, 7);
    });

    test('parses is_read', () {
      final unread = ChatMessage.fromJson({
        'id': 1, 'conversation_id': 1, 'sender_id': 1, 'content': '', 'created_at': '', 'is_read': 0,
      });
      expect(unread.isRead, 0);

      final read = ChatMessage.fromJson({
        'id': 2, 'conversation_id': 1, 'sender_id': 1, 'content': '', 'created_at': '', 'is_read': 1,
      });
      expect(read.isRead, 1);
    });
  });
}
