import '../models/diary.dart';
import '../models/user.dart';
import '../models/comment.dart';
import '../api/endpoints/discover.dart';

class DiscoverService {
  final DiscoverEndpoints _ep = DiscoverEndpoints();

  Future<Map<String, dynamic>> fetchPublicDiaries({
    int page = 1,
    String? mood,
    String? tag,
    String? keyword,
    String? clientId,
  }) async {
    final data = await _ep.getPublicDiaries(
      page: page,
      mood: mood,
      tag: tag,
      keyword: keyword,
      clientId: clientId,
    );
    final items = data['items'] as List? ?? data['data'] as List? ?? [];
    return {
      'diaries': items.map((d) => Diary.fromJson(Map<String, dynamic>.from(d))).toList(),
      'has_more': data['has_more'] ?? false,
    };
  }

  Future<Diary> fetchPublicDiaryById(int id) async {
    final data = await _ep.getPublicDiaryById(id);
    return Diary.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> likeDiary(int diaryId, String clientId) async {
    await _ep.likeDiary(diaryId, clientId);
  }

  Future<void> unlikeDiary(int diaryId, String clientId) async {
    await _ep.unlikeDiary(diaryId, clientId);
  }

  Future<Comment> commentOnDiary(
    int diaryId,
    String clientId,
    String content, {
    int? parentCommentId,
    int? replyToUserId,
    String? imageUrl,
    List<String>? imageUrls,
  }) async {
    final data = await _ep.commentOnDiary(
      diaryId, clientId, content,
      parentCommentId: parentCommentId,
      replyToUserId: replyToUserId,
      imageUrl: imageUrl,
      imageUrls: imageUrls,
    );
    return Comment.fromJson(Map<String, dynamic>.from(data['comment'] ?? data));
  }

  Future<List<Comment>> fetchComments(int diaryId) async {
    final data = await _ep.getComments(diaryId);
    final list = data['data'] as List? ?? [];
    return list.map((c) => Comment.fromJson(Map<String, dynamic>.from(c))).toList();
  }

  Future<Map<String, dynamic>> likeComment(int commentId) async {
    return await _ep.likeComment(commentId);
  }

  Future<Map<String, dynamic>> unlikeComment(int commentId) async {
    return await _ep.unlikeComment(commentId);
  }

  Future<void> reportDiary(int diaryId, String reason, {String? description}) async {
    await _ep.reportDiary(diaryId, reason, description: description);
  }

  Future<void> reportComment(int commentId, String reason, {String? description}) async {
    await _ep.reportComment(commentId, reason, description: description);
  }

  Future<List<Diary>> fetchFollowingFeed({int page = 1}) async {
    final data = await _ep.getFollowingFeed(page: page);
    final items = data['items'] as List? ?? data['data'] as List? ?? [];
    return items.map((d) => Diary.fromJson(Map<String, dynamic>.from(d))).toList();
  }

  Future<List<User>> searchUsers(String keyword) async {
    final data = await _ep.searchUsers(keyword);
    final list = data['users'] as List? ?? [];
    return list.map((u) => User.fromJson(Map<String, dynamic>.from(u))).toList();
  }
}
