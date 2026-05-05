import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../providers/treehole_provider.dart';
import '../../widgets/comment_tile.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state.dart';
import 'treehole_detail_screen.dart';

class TreeholeScreen extends ConsumerStatefulWidget {
  const TreeholeScreen({super.key});

  @override
  ConsumerState<TreeholeScreen> createState() => _TreeholeScreenState();
}

class _TreeholeScreenState extends ConsumerState<TreeholeScreen> {
  final _replyCtrl = TextEditingController();
  int? _replyingTo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(treeholeProvider.notifier).fetchRandom();
    });
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final content = _replyCtrl.text.trim();
    if (content.isEmpty) return;
    final ok = await ref
        .read(treeholeProvider.notifier)
        .reply(content, parentReplyId: _replyingTo);
    if (ok && mounted) {
      _replyCtrl.clear();
      setState(() => _replyingTo = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('回复成功')));
    }
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
                                          GestureDetector(
                                            onTap: () => ref
                                                .read(treeholeProvider
                                                    .notifier)
                                                .toggleHug(current.id),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 8),
                                              decoration: BoxDecoration(
                                                color: current.liked == true
                                                    ? AppTheme.dangerLight
                                                    : Colors.grey[50],
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                      current.liked == true
                                                          ? Icons
                                                              .volunteer_activism
                                                          : Icons
                                                              .volunteer_activism_outlined,
                                                      size: 16,
                                                      color: current.liked ==
                                                              true
                                                          ? AppTheme.danger
                                                          : AppTheme
                                                              .textMuted),
                                                  const SizedBox(width: 4),
                                                  Text('${current.hugCount}',
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          color: current.liked ==
                                                                  true
                                                              ? AppTheme.danger
                                                              : AppTheme
                                                                  .textSecondary)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(current.content,
                                          style: const TextStyle(
                                              fontSize: 15, height: 1.7)),
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
                                              onReplyTap: () {
                                                setState(() =>
                                                    _replyingTo = c.id);
                                                _replyCtrl.text =
                                                    '回复 ${c.anonName ?? ''}: ';
                                              },
                                              onLikeTap: () {},
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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyCtrl,
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText:
                            _replyingTo != null ? '回复...' : '匿名回复...',
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
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
