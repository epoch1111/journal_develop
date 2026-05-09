import '../client.dart';

class TreeholeEndpoints {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> create({
    required String mood,
    required String content,
    List<String>? imageUrls,
  }) async {
    final body = <String, dynamic>{
      'mood': mood,
      'content': content,
    };
    if (imageUrls != null && imageUrls.isNotEmpty) {
      body['image_urls'] = imageUrls;
    }
    return await _client.post('/api/treehole', body: body);
  }

  Future<Map<String, dynamic>> getRandom() async {
    return await _client.get('/api/treehole/random', auth: false);
  }

  Future<Map<String, dynamic>> getDetail(int id) async {
    return await _client.get('/api/treehole/$id', auth: true);
  }

  Future<Map<String, dynamic>> hug(int id) async {
    return await _client.post('/api/treehole/$id/hug');
  }

  Future<Map<String, dynamic>> unhug(int id) async {
    return await _client.delete('/api/treehole/$id/hug');
  }

  Future<Map<String, dynamic>> reply(
    int diaryId,
    String content, {
    int? parentReplyId,
    int? replyToIdentityId,
    String? imageUrl,
    List<String>? imageUrls,
  }) async {
    final body = <String, dynamic>{'content': content};
    if (parentReplyId != null) body['parent_reply_id'] = parentReplyId;
    if (replyToIdentityId != null) body['reply_to_identity_id'] = replyToIdentityId;
    if (imageUrl != null) body['image_url'] = imageUrl;
    if (imageUrls != null && imageUrls.isNotEmpty) body['image_urls'] = imageUrls;
    return await _client.post('/api/treehole/$diaryId/reply', body: body);
  }

  Future<Map<String, dynamic>> likeReply(int replyId) async {
    return await _client.post('/api/treehole/replies/$replyId/like', auth: true);
  }

  Future<Map<String, dynamic>> unlikeReply(int replyId) async {
    return await _client.delete('/api/treehole/replies/$replyId/like', auth: true);
  }
}
