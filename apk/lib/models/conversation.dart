class Conversation {
  final int id;
  final int user1Id;
  final int user2Id;
  final String? otherUserName;
  final String? otherUserAvatar;
  final String? lastMessage;
  final String? lastMessageTime;
  final int? unreadCount;
  final String createdAt;

  Conversation({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    this.otherUserName,
    this.otherUserAvatar,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount,
    required this.createdAt,
  });

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is bool) return v ? 1 : 0;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  factory Conversation.fromJson(Map json) {
    final other = json['other_user'];

    return Conversation(
      id: _toInt(json['id']),
      user1Id: _toInt(json['user1_id']),
      user2Id: _toInt(json['user2_id']),
      otherUserName: other is Map
          ? (other['nickname'] ?? other['username'] ?? other['name'] ?? '用户').toString()
          : '用户',
      otherUserAvatar: other is Map
          ? (other['avatar'] ?? other['avatar_url'] ?? '').toString()
          : '',
      lastMessage: json['last_message']?.toString(),
      lastMessageTime: (json['last_message_at'] ?? json['last_message_time'])?.toString(),
      unreadCount: _toInt(json['unread_count']),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}
