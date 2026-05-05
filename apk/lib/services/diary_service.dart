import '../models/diary.dart';
import 'api_client.dart';

class DiaryService {
  final ApiClient _client = ApiClient();

  Future<List<Diary>> fetchDiaries({String? date}) async {
    final data = await _client.get('/api/diaries',
        queryParams: date != null ? {'date': date} : null);
    final list = data['diaries'] as List? ?? [];
    return list.map((d) => Diary.fromJson(d)).toList();
  }

  Future<List<Diary>> fetchDiariesByDate(String date) async {
    final data = await _client.get('/api/diaries/date/$date');
    final list = data['diaries'] as List? ?? [];
    return list.map((d) => Diary.fromJson(d)).toList();
  }

  Future<Diary> fetchDiaryById(int id) async {
    final data = await _client.get('/api/diaries/$id');
    return Diary.fromJson(data);
  }

  Future<Map<String, dynamic>> saveDiary({
    required String mood,
    required String content,
    String? tags,
    bool isPublic = false,
    String? unlockDate,
    List<String>? imageUrls,
  }) async {
    final body = <String, dynamic>{
      'mood': mood,
      'content': content,
      'is_public': isPublic,
    };
    if (tags != null && tags.isNotEmpty) body['tags'] = tags;
    if (unlockDate != null && unlockDate.isNotEmpty) {
      body['unlock_date'] = unlockDate;
      body['content_type'] = 'capsule';
    }
    if (imageUrls != null && imageUrls.isNotEmpty) {
      body['image_urls'] = imageUrls;
    }
    return await _client.post('/api/save', body: body);
  }

  Future<Map<String, dynamic>> updateDiary(int id,
      {String? mood,
      String? content,
      String? tags,
      bool? isPublic,
      List<String>? imageUrls}) async {
    final body = <String, dynamic>{};
    if (mood != null) body['mood'] = mood;
    if (content != null) body['content'] = content;
    if (tags != null) body['tags'] = tags;
    if (isPublic != null) body['is_public'] = isPublic;
    if (imageUrls != null) body['image_urls'] = imageUrls;
    return await _client.put('/api/diaries/$id', body: body);
  }

  Future<void> deleteDiary(int id) async {
    await _client.delete('/api/diaries/$id');
  }

  Future<Map<String, dynamic>> fetchStats() async {
    return await _client.get('/api/stats');
  }

  Future<Map<String, dynamic>> fetchMoodStats() async {
    return await _client.get('/api/mood-stats');
  }
}
