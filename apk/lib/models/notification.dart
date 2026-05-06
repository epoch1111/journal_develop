class AppNotification {
  final int id;
  final String type;
  final String message;
  final String? relatedId;
  final bool isRead;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.message,
    this.relatedId,
    this.isRead = false,
    required this.createdAt,
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

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: _toInt(json['id']),
      type: json['type'] ?? '',
      message: json['content'] ?? json['title'] ?? '',
      relatedId: json['entity_id']?.toString(),
      isRead: _toBool(json['is_read']),
      createdAt: json['created_at'] ?? '',
    );
  }
}
