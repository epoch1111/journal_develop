import '../models/conversation.dart';
import '../models/message.dart';
import 'api_client.dart';

class MessageService {
  final ApiClient _client = ApiClient();

  Future<List<Conversation>> fetchConversations() async {
    final data = await _client.get('/api/messages/conversations');
    final list = data['conversations'] as List? ?? [];
    return list.map((c) => Conversation.fromJson(c)).toList();
  }

  Future<Conversation> createConversation(int targetUserId) async {
    final data = await _client.post('/api/messages/conversations',
        body: {'target_user_id': targetUserId});
    return Conversation.fromJson(data);
  }

  Future<List<ChatMessage>> fetchMessages(int conversationId,
      {int page = 1}) async {
    final data = await _client
        .get('/api/messages/conversations/$conversationId/messages',
            queryParams: {'page': page.toString()});
    final list = data['messages'] as List? ?? [];
    return list.map((m) => ChatMessage.fromJson(m)).toList();
  }

  Future<ChatMessage> sendMessage(int conversationId, String content) async {
    final data = await _client.post(
        '/api/messages/conversations/$conversationId/messages',
        body: {'content': content});
    return ChatMessage.fromJson(data);
  }

  Future<void> markRead(int conversationId) async {
    await _client.post('/api/messages/conversations/$conversationId/read');
  }

  Future<int> fetchUnreadCount() async {
    final data = await _client.get('/api/messages/unread-count');
    return data['unread_count'] ?? 0;
  }

  Future<List<Map<String, dynamic>>> fetchContacts() async {
    final data = await _client.get('/api/messages/contacts');
    final list = data['contacts'] as List? ?? [];
    return list.cast<Map<String, dynamic>>();
  }
}
