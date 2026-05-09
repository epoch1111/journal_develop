import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme.dart';
import '../../providers/treehole_provider.dart';
import '../../services/upload_service.dart';
import '../../services/safety_service.dart';
import '../../widgets/comment_tile.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state.dart';
import 'treehole_detail_screen.dart';
import 'treehole_compose_screen.dart';

class TreeholeScreen extends ConsumerStatefulWidget {
  const TreeholeScreen({super.key});

  @override
  ConsumerState<TreeholeScreen> createState() => _TreeholeScreenState();
}

class _TreeholeScreenState extends ConsumerState<TreeholeScreen>
    with TickerProviderStateMixin {
  final _replyCtrl = TextEditingController();
  final _imagePicker = ImagePicker();
  final _uploadService = UploadService();
  int? _replyingTo;
  String? _replyingToName;
  List<String> _replyImages = [];
  late AnimationController _hugAnimCtrl;
  late Animation<double> _hugAnim;

  @override
  void initState() {
    super.initState();
    _hugAnimCtrl = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _hugAnim = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _hugAnimCtrl, curve: Curves.easeOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(treeholeProvider.notifier).fetchRandom();
    });
  }

  Future<void> _pickReplyImages() async {
    final images = await _imagePicker.pickMultiImage();
    if (images.isEmpty) return;
    final urls = <String>[];
    for (final img in images) {
      try {
        final url = await _uploadService.uploadImage(img.path);
        urls.add(url);
      } catch (_) {}
    }
    if (urls.isNotEmpty && mounted) {
      setState(() => _replyImages = [..._replyImages, ...urls]);
    }
  }

  void _removeReplyImage(int idx) {
    setState(() => _replyImages.removeAt(idx));
  }

  Future<void> _sendReply() async {
    final content = _replyCtrl.text.trim();
    if (content.isEmpty && _replyImages.isEmpty) return;
    final ok = await ref
        .read(treeholeProvider.notifier)
        .reply(content, parentReplyId: _replyingTo, imageUrls: _replyImages);
    if (ok && mounted) {
      _replyCtrl.clear();
      setState(() {
        _replyingTo = null;
        _replyingToName = null;
        _replyImages = [];
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('回复成功')));
    }
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _replyingToName = null;
    });
    _replyCtrl.clear();
  }

  void _reportTreehole(int id) {
    final reasons = ['骚扰', '垃圾信息', '色情内容', '暴力内容', '侵犯隐私', '诈骗', '其他'];
    String? selectedReason;
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInnerState) => AlertDialog(
          title: const Text('举报树洞'),
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
                        await SafetyService().createReport(
                          reportType: 'treehole',
                          targetId: id,
                          reason: selectedReason!,
                          description: descCtrl.text.trim(),
                        );
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

  void _reportReply(int replyId) {
    final reasons = ['骚扰', '垃圾信息', '色情内容', '暴力内容', '侵犯隐私', '诈骗', '其他'];
    String? selectedReason;
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInnerState) => AlertDialog(
          title: const Text('举报回复'),
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
                        await SafetyService().createReport(
                          reportType: 'treehole_reply',
                          targetId: replyId,
                          reason: selectedReason!,
                          description: descCtrl.text.trim(),
                        );
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
    _replyCtrl.dispose();
    _hugAnimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(treeholeProvider);
    final current = state.current;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: const BoxDecoration(color: Colors.white),
              child: Row(
                children: [
                  Text('树洞', style: AppTheme.headingLarge),
                  const Spacer(),
                  // Prev / Next navigation
                  _NavButton(
                    icon: Icons.arrow_back_ios,
                    enabled: state.canGoBack,
                    onTap: () => ref.read(treeholeProvider.notifier).goBack(),
                    tooltip: '上一个',
                  ),
                  const SizedBox(width: 4),
                  _NavButton(
                    icon: Icons.arrow_forward_ios,
                    enabled: true,
                    onTap: () => ref.read(treeholeProvider.notifier).goNext(),
                    tooltip: '下一个',
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () {
                      ref.read(treeholeProvider.notifier).fetchRandom();
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('换一个', style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accent,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: state.isLoading
                  ? const LoadingIndicator(message: '正在打捞漂流瓶...')
                  : current == null
                      ? const EmptyState(
                          icon: Icons.waves_outlined,
                          title: '还没有漂流瓶',
                          subtitle: '成为第一个投递的人吧')
                      : SingleChildScrollView(
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                      MaterialPageRoute(
                                    builder: (_) => TreeholeDetailScreen(
                                        diaryId: current.id),
                                  ));
                                },
                                child: Container(
                                  margin: const EdgeInsets.all(16),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusLg),
                                    boxShadow: [AppTheme.cardShadow],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(current.mood,
                                              style: const TextStyle(
                                                  fontSize: 26)),
                                          const SizedBox(width: 10),
                                          const Text('匿名漂流瓶',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color:
                                                      AppTheme.textSecondary)),
                                          const Spacer(),
                                          _HugButton(
                                            liked: current.liked == true,
                                            count: current.hugCount,
                                            onTap: () {
                                              final wasLiked = current.liked == true;
                                              ref.read(treeholeProvider.notifier).toggleHug(current.id);
                                              if (!wasLiked) {
                                                _hugAnimCtrl.forward().then((_) => _hugAnimCtrl.reverse());
                                              }
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () => _reportTreehole(current.id),
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[50],
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: const Icon(Icons.flag_outlined,
                                                  size: 16, color: AppTheme.textMuted),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(current.content,
                                          style: const TextStyle(
                                              fontSize: 15, height: 1.7)),
                                      if (current.imageUrls != null &&
                                          current.imageUrls!.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        _ImageGallery(urls: current.imageUrls!),
                                      ],
                                      const SizedBox(height: 12),
                                      Text(current.createdAt,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textMuted)),
                                    ],
                                  ),
                                ),
                              ),
                              if (current.commentCount != null &&
                                  current.commentCount! > 0)
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMd),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          '回复 (${current.commentCount})',
                                          style: AppTheme.headingMedium),
                                      const SizedBox(height: 12),
                                      if (state.replies.isNotEmpty)
                                        ...state.replies.map((c) =>
                                            CommentTile(
                                              comment: c,
                                              isAuthor:
                                                  c.isAuthor == true,
                                              onReplyTap: (comment) {
                                                setState(() {
                                                  _replyingTo = comment.id;
                                                  _replyingToName = comment.anonName ?? '匿名';
                                                });
                                                _replyCtrl.clear();
                                              },
                                              onLikeTap: (comment) async {
                                                try {
                                                  if (comment.liked == true) {
                                                    await ref.read(treeholeProvider.notifier).unlikeReply(comment.id);
                                                  } else {
                                                    await ref.read(treeholeProvider.notifier).likeReply(comment.id);
                                                  }
                                                } catch (_) {}
                                              },
                                              onReportTap: () => _reportReply(c.id),
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
                border: Border(
                    top: BorderSide(color: Color(0xFFF3F4F6))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reply image previews
                  if (_replyImages.isNotEmpty)
                    SizedBox(
                      height: 72,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _replyImages.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _replyImages[i],
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 0, right: 0,
                              child: GestureDetector(
                                onTap: () => _removeReplyImage(i),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close,
                                      size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Reply-to indicator (matching Web's thReplyIndicator)
                  if (_replyingTo != null && _replyingToName != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('回复 $_replyingToName',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF9333EA))),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _cancelReply,
                            child: const Icon(Icons.close, size: 14, color: Color(0xFF9333EA)),
                          ),
                        ],
                      ),
                    ),
                  if (_replyImages.isNotEmpty) const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _pickReplyImages,
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.image_outlined,
                              size: 22, color: AppTheme.textMuted),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _replyCtrl,
                          maxLines: 3,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText:
                                _replyingTo != null ? '回复 $_replyingToName...' : '匿名回复...',
                            hintStyle: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _sendReply,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFF9333EA),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // FAB for compose
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TreeholeComposeScreen()),
          );
        },
        backgroundColor: const Color(0xFFEC4899),
        child: const Icon(Icons.edit_outlined, color: Colors.white),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final String tooltip;

  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: enabled ? Colors.grey[100] : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: enabled ? AppTheme.textPrimary : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

class _HugButton extends StatelessWidget {
  final bool liked;
  final int count;
  final VoidCallback onTap;

  const _HugButton({
    required this.liked,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: liked ? AppTheme.dangerLight : Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              liked ? Icons.volunteer_activism : Icons.volunteer_activism_outlined,
              size: 16,
              color: liked ? AppTheme.danger : AppTheme.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                color: liked ? AppTheme.danger : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageGallery extends StatelessWidget {
  final List<String> urls;

  const _ImageGallery({required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (urls.length == 1)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onTap: () => _showFullImage(context, urls[0]),
              child: Image.network(
                urls[0],
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          )
        else
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: urls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GestureDetector(
                  onTap: () => _showFullImage(context, urls[i]),
                  child: Image.network(
                    urls[i],
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, size: 24),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: InteractiveViewer(
            child: Image.network(url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }
}
