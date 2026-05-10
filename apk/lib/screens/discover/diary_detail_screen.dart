import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme.dart';
import '../../models/diary.dart';
import '../../models/comment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/discover_provider.dart';
import '../../services/discover_service.dart';
import '../../services/diary_service.dart';
import '../../services/upload_service.dart';
import '../../widgets/comment_tile.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/emoji_picker.dart';
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
  Diary? _privateDiary;
  bool _loading = true;
  String? _error;
  final _replyCtrl = TextEditingController();
  int? _replyingTo;
  int? _replyingToUserId;
  String? _replyingToName;
  final _imagePicker = ImagePicker();
  final _uploadService = UploadService();
  List<String> _commentImages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      Diary diary;
      if (widget.isPublic) {
        await ref.read(discoverProvider.notifier).fetchDiaryDetail(widget.diaryId);
        final state = ref.read(discoverProvider);
        if (state.error != null) {
          throw Exception(state.error);
        }
        if (state.selectedDiary == null) {
          throw Exception('日记不存在或不是公开日记');
        }
        diary = state.selectedDiary!;
        await ref.read(discoverProvider.notifier).subscribeDiary(widget.diaryId);
        if (mounted) {
          setState(() => _loading = false);
        }
      } else {
        diary = await DiaryService().fetchDiaryById(widget.diaryId);
        if (mounted) {
          setState(() {
            _privateDiary = diary;
            _loading = false;
          });
        }
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

  int _countAllComments(List<Comment> comments) {
    int count = 0;
    for (final c in comments) {
      count++;
      if (c.replies != null) {
        count += _countAllComments(c.replies!);
      }
    }
    return count;
  }

  Future<void> _sendComment() async {
    final content = _replyCtrl.text.trim();
    if (content.isEmpty && _commentImages.isEmpty) return;
    final auth = ref.read(authProvider);
    final clientId = 'user:${auth.user?.id ?? '0'}';
    try {
      await DiscoverService().commentOnDiary(widget.diaryId, clientId, content,
          parentCommentId: _replyingTo, replyToUserId: _replyingToUserId,
          imageUrls: _commentImages.isNotEmpty ? _commentImages : null);
      _replyCtrl.clear();
      setState(() {
        _replyingTo = null;
        _replyingToUserId = null;
        _replyingToName = null;
        _commentImages = [];
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

  Future<void> _pickCommentImages() async {
    final images = await _imagePicker.pickMultiImage(imageQuality: 80);
    if (images.isEmpty) return;
    final urls = <String>[];
    for (final img in images) {
      try {
        final url = await _uploadService.uploadImage(img);
        urls.add(url);
      } catch (e) {
        print('UPLOAD ERROR: $e');
      }
    }
    if (urls.isNotEmpty && mounted) {
      setState(() => _commentImages.addAll(urls));
    }
  }

  void _removeCommentImage(int index) {
    setState(() => _commentImages.removeAt(index));
  }

  Future<void> _toggleCommentLike(Comment comment) async {
    print('LIKE: commentId=${comment.id} liked=${comment.liked} authorName=${comment.authorName}');
    if (comment.liked == true) {
      await ref.read(discoverProvider.notifier).unlikeComment(comment.id);
    } else {
      await ref.read(discoverProvider.notifier).likeComment(comment.id);
    }
  }

  Widget _buildActionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }

  Future<void> _toggleLike() async {
    final diary = widget.isPublic
        ? ref.read(discoverProvider).selectedDiary
        : _privateDiary;
    if (diary == null) return;
    final auth = ref.read(authProvider);
    final clientId = 'user:${auth.user?.id ?? '0'}';
    try {
      if (diary.liked == true) {
        await DiscoverService().unlikeDiary(diary.id, clientId);
      } else {
        await DiscoverService().likeDiary(diary.id, clientId);
      }
      _load();
    } catch (e) {
      print('LIKE ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  void _showReportDiaryDialog(Diary diary) {
    final reasons = ['骚扰', '垃圾信息', '色情内容', '暴力内容', '侵犯隐私', '诈骗', '其他'];
    String? selectedReason;
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInnerState) => AlertDialog(
          title: const Text('举报日记'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('举报原因', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: reasons.map((r) => GestureDetector(
                    onTap: () => setInnerState(() => selectedReason = r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selectedReason == r ? AppTheme.dangerLight : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(r, style: TextStyle(fontSize: 13, color: selectedReason == r ? AppTheme.danger : AppTheme.textSecondary)),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                const Text('补充说明（必填）', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: '请描述具体情况...', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: selectedReason != null && descCtrl.text.trim().isNotEmpty
                  ? () async {
                      Navigator.pop(ctx);
                      try {
                        await DiscoverService().reportDiary(diary.id, selectedReason!, description: descCtrl.text.trim());
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('举报成功')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('举报失败: $e')),
                          );
                        }
                      }
                    }
                  : null,
              child: const Text('提交'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(Comment comment) {
    final reasons = ['骚扰', '垃圾信息', '色情内容', '暴力内容', '侵犯隐私', '诈骗', '其他'];
    String? selectedReason;
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInnerState) => AlertDialog(
          title: const Text('举报评论'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('举报原因', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: reasons.map((r) => GestureDetector(
                    onTap: () => setInnerState(() => selectedReason = r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selectedReason == r ? AppTheme.dangerLight : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(r, style: TextStyle(fontSize: 13, color: selectedReason == r ? AppTheme.danger : AppTheme.textSecondary)),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                const Text('补充说明（必填）', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: '请描述具体情况...', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: selectedReason != null && descCtrl.text.trim().isNotEmpty
                  ? () async {
                      Navigator.pop(ctx);
                      try {
                        await DiscoverService().reportComment(comment.id, selectedReason!, description: descCtrl.text.trim());
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('举报成功')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('举报失败: $e')),
                          );
                        }
                      }
                    }
                  : null,
              child: const Text('提交'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (widget.isPublic) {
      ref.read(discoverProvider.notifier).unsubscribeDiary();
    }
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: LoadingIndicator(message: '加载中...')));
    }
    final diary = widget.isPublic
        ? ref.watch(discoverProvider).selectedDiary
        : _privateDiary;
    if (diary == null) {
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

    final diaryOwnerId = diary.userId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(diary.mood, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            const Text('日记详情', style: TextStyle(fontSize: 17)),
          ],
        ),
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
                          Row(
                            children: [
                              UserAvatar(
                                avatar: diary.authorAvatar ?? '🐰',
                                size: 28,
                                onTap: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) =>
                                        UserProfileScreen(userId: diary.userId),
                                  ));
                                },
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) =>
                                        UserProfileScreen(userId: diary.userId),
                                  ));
                                },
                                child: Text(diary.authorName!,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary)),
                              ),
                              const Spacer(),
                              Text(diary.mood, style: const TextStyle(fontSize: 28)),
                            ],
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
                  // Action bar: like + comment count + report
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Row(
                      children: [
                        _buildActionBtn(
                          diary.liked == true ? Icons.favorite : Icons.favorite_border,
                          '${diary.likeCount ?? 0}',
                          diary.liked == true ? AppTheme.danger : AppTheme.textMuted,
                          _toggleLike,
                        ),
                        const SizedBox(width: 20),
                        Row(
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 16, color: AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text('${(ref.watch(discoverProvider).comments ?? []).length} 条评论',
                                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                          ],
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _showReportDiaryDialog(diary),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.flag_outlined, size: 14, color: AppTheme.textMuted),
                                SizedBox(width: 4),
                                Text('举报', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Comments section
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('评论 (${_countAllComments(ref.watch(discoverProvider).comments ?? [])})',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 16),
                        if ((ref.watch(discoverProvider).comments ?? []).isEmpty)
                          const Text('暂无评论',
                              style: TextStyle(
                                  fontSize: 13, color: AppTheme.textSecondary))
                        else
                          ...(ref.watch(discoverProvider).comments ?? []).map((c) => CommentTile(
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
                                onLikeTap: (comment) => _toggleCommentLike(comment),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image thumbnails
                if (_commentImages.isNotEmpty)
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _commentImages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (ctx, i) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                                _commentImages[i],
                                height: 64, width: 64, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 64, height: 64,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image, size: 20),
                                )),
                          ),
                          Positioned(
                            top: 0, right: 0,
                            child: GestureDetector(
                              onTap: () => _removeCommentImage(i),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                    color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close,
                                    size: 10, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_commentImages.isNotEmpty) const SizedBox(height: 6),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _pickCommentImages,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.image_outlined,
                            size: 22, color: AppTheme.textMuted),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => showEmojiPicker(context, _replyCtrl,
                          iconColor: AppTheme.accent, bgColor: AppTheme.accentLight),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.sentiment_satisfied_alt,
                            size: 24, color: AppTheme.accent),
                      ),
                    ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
