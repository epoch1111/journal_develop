import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_journal/services/api_client.dart';
import 'package:echo_journal/services/safety_service.dart';
import 'test_helper.dart';

void main() {
  group('SafetyService', () {
    late SafetyService service;

    setUp(() {
      service = SafetyService();
    });

    tearDown(() {
      ApiClient.injectHttpClient(null);
    });

    test('fetchBlockedUsers reads data["data"]', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode([
        {'id': 5, 'username': 'spammer', 'nickname': 'Spam', 'avatar': 'x'},
        {'id': 6, 'username': 'troll', 'nickname': 'Troll', 'avatar': 'y'},
      ])));

      final users = await service.fetchBlockedUsers();
      expect(users.length, 2);
      expect(users[0].nickname, 'Spam');
      expect(users[1].nickname, 'Troll');
    });

    test('fetchBlockedUsers empty', () async {
      ApiClient.injectHttpClient(mockClient('[]'));
      final users = await service.fetchBlockedUsers();
      expect(users, isEmpty);
    });

    test('fetchMyReports reads data["data"]', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode([
        {'id': 1, 'target_type': 'user', 'target_id': 5, 'reason': 'spam', 'status': 'pending'},
        {'id': 2, 'target_type': 'diary', 'target_id': 10, 'reason': 'harassment', 'status': 'resolved'},
      ])));

      final reports = await service.fetchMyReports();
      expect(reports.length, 2);
      expect(reports[0]['reason'], 'spam');
      expect(reports[1]['target_type'], 'diary');
    });

    test('fetchBlockStatus returns dict directly', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode({
        'blocked': true, 'blocked_by_target': false, 'any_blocked': true,
      })));

      final status = await service.fetchBlockStatus(5);
      expect(status['blocked'], true);
      expect(status['any_blocked'], true);
    });
  });
}
