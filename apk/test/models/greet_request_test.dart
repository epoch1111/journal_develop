import 'package:flutter_test/flutter_test.dart';
import 'package:echo_journal/models/greet_request.dart';

void main() {
  group('GreetRequest.fromJson', () {
    test('parses received request fields', () {
      final r = GreetRequest.fromJson({
        'id': 1,
        'from_user_id': 2,
        'to_user_id': 1,
        'status': 'pending',
        'created_at': '2025-01-16 08:00:00',
        'updated_at': '2025-01-16 08:00:00',
        'from_user_name': 'Alice',
        'from_user_avatar': '🐰',
      });
      expect(r.id, 1);
      expect(r.fromUserId, 2);
      expect(r.toUserId, 1);
      expect(r.status, 'pending');
      expect(r.fromUserName, 'Alice');
      expect(r.fromUserAvatar, '🐰');
      expect(r.toUserName, null);
      expect(r.toUserAvatar, null);
    });

    test('parses sent request fields', () {
      final r = GreetRequest.fromJson({
        'id': 2,
        'from_user_id': 1,
        'to_user_id': 3,
        'status': 'accepted',
        'created_at': '2025-01-16 09:00:00',
        'updated_at': '2025-01-16 10:00:00',
        'to_user_name': 'Bob',
        'to_user_avatar': '🐶',
      });
      expect(r.toUserName, 'Bob');
      expect(r.toUserAvatar, '🐶');
      expect(r.fromUserName, null);
      expect(r.fromUserAvatar, null);
    });

    test('handles missing fields with defaults', () {
      final r = GreetRequest.fromJson({});
      expect(r.id, 0);
      expect(r.fromUserId, 0);
      expect(r.toUserId, 0);
      expect(r.status, 'pending');
      expect(r.createdAt, '');
      expect(r.updatedAt, '');
      expect(r.fromUserName, null);
      expect(r.toUserName, null);
    });

    test('parses all status values', () {
      for (final s in ['pending', 'accepted', 'rejected', 'cancelled']) {
        final r = GreetRequest.fromJson({
          'id': 1, 'from_user_id': 1, 'to_user_id': 2,
          'status': s, 'created_at': '', 'updated_at': '',
        });
        expect(r.status, s);
      }
    });
  });
}
