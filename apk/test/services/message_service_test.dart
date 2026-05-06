import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:echo_journal/services/api_client.dart';
import 'package:echo_journal/services/message_service.dart';
import 'test_helper.dart';

void main() {
  group('MessageService', () {
    late MessageService service;

    setUp(() {
      service = MessageService();
    });

    tearDown(() {
      ApiClient.injectHttpClient(null);
    });

    test('fetchConversations reads data["data"] (raw-list-wrapped)', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode([
        {'id': 1, 'other_user': {'nickname': 'Alice', 'avatar': 'rabbit'},
         'last_message': 'hi', 'last_message_time': '', 'unread_count': 2, 'created_at': ''},
      ])));

      final convs = await service.fetchConversations();
      expect(convs.length, 1);
      expect(convs[0].id, 1);
      expect(convs[0].lastMessage, 'hi');
      expect(convs[0].unreadCount, 2);
    });

    test('fetchConversations empty', () async {
      ApiClient.injectHttpClient(mockClient('[]'));
      final convs = await service.fetchConversations();
      expect(convs, isEmpty);
    });

    test('createConversation reads data["conversation"]', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode({
        'ok': true,
        'conversation': {
          'id': 5,
          'other_user': {'id': 3, 'nickname': 'Bob', 'avatar': 'dog'},
        },
      })));

      final conv = await service.createConversation(3);
      expect(conv.id, 5);
    });

    test('createConversation returns parsed conversation', () async {
      // Verify the response is parsed correctly from data["conversation"]
      var capturedPath = '';
      ApiClient.injectHttpClient(mockClientHandler((req) async {
        capturedPath = req.url.path;
        return mockResponse(jsonEncode({
          'ok': true,
          'conversation': {'id': 6, 'other_user': {'id': 4, 'nickname': 'Eve', 'avatar': 'owl'}},
        }));
      }));

      final conv = await service.createConversation(4);
      expect(capturedPath, '/api/messages/conversations');
      expect(conv.id, 6);
    });

    test('fetchMessages reads data["items"]', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode({
        'items': [
          {'id': 1, 'conversation_id': 5, 'sender_id': 1, 'content': 'hello', 'created_at': ''},
          {'id': 2, 'conversation_id': 5, 'sender_id': 2, 'content': 'hi', 'created_at': ''},
        ],
        'has_more': false,
      })));

      final msgs = await service.fetchMessages(5);
      expect(msgs.length, 2);
      expect(msgs[0].senderId, 1);
      expect(msgs[1].senderId, 2);
    });

    test('sendMessage reads data["message"]', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode({
        'ok': true,
        'message': {
          'id': 3, 'conversation_id': 5, 'sender_id': 1,
          'receiver_id': 2, 'content': 'test msg', 'created_at': '2025-01-16 12:00:00',
        },
      })));

      final msg = await service.sendMessage(5, 'test msg');
      expect(msg.id, 3);
      expect(msg.senderId, 1);
      expect(msg.content, 'test msg');
    });

    test('fetchUnreadCount reads unread_count', () async {
      ApiClient.injectHttpClient(mockClient(jsonEncode({'unread_count': 5})));
      final count = await service.fetchUnreadCount();
      expect(count, 5);
    });
  });
}
