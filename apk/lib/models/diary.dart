class Diary {
  final int id;
  final String createdAt;
  final String mood;
  final String content;
  final String? aiSummary;
  final String? aiMessage;
  final String? tags;
  final int isPublic;
  final int hugCount;
  final String? imageUrl;
  final List<String>? imageUrls;
  final String? unlockDate;
  final int userId;
  final String contentType;
  final String? authorName;
  final String? authorAvatar;
  final bool? locked;
  final int? likeCount;
  final bool? liked;
  final int? commentCount;
  final String? anonName;
  final String? anonAvatar;

  Diary({
    required this.id,
    required this.createdAt,
    required this.mood,
    required this.content,
    this.aiSummary,
    this.aiMessage,
    this.tags,
    this.isPublic = 0,
    this.hugCount = 0,
    this.imageUrl,
    this.imageUrls,
    this.unlockDate,
    this.userId = 0,
    this.contentType = 'diary',
    this.authorName,
    this.authorAvatar,
    this.locked,
    this.likeCount,
    this.liked,
    this.commentCount,
    this.anonName,
    this.anonAvatar,
  });

  factory Diary.fromJson(Map<String, dynamic> json) {
    return Diary(
      id: json['id'] ?? 0,
      createdAt: json['created_at'] ?? '',
      mood: json['mood'] ?? '😊',
      content: json['content'] ?? '',
      aiSummary: json['ai_summary'],
      aiMessage: json['ai_message'],
      tags: json['tags'],
      isPublic: json['is_public'] ?? 0,
      hugCount: json['hug_count'] ?? 0,
      imageUrl: json['image_url'],
      imageUrls: json['image_urls'] != null
          ? List<String>.from(json['image_urls'])
          : null,
      unlockDate: json['unlock_date'],
      userId: json['user_id'] ?? 0,
      contentType: json['content_type'] ?? 'diary',
      authorName: json['author_name'],
      authorAvatar: json['author_avatar'],
      locked: json['locked'],
      likeCount: json['like_count'],
      liked: json['liked'],
      commentCount: json['comment_count'],
      anonName: json['anon_name'],
      anonAvatar: json['anon_avatar'],
    );
  }

  bool get isCapsule => contentType == 'capsule' || (unlockDate != null && unlockDate!.isNotEmpty);
  bool get isTreehole => contentType == 'treehole';
}
