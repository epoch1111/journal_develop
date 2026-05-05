class ChatMessage {
  final int id;
  final int conversationId;
  final int senderId;
  final String content;
  final String createdAt;
  final int isRead;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.isRead = 0,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? 0,
      conversationId: json['conversation_id'] ?? 0,
      senderId: json['sender_id'] ?? 0,
      content: json['content'] ?? '',
      createdAt: json['created_at'] ?? '',
      isRead: json['is_read'] ?? 0,
    );
  }
}
