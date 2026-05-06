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

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is bool) return v ? 1 : 0;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static bool? _toNullableBool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      if (s == 'true' || s == '1' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'no') return false;
    }
    return null;
  }

  factory Diary.fromJson(Map<String, dynamic> json) {
    return Diary(
      id: _toInt(json['id']),
      createdAt: json['created_at'] ?? '',
      mood: json['mood'] ?? '😊',
      content: json['content'] ?? '',
      aiSummary: json['ai_summary'],
      aiMessage: json['ai_message'],
      tags: json['tags'],
      isPublic: _toInt(json['is_public']),
      hugCount: _toInt(json['hug_count']),
      imageUrl: json['image_url'],
      imageUrls: json['image_urls'] != null
          ? List<String>.from(json['image_urls'])
          : null,
      unlockDate: json['unlock_date'],
      userId: _toInt(json['user_id']),
      contentType: json['content_type'] ?? 'diary',
      authorName: json['author_name'],
      authorAvatar: json['author_avatar'],
      locked: _toNullableBool(json['locked']),
      likeCount: json['like_count'] == null ? null : _toInt(json['like_count']),
      commentCount: json['comment_count'] == null ? null : _toInt(json['comment_count']),
      liked: _toNullableBool(json['liked']),
      anonName: json['anon_name'],
      anonAvatar: json['anon_avatar'],
    );
  }

  bool get isCapsule => contentType == 'capsule' || (unlockDate != null && unlockDate!.isNotEmpty);
  bool get isTreehole => contentType == 'treehole';
}
