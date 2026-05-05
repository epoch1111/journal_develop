import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme.dart';

class UserAvatar extends StatelessWidget {
  final String avatar;
  final double size;
  final VoidCallback? onTap;
  final String? heroTag;

  const UserAvatar({
    super.key,
    required this.avatar,
    this.size = 40,
    this.onTap,
    this.heroTag,
  });

  bool get _isImageUrl {
    return avatar.startsWith('/uploads/') ||
        avatar.startsWith('http://') ||
        avatar.startsWith('https://');
  }

  String get _fullUrl {
    if (avatar.startsWith('http')) return avatar;
    return '${ApiClient().baseUrl}$avatar';
  }

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: _isImageUrl ? null : AppTheme.avatarGradient,
          color: _isImageUrl ? AppTheme.accentLight : null,
          shape: BoxShape.circle,
          boxShadow: [AppTheme.cardShadowSm],
        ),
        clipBehavior: Clip.antiAlias,
        child: _isImageUrl
            ? Image.network(
                _fullUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: AppTheme.avatarGradient,
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 24),
                ),
              )
            : Center(
                child: Text(avatar,
                    style: TextStyle(fontSize: size * 0.55)),
              ),
      ),
    );

    if (heroTag != null) {
      return Hero(tag: heroTag!, child: child);
    }
    return child;
  }
}
