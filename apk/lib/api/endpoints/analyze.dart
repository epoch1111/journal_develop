import '../client.dart';

class AnalyzeEndpoints {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> analyze(String content, String mood, {String persona = 'default'}) async {
    return await _client.post('/api/analyze',
        body: {'content': content, 'mood': mood, 'persona': persona},
        auth: false);
  }
}
