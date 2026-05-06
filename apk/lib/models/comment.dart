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
      parentReplyId: json['parent_reply_id'] ?? json['parent_comment_id'],
      rootReplyId: json['root_reply_id'] ?? json['root_comment_id'],
      replyToIdentityId: json['reply_to_identity_id'] ?? json['reply_to_user_id'],
      identityId: json['identity_id'],
      replyToNickname: json['reply_to_nickname'],
      replyToAnonName: json['reply_to_anon_name'],
      replies: json['replies'] != null
          ? (json['replies'] as List).map((r) => Comment.fromJson(r)).toList()
          : null,
      likeCount: json['like_count'],
      liked: json['liked'],
    );
  }
}
