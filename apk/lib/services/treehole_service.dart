import '../models/diary.dart';
import '../models/comment.dart';
import '../api/endpoints/treehole.dart';

class TreeholeWithReplies {
  final Diary diary;
  final List<Comment> replies;
  TreeholeWithReplies({required this.diary, required this.replies});
}

class TreeholeService {
  final TreeholeEndpoints _ep = TreeholeEndpoints();

  Future<Diary> createTreehole({
    required String mood,
    required String content,
    List<String>? imageUrls,
  }) async {
    final data = await _ep.create(mood: mood, content: content, imageUrls: imageUrls);
    return Diary.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Diary?> fetchRandomTreehole() async {
    final data = await _ep.getRandom();
    if (data.isEmpty) return null;
    return Diary.fromJson(Map<String, dynamic>.from(data));
  }

  Future<TreeholeWithReplies> fetchTreeholeDetail(int id) async {
    final data = await _ep.getDetail(id);
    final diary = Diary.fromJson(Map<String, dynamic>.from(data));
    final repliesList = (data['replies'] as List? ?? [])
        .map((r) => Comment.fromJson(Map<String, dynamic>.from(r)))
        .toList();
    return TreeholeWithReplies(diary: diary, replies: repliesList);
  }

  Future<Map<String, dynamic>> hugTreehole(int id) async {
    return await _ep.hug(id);
  }

  Future<Map<String, dynamic>> unhugTreehole(int id) async {
    return await _ep.unhug(id);
  }

  Future<Comment> replyToTreehole(
    int diaryId,
    String content, {
    int? parentReplyId,
    int? replyToIdentityId,
    String? imageUrl,
    List<String>? imageUrls,
  }) async {
    final data = await _ep.reply(
      diaryId,
      content,
      parentReplyId: parentReplyId,
      replyToIdentityId: replyToIdentityId,
      imageUrl: imageUrl,
      imageUrls: imageUrls,
    );
    return Comment.fromJson(Map<String, dynamic>.from(data['reply'] ?? data));
  }

  Future<Map<String, dynamic>> likeReply(int replyId) async {
    return await _ep.likeReply(replyId);
  }

  Future<Map<String, dynamic>> unlikeReply(int replyId) async {
    return await _ep.unlikeReply(replyId);
  }
}
