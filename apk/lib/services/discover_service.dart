import '../models/diary.dart';
import '../models/comment.dart';
import 'api_client.dart';

class DiscoverService {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> fetchPublicDiaries({
    int page = 1,
    String? mood,
    String? tag,
    String? keyword,
    String? clientId,
    String? feed,
  }) async {
    // Following feed uses a different endpoint
    if (feed == 'following') {
      final data = await _client.get('/api/me/following-feed',
          queryParams: {'page': page.toString()});
      final list = data['diaries'] as List? ?? [];
      return {
        'diaries': list.map((d) => Diary.fromJson(d)).toList(),
        'has_more': data['has_more'] ?? false,
      };
    }

    final params = <String, String>{'page': page.toString()};
    if (mood != null) params['mood'] = mood;
    if (tag != null) params['tag'] = tag;
    if (keyword != null) params['keyword'] = keyword;
    if (clientId != null) params['client_id'] = clientId;

    final data = await _client.get('/api/public/diaries',
        auth: false, queryParams: params);
    final list = data['diaries'] as List? ?? [];
    return {
      'diaries': list.map((d) => Diary.fromJson(d)).toList(),
      'has_more': data['has_more'] ?? false,
    };
  }

  Future<Diary> fetchPublicDiaryById(int id) async {
    final data = await _client.get('/api/public/diaries/$id', auth: false);
    return Diary.fromJson(data);
  }

  Future<void> likeDiary(int diaryId, String clientId) async {
    await _client.post('/api/public/diaries/$diaryId/like',
        body: {'client_id': clientId}, auth: false);
  }

  Future<void> unlikeDiary(int diaryId, String clientId) async {
    await _client.delete(
        '/api/public/diaries/$diaryId/like?client_id=$clientId',
        auth: false);
  }

  Future<Comment> commentOnDiary(int diaryId, String clientId, String content,
      {int? parentReplyId}) async {
    final body = <String, dynamic>{
      'client_id': clientId,
      'content': content,
    };
    if (parentReplyId != null) body['parent_reply_id'] = parentReplyId;
    final data = await _client.post(
        '/api/public/diaries/$diaryId/comments',
        body: body,
        auth: false);
    return Comment.fromJson(data);
  }

  Future<List<Comment>> fetchComments(int diaryId) async {
    final data = await _client.get(
        '/api/public/diaries/$diaryId/comments',
        auth: false);
    final list = data['comments'] as List? ?? [];
    return list.map((c) => Comment.fromJson(c)).toList();
  }
}
