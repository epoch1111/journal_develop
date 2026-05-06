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

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] ?? 0,
      user1Id: json['user1_id'] ?? 0,
      user2Id: json['user2_id'] ?? 0,
      otherUserName: json['other_user']?['nickname'],
      otherUserAvatar: json['other_user']?['avatar'],
      lastMessage: json['last_message'],
      lastMessageTime: json['last_message_time'],
      unreadCount: json['unread_count'],
      createdAt: json['created_at'] ?? '',
    );
  }
}
