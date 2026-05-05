class GreetRequest {
  final int id;
  final int fromUserId;
  final int toUserId;
  final String status;
  final String createdAt;
  final String updatedAt;
  final String? fromUserName;
  final String? fromUserAvatar;
  final String? toUserName;
  final String? toUserAvatar;

  GreetRequest({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.fromUserName,
    this.fromUserAvatar,
    this.toUserName,
    this.toUserAvatar,
  });

  factory GreetRequest.fromJson(Map<String, dynamic> json) {
    return GreetRequest(
      id: json['id'] ?? 0,
      fromUserId: json['from_user_id'] ?? 0,
      toUserId: json['to_user_id'] ?? 0,
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      fromUserName: json['from_user_name'],
      fromUserAvatar: json['from_user_avatar'],
      toUserName: json['to_user_name'],
      toUserAvatar: json['to_user_avatar'],
    );
  }
}
