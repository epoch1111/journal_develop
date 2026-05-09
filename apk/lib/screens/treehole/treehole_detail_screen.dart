import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme.dart';
import '../../models/comment.dart';
import '../../services/upload_service.dart';
import '../../services/safety_service.dart';
import '../../providers/treehole_provider.dart';
import '../../widgets/comment_tile.dart';
import '../../widgets/loading_indicator.dart';

class TreeholeDetailScreen extends ConsumerStatefulWidget {
  final int diaryId;
  const TreeholeDetailScreen({super.key, required this.diaryId});

  @override
  ConsumerState<TreeholeDetailScreen> createState() =>
      _TreeholeDetailScreenState();
}

class _TreeholeDetailScreenState extends ConsumerState<TreeholeDetailScreen> {
  final _replyCtrl = TextEditingController();
  final _imagePicker = ImagePicker();
  final _uploadService = UploadService();
  int? _replyingTo;
  int? _replyingToIdentityId;
  String? _replyingToName;
  bool _sending = false;
  List<String> _replyImages = [];

  @override
  void initState() {
    super.initState();
    // 通过 provider 加载，让 provider 管理 replies 状态
    Future.microtask(() {
      ref.read(treeholeProvider.notifier).fetchDetail(widget.diaryId);
    });
  }

  Future<void> _sendReply() async {
    final content = _replyCtrl.text.trim();
    if (content.isEmpty && _replyImages.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(treeholeProvider.notifier).reply(
        content,
        parentReplyId: _replyingTo,
        imageUrls: _replyImages,
      );
      _replyCtrl.clear();
      setState(() {
        _replyingTo = null;
        _replyingToIdentityId = null;
        _replyingToName = null;
        _replyImages = [];
        _sending = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('回复成功')));
      }
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('回复失败: $e')));
      }
    }
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

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _replyingToIdentityId = null;
      _replyingToName = null;
    });
    _replyCtrl.clear();
  }

  void _reportTreehole(int diaryId) {
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
                          targetId: diaryId,
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

  void _toggleReplyLike(Comment comment) {
    if (comment.liked == true) {
      ref.read(treeholeProvider.notifier).unlikeReply(comment.id);
    } else {
      ref.read(treeholeProvider.notifier).likeReply(comment.id);
    }
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(treeholeProvider);
    final diary = state.current;

    if (state.isLoading || diary == null) {
      return const Scaffold(
          body: Center(child: LoadingIndicator(message: '加载中...')));
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('树洞详情'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined, size: 20),
            color: AppTheme.textMuted,
            onPressed: () => _reportTreehole(diary.id),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: [AppTheme.cardShadow],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(diary.mood, style: const TextStyle(fontSize: 26)),
                          const SizedBox(width: 10),
                          const Text('匿名漂流瓶',
                              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              ref.read(treeholeProvider.notifier).toggleHug(diary.id);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: diary.liked == true ? AppTheme.dangerLight : Colors.grey[50],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                      diary.liked == true
                                          ? Icons.volunteer_activism
                                          : Icons.volunteer_activism_outlined,
                                      size: 16,
                                      color: diary.liked == true ? AppTheme.danger : AppTheme.textSecondary),
                                  const SizedBox(width: 4),
                                  Text('${diary.hugCount}',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: diary.liked == true ? AppTheme.danger : AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(diary.content,
                          style: const TextStyle(fontSize: 15, height: 1.7)),
                      if (diary.imageUrls != null && diary.imageUrls!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _DetailImageGallery(urls: diary.imageUrls!),
                      ],
                      if (diary.tags != null && diary.tags!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6, runSpacing: 4,
                          children: diary.tags!
                              .split(',')
                              .where((t) => t.trim().isNotEmpty)
                              .map((t) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.purple[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('#${t.trim()}',
                                        style: TextStyle(fontSize: 11, color: Colors.purple[400])),
                                  ))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(diary.createdAt,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (state.replies.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('回复 (${state.replies.length})',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        const SizedBox(height: 12),
                        ...state.replies.map((c) => CommentTile(
                              comment: c,
                              isAuthor: c.isAuthor == true,
                              onReplyTap: (comment) {
                                setState(() {
                                  _replyingTo = comment.id;
                                  _replyingToIdentityId = comment.identityId;
                                  _replyingToName = comment.anonName ?? '匿名';
                                });
                                _replyCtrl.clear();
                              },
                              onLikeTap: (comment) => _toggleReplyLike(comment),
                              onReportTap: () => _reportReply(c.id),
                            )),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    child: const Text('暂无回复，来做第一个回应的人吧',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                              width: 72, height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 0, right: 0,
                            child: GestureDetector(
                              onTap: () => _removeReplyImage(i),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_replyImages.isNotEmpty) const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _pickReplyImages,
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.image_outlined, size: 22, color: AppTheme.textMuted),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _replyCtrl,
                        maxLines: 3, minLines: 1,
                        decoration: InputDecoration(
                          hintText: _replyingTo != null ? '回复 $_replyingToName...' : '匿名回复...',
                          hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                          filled: true,
                          fillColor: AppTheme.bg,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _sending ? null : _sendReply,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _sending ? AppTheme.textMuted : const Color(0xFF9333EA),
                          shape: BoxShape.circle,
                        ),
                        child: _sending
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send, color: Colors.white, size: 18),
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

class _DetailImageGallery extends StatelessWidget {
  final List<String> urls;
  const _DetailImageGallery({required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    if (urls.length == 1) {
      return GestureDetector(
        onTap: () => _showFullImage(context, urls[0]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(urls[0],
            width: double.infinity, height: 200, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        ),
      );
    }
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) => GestureDetector(
          onTap: () => _showFullImage(context, urls[i]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(urls[i],
              width: 100, height: 100, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 100, height: 100, color: Colors.grey[200],
                child: const Icon(Icons.broken_image, size: 24),
              )),
          ),
        ),
      ),
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
            child: Image.network(url, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }
}
