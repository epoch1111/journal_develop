import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:echo_journal/services/api_client.dart';
import 'package:echo_journal/services/diary_service.dart';
import 'test_helper.dart';

void main() {
  group('DiaryService', () {
    late DiaryService service;

    setUp(() {
      service = DiaryService();
    });

    tearDown(() {
      ApiClient.injectHttpClient(null);
    });

    test('fetchDiaries reads data["data"] (raw-list-wrapped)', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode([
        {'id': 1, 'mood': '😊', 'content': 'test', 'created_at': '2025-01-01', 'user_id': 1},
        {'id': 2, 'mood': '😢', 'content': 'test2', 'created_at': '2025-01-02', 'user_id': 1},
      ])));

      final diaries = await service.fetchDiaries();
      expect(diaries.length, 2);
      expect(diaries[0].id, 1);
      expect(diaries[0].mood, '😊');
      expect(diaries[1].id, 2);
    });

    test('fetchDiaries returns empty list for empty response', () async {
      ApiClient.injectHttpClient(mockClient('[]'));
      final diaries = await service.fetchDiaries();
      expect(diaries, isEmpty);
    });

    test('fetchDiariesByDate reads data["data"]', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode([
        {'id': 3, 'mood': '🥳', 'content': 'party', 'created_at': '2025-06-01', 'user_id': 1},
      ])));

      final diaries = await service.fetchDiariesByDate('2025-06-01');
      expect(diaries.length, 1);
      expect(diaries[0].id, 3);
      expect(diaries[0].mood, '🥳');
    });

    test('fetchDiaryById reads response directly (single object)', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode({
        'id': 42, 'mood': '🤩', 'content': 'single', 'created_at': '', 'user_id': 1,
        'image_urls': ['/a.jpg'],
      })));

      final diary = await service.fetchDiaryById(42);
      expect(diary.id, 42);
      expect(diary.content, 'single');
      expect(diary.imageUrls, ['/a.jpg']);
    });

    test('fetchStats returns raw dict', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode({
        'mood_distribution': {'😊': 5},
        'calendar_data': {},
      })));

      final stats = await service.fetchStats();
      expect(stats['mood_distribution'], isNotNull);
    });

    test('fetchMoodStats returns raw dict', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode({
        'moods': [{'emoji': '😊', 'count': 3}],
      })));

      final stats = await service.fetchMoodStats();
      expect(stats['moods'], isNotNull);
    });
  });
}
