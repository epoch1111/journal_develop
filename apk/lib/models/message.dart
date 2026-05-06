class ChatMessage {
  final int id;
  final int conversationId;
  final int senderId;
  final int? receiverId;
  final String content;
  final String createdAt;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.receiverId,
    required this.content,
    required this.createdAt,
    this.isRead = false,
  });

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is bool) return v ? 1 : 0;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      return s == 'true' || s == '1' || s == 'yes';
    }
    return false;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: _toInt(json['id']),
      conversationId: _toInt(json['conversation_id']),
      senderId: _toInt(json['sender_id']),
      receiverId: json['receiver_id'] == null ? null : _toInt(json['receiver_id']),
      content: (json['content'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      isRead: _toBool(json['is_read']),
    );
  }
}
