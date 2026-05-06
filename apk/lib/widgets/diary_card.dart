import 'package:flutter/material.dart';
import '../models/diary.dart';
import '../config.dart';
import '../theme.dart';
import '../services/api_client.dart';
import 'user_avatar.dart';

class DiaryCard extends StatelessWidget {
  final Diary diary;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;
  final bool showAuthor;
  final bool isTimeline;

  const DiaryCard({
    super.key,
    required this.diary,
    this.onTap,
    this.onAuthorTap,
    this.showAuthor = false,
    this.isTimeline = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        AppConfig.moodColors[diary.mood] ?? AppConfig.moodColors['😊']!;
    final borderColor =
        Color(int.parse(colors['border']!.replaceFirst('#', '0xFF')));
    final accentColor =
        Color(int.parse(colors['accent']!.replaceFirst('#', '0xFF')));

    if (diary.locked == true) {
      return _buildLockedCard(context, borderColor, accentColor);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Text(diary.mood, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                    ),
                    child: Text(colors['label']!,
                        style: TextStyle(
                            fontSize: 11,
                            color: borderColor,
                            fontWeight: FontWeight.w500)),
                  ),
                  const Spacer(),
                  if (showAuthor && diary.authorName != null) ...[
                    UserAvatar(
                        avatar: diary.authorAvatar ?? '🐰',
                        size: 24,
                        onTap: onAuthorTap),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onAuthorTap,
                      child: Text(diary.authorName!,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    ),
                  ],
                  if (!showAuthor)
                    Text(_formatDate(diary.createdAt),
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(
                diary.content,
                style: const TextStyle(fontSize: 14, height: 1.6),
                maxLines: isTimeline ? 5 : 20,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Tags & AI summary
            if ((diary.tags != null && diary.tags!.isNotEmpty) ||
                (diary.aiSummary != null && diary.aiSummary!.isNotEmpty))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (diary.tags != null)
                      ...diary.tags!
                          .split(',')
                          .where((t) => t.trim().isNotEmpty)
                          .map(
                            (t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusXs),
                              ),
                              child: Text(t.trim(),
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF60A5FA))),
                            ),
                          ),
                    if (diary.aiSummary != null &&
                        diary.aiSummary!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(diary.aiSummary!,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                                fontStyle: FontStyle.italic)),
                      ),
                  ],
                ),
              ),
            // Images
            if (diary.imageUrls != null && diary.imageUrls!.isNotEmpty)
              _buildImageGallery(diary.imageUrls!),
            // AI message
            if (diary.aiMessage != null && diary.aiMessage!.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🐰', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(diary.aiMessage!,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple[700],
                              height: 1.4)),
                    ),
                  ],
                ),
              ),
            // Bottom bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  if (showAuthor)
                    Text(_formatDate(diary.createdAt),
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted)),
                  const Spacer(),
                  if (diary.likeCount != null)
                    _buildStat(Icons.star_border, '${diary.likeCount}',
                        diary.liked == true ? Colors.amber : AppTheme.textMuted),
                  if (diary.commentCount != null) ...[
                    const SizedBox(width: 14),
                    _buildStat(Icons.chat_bubble_outline,
                        '${diary.commentCount}', AppTheme.textMuted),
                  ],
                  if (isTimeline && diary.isPublic == 1) ...[
                    const SizedBox(width: 14),
                    const Icon(Icons.public, size: 16, color: AppTheme.textMuted),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedCard(
      BuildContext context, Color borderColor, Color accentColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 20, color: AppTheme.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('时光胶囊 · 等待解锁',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Text('${diary.unlockDate} 解锁',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Text(diary.mood, style: const TextStyle(fontSize: 20)),
        ],
      ),
    );
  }

  String _fullUrl(String url) {
    if (url.startsWith('http')) return url;
    return '${ApiClient().baseUrl}$url';
  }

  Widget _buildImageGallery(List<String> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();
    final count = urls.length.clamp(1, 9);
    final crossAxisCount =
        count == 1 ? 1 : (count == 2 || count == 4 ? 2 : 3);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
            childAspectRatio: 1,
          ),
          itemCount: count,
          itemBuilder: (context, index) => Image.network(
            _fullUrl(urls[index]),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[100],
                child: const Icon(Icons.broken_image, color: Colors.grey)),
          ),
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 3),
        Text(count,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }

  String _formatDate(String date) {
    if (date.length >= 16) return date.substring(5, 16);
    if (date.length >= 10) return date.substring(5, 10);
    return date;
  }
}
