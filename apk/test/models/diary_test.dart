import 'package:flutter_test/flutter_test.dart';
import 'package:echo_journal/models/diary.dart';

void main() {
  group('Diary.fromJson', () {
    final sampleJson = {
      'id': 1,
      'created_at': '2025-01-15 10:30:00',
      'mood': '😊',
      'content': '今天天气真好',
      'ai_summary': '愉快的一天',
      'ai_message': '你的快乐会传染',
      'tags': '生活,开心',
      'is_public': 1,
      'hug_count': 3,
      'image_url': '/uploads/img1.jpg',
      'image_urls': ['/uploads/img1.jpg', '/uploads/img2.jpg'],
      'unlock_date': '',
      'user_id': 5,
      'content_type': 'diary',
      'author_name': 'Charlie',
      'author_avatar': '🐱',
      'locked': false,
      'like_count': 10,
      'liked': true,
      'comment_count': 4,
      'anon_name': null,
      'anon_avatar': null,
    };

    test('parses all fields correctly', () {
      final d = Diary.fromJson(sampleJson);
      expect(d.id, 1);
      expect(d.createdAt, '2025-01-15 10:30:00');
      expect(d.mood, '😊');
      expect(d.content, '今天天气真好');
      expect(d.aiSummary, '愉快的一天');
      expect(d.aiMessage, '你的快乐会传染');
      expect(d.tags, '生活,开心');
      expect(d.isPublic, 1);
      expect(d.hugCount, 3);
      expect(d.imageUrl, '/uploads/img1.jpg');
      expect(d.imageUrls, ['/uploads/img1.jpg', '/uploads/img2.jpg']);
      expect(d.unlockDate, '');
      expect(d.userId, 5);
      expect(d.contentType, 'diary');
      expect(d.authorName, 'Charlie');
      expect(d.authorAvatar, '🐱');
      expect(d.locked, false);
      expect(d.likeCount, 10);
      expect(d.liked, true);
      expect(d.commentCount, 4);
      expect(d.anonName, null);
      expect(d.anonAvatar, null);
    });

    test('handles missing fields with defaults', () {
      final d = Diary.fromJson({});
      expect(d.id, 0);
      expect(d.mood, '😊');
      expect(d.content, '');
      expect(d.isPublic, 0);
      expect(d.hugCount, 0);
      expect(d.userId, 0);
      expect(d.contentType, 'diary');
      expect(d.imageUrls, null);
      expect(d.locked, null);
      expect(d.liked, null);
    });

    test('isCapsule returns true for capsule content_type', () {
      final d = Diary.fromJson({'content_type': 'capsule', 'unlock_date': '2026-01-01'});
      expect(d.isCapsule, true);
    });

    test('isCapsule returns true when unlock_date is set', () {
      final d = Diary.fromJson({'unlock_date': '2026-01-01'});
      expect(d.isCapsule, true);
    });

    test('isTreehole returns true for treehole', () {
      final d = Diary.fromJson({'content_type': 'treehole'});
      expect(d.isTreehole, true);
    });

    test('parses null image_urls gracefully', () {
      final d = Diary.fromJson({'image_urls': null});
      expect(d.imageUrls, null);
    });

    test('parses like_count from backend', () {
      final d = Diary.fromJson({'like_count': 42});
      expect(d.likeCount, 42);
    });

    test('parses comment_count from backend', () {
      final d = Diary.fromJson({'comment_count': 7});
      expect(d.commentCount, 7);
    });

    test('parses locked field from capsule response', () {
      final d = Diary.fromJson({'locked': true, 'unlock_date': '2026-06-01'});
      expect(d.locked, true);
    });
  });
}
