import 'package:flutter/material.dart';
import '../models/comment.dart';
import 'user_avatar.dart';

class CommentTile extends StatelessWidget {
  final Comment comment;
  final bool isAuthor; // whether this comment is by the diary author
  final VoidCallback? onAvatarTap;
  final VoidCallback? onReplyTap;
  final VoidCallback? onLikeTap;

  const CommentTile({
    super.key,
    required this.comment,
    this.isAuthor = false,
    this.onAvatarTap,
    this.onReplyTap,
    this.onLikeTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = comment.authorName ?? comment.anonName ?? '匿名';
    final avatar = comment.authorAvatar ?? comment.anonAvatar ?? '🐰';
    final isTreehole = comment.anonName != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            avatar: avatar,
            size: 32,
            onTap: isTreehole ? null : onAvatarTap,
          ),
          const SizedBox(width: 10),
          Expanded(
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    if (isAuthor) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber[200]!),
                        ),
                        child: const Text('作者',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.amber,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.content,
                    style: const TextStyle(fontSize: 14, height: 1.5)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(_formatTime(comment.createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                    const SizedBox(width: 16),
                    if (onLikeTap != null)
                      GestureDetector(
                        onTap: onLikeTap,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              comment.liked == true
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 14,
                              color: comment.liked == true
                                  ? Colors.red[300]
                                  : Colors.grey[400],
                            ),
                            if (comment.likeCount != null &&
                                comment.likeCount! > 0)
                              Text(' ${comment.likeCount}',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[400])),
                          ],
                        ),
                      ),
                    if (onReplyTap != null) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: onReplyTap,
                        child: Text('回复',
                            style:
                                TextStyle(fontSize: 11, color: Colors.grey[400])),
                      ),
                    ],
                  ],
                ),
                if (comment.replies != null && comment.replies!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: comment.replies!
                            .map((r) => _ReplyItem(
                                  reply: r,
                                  onAvatarTap: onAvatarTap,
                                ))
                            .toList(),
                      ),
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

class _ReplyItem extends StatelessWidget {
  final Comment reply;
  final VoidCallback? onAvatarTap;

  const _ReplyItem({required this.reply, this.onAvatarTap});

  @override
  Widget build(BuildContext context) {
    final name = reply.authorName ?? reply.anonName ?? '匿名';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
          children: [
            TextSpan(
              text: name,
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
            TextSpan(text: '：${reply.content}'),
          ],
        ),
      ),
    );
  }
}
