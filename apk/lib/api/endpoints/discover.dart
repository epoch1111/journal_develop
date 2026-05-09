import '../client.dart';

class DiscoverEndpoints {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> getPublicDiaries({
    int page = 1,
    String? mood,
    String? tag,
    String? keyword,
    String? clientId,
  }) async {
    final params = <String, String>{'page': page.toString()};
    if (mood != null && mood.isNotEmpty) params['mood'] = mood;
    if (tag != null && tag.isNotEmpty) params['tag'] = tag;
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
    if (clientId != null && clientId.isNotEmpty) params['client_id'] = clientId;
    return await _client.get('/api/public/diaries', auth: false, queryParams: params);
  }

  Future<Map<String, dynamic>> getPublicDiaryById(int id) async {
    return await _client.get('/api/public/diaries/$id', auth: false);
  }

  Future<void> likeDiary(int diaryId, String clientId) async {
    await _client.post('/api/public/diaries/$diaryId/like',
        body: {'client_id': clientId});
  }

  Future<void> unlikeDiary(int diaryId, String clientId) async {
    await _client.delete('/api/public/diaries/$diaryId/like?client_id=$clientId');
  }

  Future<Map<String, dynamic>> commentOnDiary(
    int diaryId,
    String clientId,
    String content, {
    int? parentCommentId,
    int? replyToUserId,
    String? imageUrl,
    List<String>? imageUrls,
  }) async {
    final body = <String, dynamic>{
      'client_id': clientId,
      'content': content,
    };
    if (parentCommentId != null) body['parent_comment_id'] = parentCommentId;
    if (replyToUserId != null) body['reply_to_user_id'] = replyToUserId;
    if (imageUrl != null) body['image_url'] = imageUrl;
    if (imageUrls != null) body['image_urls'] = imageUrls;
    return await _client.post('/api/public/diaries/$diaryId/comments',
        body: body, auth: true);
  }

  Future<Map<String, dynamic>> getComments(int diaryId) async {
    return await _client.get('/api/public/diaries/$diaryId/comments', auth: true);
  }

  Future<Map<String, dynamic>> likeComment(int commentId) async {
    return await _client.post('/api/public/diaries/comments/$commentId/like', auth: true);
  }

  Future<Map<String, dynamic>> unlikeComment(int commentId) async {
    return await _client.delete('/api/public/diaries/comments/$commentId/like', auth: true);
  }

  Future<void> reportDiary(int diaryId, String reason, {String? description}) async {
    final body = <String, dynamic>{
      'target_type': 'diary',
      'target_id': diaryId,
      'reason': _mapReason(reason),
    };
    if (description != null && description.isNotEmpty) body['description'] = description;
    await _client.post('/api/reports', body: body, auth: true);
  }

  Future<void> reportComment(int commentId, String reason, {String? description}) async {
    final body = <String, dynamic>{
      'target_type': 'comment',
      'target_id': commentId,
      'reason': _mapReason(reason),
    };
    if (description != null && description.isNotEmpty) body['description'] = description;
    await _client.post('/api/reports', body: body, auth: true);
  }

  static String _mapReason(String reason) {
    const map = {
      '骚扰': 'harassment',
      '垃圾信息': 'spam',
      '色情内容': 'sexual',
      '暴力内容': 'violence',
      '侵犯隐私': 'privacy',
      '诈骗': 'scam',
      '其他': 'other',
    };
    return map[reason] ?? reason;
  }

  Future<Map<String, dynamic>> getFollowingFeed({int page = 1}) async {
    return await _client.get('/api/me/following-feed',
        queryParams: {'page': page.toString()});
  }

  Future<Map<String, dynamic>> searchUsers(String keyword) async {
    return await _client.get('/api/users/search',
        queryParams: {'keyword': keyword}, auth: true);
  }
}
