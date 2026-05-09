import '../client.dart';

class GreetEndpoints {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> fetchGreetStatus(int userId) async {
    return await _client.get('/api/greet/status/$userId');
  }

  Future<void> createGreetRequest({
    required int receiverId,
    required String message,
  }) async {
    await _client.post('/api/greet/requests',
        body: {'receiver_id': receiverId, 'message': message});
  }
}
