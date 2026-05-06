import 'package:flutter_test/flutter_test.dart';
import 'package:echo_journal/models/comment.dart';

void main() {
  group('Comment.fromJson', () {
    final sampleJson = {
      'id': 10,
      'diary_id': 5,
      'content': '写得真好！',
      'created_at': '2025-01-16 14:20:00',
      'client_id': 'user:3',
      'author_name': 'Bob',
      'author_avatar': '🐶',
      'author_user_id': 3,
      'is_author': false,
      'anon_name': null,
      'anon_avatar': null,
      'parent_comment_id': null,
      'root_comment_id': null,
      'reply_to_identity_id': null,
      'like_count': 3,
      'liked': true,
    };

    test('parses all fields correctly', () {
      final c = Comment.fromJson(sampleJson);
      expect(c.id, 10);
      expect(c.diaryId, 5);
      expect(c.content, '写得真好！');
      expect(c.createdAt, '2025-01-16 14:20:00');
      expect(c.clientId, 'user:3');
      expect(c.authorName, 'Bob');
      expect(c.authorAvatar, '🐶');
      expect(c.authorUserId, 3);
      expect(c.isAuthor, false);
      expect(c.anonName, null);
      expect(c.anonAvatar, null);
      expect(c.parentReplyId, null);
      expect(c.rootReplyId, null);
      expect(c.likeCount, 3);
      expect(c.liked, true);
    });

    test('handles anon (treehole) comments', () {
      final c = Comment.fromJson({
        'id': 1,
        'diary_id': 2,
        'content': '匿名消息',
        'created_at': '',
        'client_id': '',
        'anon_name': '山间小鹿',
        'anon_avatar': '🦌',
      });
      expect(c.anonName, '山间小鹿');
      expect(c.anonAvatar, '🦌');
      expect(c.authorName, null);
    });

    test('handles missing fields with defaults', () {
      final c = Comment.fromJson({});
      expect(c.id, 0);
      expect(c.diaryId, 0);
      expect(c.content, '');
      expect(c.clientId, '');
      expect(c.authorName, null);
      expect(c.authorUserId, null);
      expect(c.likeCount, null);
      expect(c.liked, null);
    });

    test('parses nested replies', () {
      final c = Comment.fromJson({
        'id': 1, 'diary_id': 2, 'content': 'parent', 'created_at': '', 'client_id': '',
        'replies': [
          {'id': 2, 'diary_id': 2, 'content': 'reply1', 'created_at': '', 'client_id': ''},
          {'id': 3, 'diary_id': 2, 'content': 'reply2', 'created_at': '', 'client_id': ''},
        ],
      });
      expect(c.replies, isNotNull);
      expect(c.replies!.length, 2);
      expect(c.replies![0].id, 2);
      expect(c.replies![0].content, 'reply1');
      expect(c.replies![1].id, 3);
    });

    test('parses nested replies with anon names', () {
      final c = Comment.fromJson({
        'id': 1, 'diary_id': 2, 'content': 'parent', 'created_at': '', 'client_id': '',
        'replies': [
          {'id': 4, 'diary_id': 2, 'content': 'reply', 'created_at': '', 'client_id': '',
           'anon_name': '夜晚的风', 'anon_avatar': '🌙'},
        ],
      });
      expect(c.replies![0].anonName, '夜晚的风');
      expect(c.replies![0].anonAvatar, '🌙');
    });

    test('parses reply threading fields', () {
      final c = Comment.fromJson({
        'id': 1, 'diary_id': 2, 'content': 'reply', 'created_at': '', 'client_id': '',
        'parent_comment_id': 5,
        'root_comment_id': 5,
        'reply_to_user_id': 8,
      });
      expect(c.parentReplyId, 5);
      expect(c.rootReplyId, 5);
      expect(c.replyToIdentityId, 8); // falls back to reply_to_user_id
    });

    test('parses reply_to_identity_id (for treehole)', () {
      final c = Comment.fromJson({
        'id': 1, 'diary_id': 2, 'content': 'reply', 'created_at': '', 'client_id': '',
        'reply_to_identity_id': 7,
      });
      expect(c.replyToIdentityId, 7);
    });

    test('parses like info on comment', () {
      final c = Comment.fromJson({
        'id': 1, 'diary_id': 2, 'content': 'c', 'created_at': '', 'client_id': '',
        'like_count': 12, 'liked': true,
      });
      expect(c.likeCount, 12);
      expect(c.liked, true);
    });
  });
}
