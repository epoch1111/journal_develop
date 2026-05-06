import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:echo_journal/services/api_client.dart';
import 'package:echo_journal/services/discover_service.dart';
import 'test_helper.dart';

void main() {
  group('DiscoverService', () {
    late DiscoverService service;

    setUp(() {
      service = DiscoverService();
    });

    tearDown(() {
      ApiClient.injectHttpClient(null);
    });

    test('fetchPublicDiaries reads data["items"]', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode({
        'items': [
          {'id': 1, 'mood': '😊', 'content': 'hello', 'created_at': '', 'user_id': 2,
           'author_name': 'Alice', 'is_public': 1},
        ],
        'has_more': true,
      })));

      final result = await service.fetchPublicDiaries();
      final diaries = result['diaries'] as List;
      expect(diaries.length, 1);
      expect(diaries[0].id, 1);
      expect(result['has_more'], true);
    });

    test('fetchPublicDiaries returns empty when items is empty', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode({'items': [], 'has_more': false})));
      final result = await service.fetchPublicDiaries();
      expect(result['diaries'] as List, isEmpty);
    });

    test('fetchPublicDiaries following feed reads data["items"]', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode({
        'items': [
          {'id': 3, 'mood': '🥳', 'content': 'following feed', 'created_at': '', 'user_id': 5,
           'author_name': 'Bob', 'is_public': 1},
        ],
        'has_more': false,
      })));

      final result = await service.fetchPublicDiaries(feed: 'following');
      expect((result['diaries'] as List).length, 1);
    });

    test('fetchPublicDiaryById reads response directly', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode({
        'id': 7, 'mood': '😎', 'content': 'detail', 'created_at': '', 'user_id': 2,
        'author_name': 'Charlie',
      })));

      final diary = await service.fetchPublicDiaryById(7);
      expect(diary.id, 7);
      expect(diary.authorName, 'Charlie');
    });

    test('fetchComments reads data["data"] (raw-list-wrapped)', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode([
        {'id': 1, 'diary_id': 5, 'content': 'nice post', 'created_at': '', 'client_id': ''},
        {'id': 2, 'diary_id': 5, 'content': 'great!', 'created_at': '', 'client_id': ''},
      ])));

      final comments = await service.fetchComments(5);
      expect(comments.length, 2);
      expect(comments[0].content, 'nice post');
      expect(comments[1].content, 'great!');
    });

    test('fetchComments empty', () async {
      ApiClient.injectHttpClient(mockClient('[]'));
      final comments = await service.fetchComments(999);
      expect(comments, isEmpty);
    });

    test('commentOnDiary reads data["comment"]', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode({
        'ok': true,
        'comment': {'id': 100, 'content': 'my comment', 'created_at': '2025-01-16',
                      'diary_id': 5, 'client_id': 'user:1'},
      })));

      final c = await service.commentOnDiary(5, 'user:1', 'my comment');
      expect(c.id, 100);
      expect(c.content, 'my comment');
    });

    test('commentOnDiary sends parent_comment_id and reply_to_user_id for replies', () async {
      String? body;
      ApiClient.injectHttpClient(mockClientHandler((req) async {
        body = (req as http.Request).body;
        return mockResponse(jsonEncode({
          'ok': true,
          'comment': {'id': 101, 'content': 'reply', 'created_at': '', 'diary_id': 5,
                        'client_id': 'user:1'},
        }));
      }));

      await service.commentOnDiary(5, 'user:1', 'reply', parentReplyId: 10, replyToUserId: 3);
      final decoded = jsonDecode(body!);
      expect(decoded['parent_comment_id'], 10);
      expect(decoded['reply_to_user_id'], 3);
      expect(decoded['content'], 'reply');
    });
  });
}
