import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../models/diary.dart';
import '../../models/comment.dart';
import '../../providers/auth_provider.dart';
import '../../services/discover_service.dart';
import '../../services/diary_service.dart';
import '../../widgets/comment_tile.dart';
import '../../widgets/loading_indicator.dart';
import 'discover_screen.dart';

class DiaryDetailScreen extends ConsumerStatefulWidget {
  final int diaryId;
  final bool isPublic;

  const DiaryDetailScreen({
    super.key,
    required this.diaryId,
    this.isPublic = true,
  });

  @override
  ConsumerState<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends ConsumerState<DiaryDetailScreen> {
  Diary? _diary;
  List<Comment> _comments = [];
  bool _loading = true;
  String? _error;
  final _replyCtrl = TextEditingController();
  int? _replyingTo;
  int? _replyingToUserId;
  String? _replyingToName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      Diary diary;
      List<Comment> comments;
      if (widget.isPublic) {
        diary = await DiscoverService().fetchPublicDiaryById(widget.diaryId);
        comments = await DiscoverService().fetchComments(widget.diaryId);
      } else {
        diary = await DiaryService().fetchDiaryById(widget.diaryId);
        comments = [];
      }
      if (mounted) {
        setState(() {
          _diary = diary;
          _comments = comments;
          _loading = false;
        });
      }
    } catch (e, st) {
      if (mounted) {
        print('DIARY DETAIL ERROR: $e');
        print('DIARY DETAIL STACK: $st');
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _sendComment() async {
    final content = _replyCtrl.text.trim();
    if (content.isEmpty) return;
    final auth = ref.read(authProvider);
    final clientId = 'user:${auth.user?.id ?? '0'}';
    try {
      await DiscoverService().commentOnDiary(widget.diaryId, clientId, content,
          parentReplyId: _replyingTo, replyToUserId: _replyingToUserId);
      _replyCtrl.clear();
      setState(() {
        _replyingTo = null;
        _replyingToUserId = null;
        _replyingToName = null;
      });
      _load();
    } catch (e) {
      print('COMMENT ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('评论失败: $e')));
      }
    }
  }

  Future<void> _toggleCommentLike(Comment comment) async {
    try {
      print('LIKE: commentId=${comment.id} liked=${comment.liked}');
      if (comment.liked == true) {
        final result = await DiscoverService().unlikeComment(comment.id);
        print('UNLIKE result: $result');
      } else {
        final result = await DiscoverService().likeComment(comment.id);
        print('LIKE result: $result');
      }
      _load();
    } catch (e, st) {
      print('LIKE ERROR: $e');
      print('LIKE STACK: $st');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  void _showReportDialog(Comment comment) {
    final reasons = ['骚扰', '垃圾信息', '色情内容', '暴力内容', '侵犯隐私', '诈骗', '其他'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('举报评论'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((r) => ListTile(
            title: Text(r),
            onTap: () async {
              Navigator.pop(ctx);
              try {
                await DiscoverService().reportComment(comment.id, r);
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('举报成功')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('举报失败: $e')));
                }
              }
            },
          )).toList(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: LoadingIndicator(message: '加载中...')));
    }
    if (_diary == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('日记')),
        body: Center(
          child: Text(
            _error ?? '加载失败',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    final diary = _diary!;
    final diaryOwnerId = diary.userId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${diary.mood} 日记详情'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (diary.authorName != null)
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) =>
                                    UserProfileScreen(userId: diary.userId),
                              ));
                            },
                            child: Row(
                              children: [
                                Text(diary.authorAvatar ?? '🐰',
                                    style: const TextStyle(fontSize: 24)),
                                const SizedBox(width: 8),
                                Text(diary.authorName!,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(diary.content,
                            style:
                                const TextStyle(fontSize: 15, height: 1.7)),
                        const SizedBox(height: 16),
                        Text(diary.createdAt,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                        if (diary.tags != null && diary.tags!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: diary.tags!
                                  .split(',')
                                  .where((t) => t.trim().isNotEmpty)
                                  .map((t) => Chip(
                                      label: Text(t.trim(),
                                          style: const TextStyle(fontSize: 11)),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact))
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Divider
                  Container(height: 8, color: AppTheme.bg),
                  // Comments section
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('评论 (${_comments.length})',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 16),
                        if (_comments.isEmpty)
                          const Text('暂无评论',
                              style: TextStyle(
                                  fontSize: 13, color: AppTheme.textSecondary))
                        else
                          ..._comments.map((c) => CommentTile(
                                comment: c,
                                isAuthor: c.isAuthor == true ||
                                    c.authorUserId == diaryOwnerId,
                                onAvatarTap: c.authorUserId != null
                                    ? () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => UserProfileScreen(
                                                userId: c.authorUserId!),
                                          ),
                                        );
                                      }
                                    : null,
                                onReplyTap: (comment) {
                                  setState(() {
                                    _replyingTo = comment.id;
                                    _replyingToUserId = comment.authorUserId;
                                    _replyingToName = comment.authorName ?? comment.anonName ?? '用户';
                                  });
                                  _replyCtrl.clear();
                                },
                                onLikeTap: () => _toggleCommentLike(c),
                                onReportTap: () => _showReportDialog(c),
                              )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Reply input
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyCtrl,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: _replyingTo != null
                          ? '回复 $_replyingToName...'
                          : '写评论...',
                      hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.bg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      suffixIcon: _replyingTo != null
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () {
                                setState(() {
                                  _replyingTo = null;
                                  _replyingToUserId = null;
                                  _replyingToName = null;
                                });
                                _replyCtrl.clear();
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sendComment,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
