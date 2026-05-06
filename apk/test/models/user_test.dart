import 'package:flutter_test/flutter_test.dart';
import 'package:echo_journal/models/user.dart';

void main() {
  group('User.fromJson', () {
    test('parses all fields correctly', () {
      final u = User.fromJson({
        'id': 1,
        'username': 'charlie',
        'email': 'charlie@example.com',
        'nickname': 'Charlie',
        'avatar': '🐱',
        'bio': '热爱生活',
        'interests': '日记,摄影',
        'created_at': '2025-01-01 00:00:00',
        'updated_at': '2025-01-15 00:00:00',
        'following_count': 10,
        'follower_count': 20,
        'is_following': true,
      });
      expect(u.id, 1);
      expect(u.username, 'charlie');
      expect(u.email, 'charlie@example.com');
      expect(u.nickname, 'Charlie');
      expect(u.avatar, '🐱');
      expect(u.bio, '热爱生活');
      expect(u.interests, '日记,摄影');
      expect(u.createdAt, '2025-01-01 00:00:00');
      expect(u.updatedAt, '2025-01-15 00:00:00');
      expect(u.followingCount, 10);
      expect(u.followerCount, 20);
      expect(u.isFollowing, true);
    });

    test('handles missing fields with defaults', () {
      final u = User.fromJson({});
      expect(u.id, 0);
      expect(u.username, '');
      expect(u.nickname, '小兔');
      expect(u.avatar, '🐰');
      expect(u.bio, '今天也在认真生活');
      expect(u.interests, '日记,生活,小确幸');
      expect(u.followingCount, null);
      expect(u.followerCount, null);
      expect(u.isFollowing, null);
    });

    test('toJson returns only editable fields', () {
      final u = User.fromJson({'nickname': 'Test', 'avatar': '🐸', 'bio': 'bio', 'interests': 'a,b'});
      final j = u.toJson();
      expect(j['nickname'], 'Test');
      expect(j['avatar'], '🐸');
      expect(j['bio'], 'bio');
      expect(j['interests'], 'a,b');
      expect(j.containsKey('id'), false);
      expect(j.containsKey('username'), false);
    });

    test('handles null follow counts', () {
      final u = User.fromJson({'following_count': null, 'follower_count': null});
      expect(u.followingCount, null);
      expect(u.followerCount, null);
    });
  });
}
