import '../client.dart';

class MessageEndpoints {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> getConversations() async {
    return await _client.get('/api/messages/conversations');
  }

  Future<Map<String, dynamic>> createConversation(int targetUserId) async {
    return await _client.post('/api/messages/conversations',
        body: {'user_id': targetUserId});
  }

  Future<Map<String, dynamic>> getMessages(int conversationId, {int page = 1}) async {
    return await _client.get(
        '/api/messages/conversations/$conversationId/messages',
        queryParams: {'page': page.toString()});
  }

  Future<Map<String, dynamic>> sendMessage(
    int conversationId,
    String content, {
    String? imageUrl,
  }) async {
    final body = <String, dynamic>{'content': content};
    if (imageUrl != null && imageUrl.isNotEmpty) {
      body['image_url'] = imageUrl;
    }
    return await _client.post(
        '/api/messages/conversations/$conversationId/messages',
        body: body);
  }

  Future<Map<String, dynamic>> markRead(int conversationId) async {
    return await _client.post('/api/messages/conversations/$conversationId/read');
  }

  Future<Map<String, dynamic>> getUnreadCount() async {
    return await _client.get('/api/messages/unread-count');
  }

  Future<Map<String, dynamic>> getContacts() async {
    return await _client.get('/api/messages/contacts');
  }
}
