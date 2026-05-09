import '../api/endpoints/greet.dart';

class GreetService {
  final GreetEndpoints _ep = GreetEndpoints();

  Future<Map<String, dynamic>> fetchGreetStatus(int userId) async {
    return await _ep.fetchGreetStatus(userId);
  }

  Future<void> createGreetRequest({
    required int receiverId,
    required String message,
  }) async {
    await _ep.createGreetRequest(receiverId: receiverId, message: message);
  }
}
