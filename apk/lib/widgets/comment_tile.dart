import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../theme.dart';
import 'user_avatar.dart';

class CommentTile extends StatelessWidget {
  final Comment comment;
  final bool isAuthor;
  final bool isChild;
  final VoidCallback? onAvatarTap;
  final void Function(Comment)? onReplyTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onReportTap;

  const CommentTile({
    super.key,
    required this.comment,
    this.isAuthor = false,
    this.isChild = false,
    this.onAvatarTap,
    this.onReplyTap,
    this.onLikeTap,
    this.onReportTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = comment.authorName ?? comment.anonName ?? '匿名';
    final avatar = comment.authorAvatar ?? comment.anonAvatar ?? '🐰';
    final isTreehole = comment.anonName != null;
    final replyToName = comment.replyToNickname ?? comment.replyToAnonName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isChild) const SizedBox(width: 32),
          UserAvatar(
            avatar: avatar,
            size: isChild ? 28 : 32,
            onTap: isTreehole ? null : onAvatarTap,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isChild ? AppTheme.bg : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: isTreehole ? null : onAvatarTap,
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: isChild ? 11 : 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (isAuthor) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.amber[50],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.amber[200]!),
                              ),
                              child: const Text('作者',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Color(0xFFD97706),
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ],
                      ),
                      if (replyToName != null && replyToName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('回复 $replyToName',
                            style: TextStyle(
                                fontSize: 10,
                                color: isTreehole
                                    ? Colors.purple[400]
                                    : AppTheme.accent)),
                      ],
                      const SizedBox(height: 4),
                      Text(comment.content,
                          style: const TextStyle(fontSize: 13, height: 1.5)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(_formatTime(comment.createdAt),
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textSecondary)),
                          if (onLikeTap != null) ...[
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: onLikeTap,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    comment.liked == true
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 12,
                                    color: comment.liked == true
                                        ? AppTheme.danger
                                        : AppTheme.textSecondary,
                                  ),
                                  if (comment.likeCount != null &&
                                      comment.likeCount! > 0)
                                    Text(' ${comment.likeCount}',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                          if (onReplyTap != null) ...[
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => onReplyTap!(comment),
                              child: Text('回复',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: isTreehole
                                          ? Colors.purple[400]
                                          : AppTheme.accent)),
                            ),
                          ],
                          if (onReportTap != null) ...[
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: onReportTap,
                              child: const Text('举报',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.textMuted)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Nested replies (recursive)
                if (comment.replies != null && comment.replies!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      children: comment.replies!
                          .map((r) => CommentTile(
                                comment: r,
                                isAuthor: r.isAuthor == true,
                                isChild: true,
                                onAvatarTap: onAvatarTap,
                                onReplyTap: onReplyTap,
                                onLikeTap: onLikeTap,
                                onReportTap: onReportTap,
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String time) {
    if (time.length >= 16) return time.substring(5, 16);
    return time;
  }
}
