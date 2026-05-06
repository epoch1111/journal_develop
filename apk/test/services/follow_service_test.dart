import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_journal/services/api_client.dart';
import 'package:echo_journal/services/follow_service.dart';
import 'test_helper.dart';

void main() {
  group('FollowService', () {
    late FollowService service;

    setUp(() {
      service = FollowService();
    });

    tearDown(() {
      ApiClient.injectHttpClient(null);
    });

    test('fetchFollowing reads data["data"]', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode([
        {'id': 2, 'username': 'bob', 'nickname': 'Bob', 'avatar': '🐶'},
        {'id': 3, 'username': 'alice', 'nickname': 'Alice', 'avatar': '🐰'},
      ])));

      final users = await service.fetchFollowing();
      expect(users.length, 2);
      expect(users[0].nickname, 'Bob');
      expect(users[1].nickname, 'Alice');
    });

    test('fetchFollowers reads data["data"]', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode([
        {'id': 4, 'username': 'eve', 'nickname': 'Eve', 'avatar': '🦊'},
      ])));

      final users = await service.fetchFollowers();
      expect(users.length, 1);
      expect(users[0].nickname, 'Eve');
    });

    test('fetchFollowingFeed reads data["items"]', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode({
        'items': [
          {'id': 10, 'mood': '😊', 'content': 'feed item', 'created_at': '', 'user_id': 2,
           'author_name': 'Bob', 'is_public': 1},
        ],
        'has_more': false,
      })));

      final diaries = await service.fetchFollowingFeed();
      expect(diaries.length, 1);
      expect(diaries[0].authorName, 'Bob');
    });

    test('fetchFollowing empty returns empty list', () async {
      ApiClient.injectHttpClient(mockClient('[]'));
      final users = await service.fetchFollowing();
      expect(users, isEmpty);
    });
  });
}
