import '../models/diary.dart';
import '../models/comment.dart';
import 'api_client.dart'
    show ApiClient, ApiException, AuthException;

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
      final list = data['items'] as List? ?? [];
      return {
        'diaries': list.map((d) => Diary.fromJson(d)).toList(),
        'has_more': data['has_more'] ?? false,
      };
    }

    final params = <String, String>{'page': page.toString()};
    if (mood != null && mood.isNotEmpty) params['mood'] = mood;
    if (tag != null && tag.isNotEmpty) params['tag'] = tag;
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
    if (clientId != null && clientId.isNotEmpty) params['client_id'] = clientId;

    // 发现页是公开接口，直接用 auth:false
    print('DISCOVER URL: ${_client.baseUrl}/api/public/diaries params=$params');
    final raw = await _client.get(
      '/api/public/diaries',
      auth: false,
      queryParams: params,
    );
    print('DISCOVER raw: $raw');

    // raw 必须是 {'items': [...], 'has_more': ...} 格式
    List<dynamic> items;
    if (raw is Map && raw.containsKey('items') && raw['items'] is List) {
      items = raw['items'] as List;
    } else if (raw is Map && raw.containsKey('data') && raw['data'] is List) {
      items = raw['data'] as List;
    } else {
      print('DISCOVER unexpected: $raw');
      items = [];
    }

    return {
      'diaries': items.map((d) => Diary.fromJson(Map<String, dynamic>.from(d))).toList(),
      'has_more': (raw is Map) ? (raw['has_more'] ?? false) : false,
    };
  }

  Future<Diary> fetchPublicDiaryById(int id) async {
    final data = await _client.get('/api/public/diaries/$id', auth: false);
    return Diary.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> likeDiary(int diaryId, String clientId) async {
    await _client.post('/api/public/diaries/$diaryId/like',
        body: {'client_id': clientId});
  }

  Future<void> unlikeDiary(int diaryId, String clientId) async {
    await _client.delete(
        '/api/public/diaries/$diaryId/like?client_id=$clientId');
  }

  Future<Comment> commentOnDiary(int diaryId, String clientId, String content,
      {int? parentReplyId, int? replyToUserId}) async {
    final body = <String, dynamic>{
      'client_id': clientId,
      'content': content,
    };
    if (parentReplyId != null) body['parent_comment_id'] = parentReplyId;
    if (replyToUserId != null) body['reply_to_user_id'] = replyToUserId;
    final data = await _client.post(
        '/api/public/diaries/$diaryId/comments',
        body: body,
        auth: true);
    return Comment.fromJson(data['comment']);
  }

  Future<List<Comment>> fetchComments(int diaryId) async {
    final data = await _client.get(
      '/api/public/diaries/$diaryId/comments',
      auth: true,
    );

    // Backend returns list directly, not wrapped in {"data": [...]}
    final list = data is List ? (data as List) : (data['data'] as List? ?? []);
    return list
        .map((c) => Comment.fromJson(Map<String, dynamic>.from(c)))
        .toList();
  }

  // 评论点赞
  Future<Map<String, dynamic>> likeComment(int commentId) async {
    return await _client.post('/api/public/diaries/comments/$commentId/like', auth: true);
  }

  // 取消评论点赞
  Future<Map<String, dynamic>> unlikeComment(int commentId) async {
    return await _client.delete('/api/public/diaries/comments/$commentId/like', auth: true);
  }

  // 举报评论
  Future<void> reportComment(int commentId, String reason) async {
    await _client.post('/api/reports',
        body: {
          'target_type': 'comment',
          'target_id': commentId,
          'reason': reason,
        },
        auth: true);
  }
}
