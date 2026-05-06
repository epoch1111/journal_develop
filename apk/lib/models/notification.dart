class AppNotification {
  final int id;
  final String type;
  final String message;
  final String? relatedId;
  final int isRead;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.message,
    this.relatedId,
    this.isRead = 0,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? 0,
      type: json['type'] ?? '',
      message: json['content'] ?? json['title'] ?? '',
      relatedId: json['entity_id']?.toString(),
      isRead: json['is_read'] ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }
}
