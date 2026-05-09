import '../client.dart';

class DiaryEndpoints {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> getDiaries({String? date, String? keyword}) async {
    final params = <String, String>{};
    if (date != null && date.isNotEmpty) params['date'] = date;
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
    return await _client.get('/api/diaries',
        queryParams: params.isNotEmpty ? params : null);
  }

  Future<Map<String, dynamic>> getDiariesByDate(String date) async {
    return await _client.get('/api/diaries/date/$date');
  }

  Future<Map<String, dynamic>> getDiaryById(int id) async {
    return await _client.get('/api/diaries/$id');
  }

  Future<Map<String, dynamic>> saveDiary({
    required String mood,
    required String content,
    String? tags,
    bool isPublic = false,
    String? unlockDate,
    List<String>? imageUrls,
    String? aiSummary,
    String? aiMessage,
  }) async {
    final body = <String, dynamic>{
      'mood': mood,
      'content': content,
      'is_public': isPublic,
    };
    if (tags != null && tags.isNotEmpty) body['tags'] = tags;
    if (aiSummary != null) body['ai_summary'] = aiSummary;
    if (aiMessage != null) body['ai_message'] = aiMessage;
    if (unlockDate != null && unlockDate.isNotEmpty) {
      body['unlock_date'] = unlockDate;
      body['content_type'] = 'capsule';
    }
    if (imageUrls != null && imageUrls.isNotEmpty) {
      body['image_urls'] = imageUrls;
    }
    return await _client.post('/api/save', body: body);
  }

  Future<Map<String, dynamic>> updateDiary(int id, Map<String, dynamic> updates) async {
    return await _client.put('/api/diaries/$id', body: updates);
  }

  Future<Map<String, dynamic>> deleteDiary(int id) async {
    return await _client.delete('/api/diaries/$id');
  }

  Future<Map<String, dynamic>> getStats() async {
    return await _client.get('/api/stats');
  }

  Future<Map<String, dynamic>> getMoodStats() async {
    return await _client.get('/api/mood-stats');
  }
}
