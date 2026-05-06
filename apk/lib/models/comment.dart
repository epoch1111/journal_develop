class Comment {
  final int id;
  final int diaryId;
  final String content;
  final String createdAt;
  final String clientId;
  final String? authorName;
  final String? authorAvatar;
  final int? authorUserId;
  final bool? isAuthor;
  final String? anonName;
  final String? anonAvatar;
  final int? parentReplyId;
  final int? rootReplyId;
  final int? replyToIdentityId;
  final int? identityId;
  final String? replyToNickname;
  final String? replyToAnonName;
  final List<Comment>? replies;
  final int? likeCount;
  final bool? liked;

  Comment({
    required this.id,
    required this.diaryId,
    required this.content,
    required this.createdAt,
    required this.clientId,
    this.authorName,
    this.authorAvatar,
    this.authorUserId,
    this.isAuthor,
    this.anonName,
    this.anonAvatar,
    this.parentReplyId,
    this.rootReplyId,
    this.replyToIdentityId,
    this.identityId,
    this.replyToNickname,
    this.replyToAnonName,
    this.replies,
    this.likeCount,
    this.liked,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    int? _toNullableInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is bool) return v ? 1 : 0;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    bool? _toNullableBool(dynamic v) {
      if (v == null) return null;
      if (v is bool) return v;
      if (v is int) return v != 0;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.toLowerCase().trim();
        if (s == 'true' || s == '1') return true;
        if (s == 'false' || s == '0') return false;
      }
      return null;
    }

    return Comment(
      id: _toNullableInt(json['id']) ?? 0,
      diaryId: _toNullableInt(json['diary_id']) ?? 0,
      content: (json['content'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      clientId: (json['client_id'] ?? '').toString(),
      authorName: (json['author_name'] ?? json['nickname'] ?? json['username'])?.toString(),
      authorAvatar: (json['author_avatar'] ?? json['avatar'])?.toString(),
      authorUserId: _toNullableInt(
          json['author_user_id'] ?? json['user_id'] ?? json['author_id']),
      isAuthor: _toNullableBool(json['is_author']),
      anonName: json['anon_name']?.toString(),
      anonAvatar: json['anon_avatar']?.toString(),
      parentReplyId: _toNullableInt(json['parent_reply_id'] ?? json['parent_comment_id']),
      rootReplyId: _toNullableInt(json['root_reply_id'] ?? json['root_comment_id']),
      replyToIdentityId: _toNullableInt(json['reply_to_identity_id'] ?? json['reply_to_user_id']),
      identityId: _toNullableInt(json['identity_id']),
      replyToNickname: json['reply_to_nickname']?.toString(),
      replyToAnonName: json['reply_to_anon_name']?.toString(),
      replies: json['replies'] != null
          ? (json['replies'] as List)
              .map((r) => Comment.fromJson(Map<String, dynamic>.from(r)))
              .toList()
          : null,
      likeCount: _toNullableInt(json['like_count']),
      liked: _toNullableBool(json['liked']),
    );
  }
}
