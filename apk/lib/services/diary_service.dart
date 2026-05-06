import '../models/diary.dart';
import 'api_client.dart';

String _todayStr() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

class DiaryService {
  final ApiClient _client = ApiClient();

  Future<List<Diary>> fetchDiaries({String? date, String? keyword}) async {
    final params = <String, String>{};
    final effectiveDate = keyword != null && keyword.isNotEmpty ? date : (date ?? _todayStr());
    if (effectiveDate != null) params['date'] = effectiveDate;
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;

    final data = await _client.get('/api/diaries',
        queryParams: params.isNotEmpty ? params : null);

    // 后端返回数组，_handleResponse 把 List 包装成 {'data': [...]} 再返回
    // data 本身是 Map，{'data': [...]} 在 data['data'] 里
    final list = (data['data'] as List?) ?? [];
    return list.map((d) => Diary.fromJson(Map<String, dynamic>.from(d))).toList();
  }

  Future<List<Diary>> fetchDiariesByDate(String date) async {
    final data = await _client.get('/api/diaries/date/$date');
    final list = (data['data'] as List?) ?? [];
    return list.map((d) => Diary.fromJson(Map<String, dynamic>.from(d))).toList();
  }

  Future<Diary> fetchDiaryById(int id) async {
    final data = await _client.get('/api/diaries/$id');
    return Diary.fromJson(Map<String, dynamic>.from(data));
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
