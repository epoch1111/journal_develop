class User {
  final int id;
  final String username;
  final String? email;
  final String nickname;
  final String avatar;
  final String bio;
  final String interests;
  final String createdAt;
  final String updatedAt;
  final int? followingCount;
  final int? followerCount;
  final bool? isFollowing;

  User({
    required this.id,
    required this.username,
    this.email,
    required this.nickname,
    required this.avatar,
    required this.bio,
    required this.interests,
    required this.createdAt,
    required this.updatedAt,
    this.followingCount,
    this.followerCount,
    this.isFollowing,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'],
      nickname: json['nickname'] ?? '小兔',
      avatar: json['avatar'] ?? '🐰',
      bio: json['bio'] ?? '今天也在认真生活',
      interests: json['interests'] ?? '日记,生活,小确幸',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      followingCount: json['following_count'],
      followerCount: json['follower_count'],
      isFollowing: json['is_following'],
    );
  }

  Map<String, dynamic> toJson() => {
    'nickname': nickname,
    'avatar': avatar,
    'bio': bio,
    'interests': interests,
  };
}
