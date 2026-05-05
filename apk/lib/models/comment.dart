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
    this.replies,
    this.likeCount,
    this.liked,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? 0,
      diaryId: json['diary_id'] ?? 0,
      content: json['content'] ?? '',
      createdAt: json['created_at'] ?? '',
      clientId: json['client_id'] ?? '',
      authorName: json['author_name'],
      authorAvatar: json['author_avatar'],
      authorUserId: json['author_user_id'],
      isAuthor: json['is_author'],
      anonName: json['anon_name'],
      anonAvatar: json['anon_avatar'],
      parentReplyId: json['parent_reply_id'],
      rootReplyId: json['root_reply_id'],
      replyToIdentityId: json['reply_to_identity_id'],
      replies: json['replies'] != null
          ? (json['replies'] as List).map((r) => Comment.fromJson(r)).toList()
          : null,
      likeCount: json['like_count'],
      liked: json['liked'],
    );
  }
}
