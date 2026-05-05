import '../models/diary.dart';
import '../models/comment.dart';
import 'api_client.dart';

class TreeholeService {
  final ApiClient _client = ApiClient();

  Future<Diary> createTreehole({
    required String mood,
    required String content,
  }) async {
    final data = await _client.post('/api/treehole', body: {
      'mood': mood,
      'content': content,
    });
    return Diary.fromJson(data);
  }

  Future<Diary> fetchRandomTreehole() async {
    final data = await _client.get('/api/treehole/random', auth: false);
    return Diary.fromJson(data);
  }

  Future<Diary> fetchTreeholeDetail(int id) async {
    final data = await _client.get('/api/treehole/$id', auth: false);
    return Diary.fromJson(data);
  }

  Future<void> hugTreehole(int id) async {
    await _client.post('/api/treehole/$id/hug');
  }

  Future<void> unhugTreehole(int id) async {
    await _client.delete('/api/treehole/$id/hug');
  }

  Future<Comment> replyToTreehole(int id, String content,
      {int? parentReplyId, String? identityKey}) async {
    final body = <String, dynamic>{'content': content};
    if (parentReplyId != null) body['parent_reply_id'] = parentReplyId;
    if (identityKey != null) body['identity_key'] = identityKey;
    final data = await _client.post('/api/treehole/$id/reply', body: body);
    return Comment.fromJson(data);
  }

  Future<void> likeReply(int replyId) async {
    await _client.post('/api/treehole/replies/$replyId/like');
  }

  Future<void> unlikeReply(int replyId) async {
    await _client.delete('/api/treehole/replies/$replyId/like');
  }
}
