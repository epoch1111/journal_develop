import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../models/diary.dart';
import '../../models/comment.dart';
import '../../services/api_client.dart';
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
  Diary? _diary;
  List<Comment> _replies = [];
  bool _loading = true;
  final _replyCtrl = TextEditingController();
  int? _replyingTo;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient().get('/api/treehole/${widget.diaryId}', auth: false);
      if (mounted) {
        final repliesList = data['replies'] as List? ?? [];
        setState(() {
          _diary = Diary.fromJson(data);
          _replies = repliesList.map((r) => Comment.fromJson(r)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleHug() async {
    if (_diary == null) return;
    try {
      if (_diary!.liked == true) {
        await ApiClient().delete('/api/treehole/${_diary!.id}/hug');
      } else {
        await ApiClient().post('/api/treehole/${_diary!.id}/hug');
      }
      setState(() {
        _diary = Diary.fromJson({
          ..._diaryToJson(_diary!),
          'liked': !(_diary!.liked == true),
          'hug_count': (_diary!.hugCount) + (_diary!.liked == true ? -1 : 1),
        });
      });
    } catch (_) {}
  }

  Future<void> _sendReply() async {
    final content = _replyCtrl.text.trim();
    if (content.isEmpty || _diary == null) return;
    setState(() => _sending = true);
    try {
      final body = <String, dynamic>{'content': content};
      if (_replyingTo != null) body['parent_reply_id'] = _replyingTo;
      await ApiClient().post('/api/treehole/${_diary!.id}/reply', body: body);
      _replyCtrl.clear();
      setState(() {
        _replyingTo = null;
        _sending = false;
      });
      await _load();
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

  Map<String, dynamic> _diaryToJson(Diary d) => {
        'id': d.id, 'created_at': d.createdAt, 'mood': d.mood,
        'content': d.content, 'hug_count': d.hugCount,
        'comment_count': d.commentCount, 'liked': d.liked,
        'anon_name': d.anonName, 'anon_avatar': d.anonAvatar,
        'tags': d.tags,
      };

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
        appBar: AppBar(title: const Text('树洞')),
        body: const Center(child: Text('加载失败')),
      );
    }

    final diary = _diary!;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('树洞详情'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Full content card
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
                      // Header
                      Row(
                        children: [
                          Text(diary.mood, style: const TextStyle(fontSize: 26)),
                          const SizedBox(width: 10),
                          const Text('匿名漂流瓶',
                              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                          const Spacer(),
                          GestureDetector(
                            onTap: _toggleHug,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: diary.liked == true
                                    ? AppTheme.dangerLight
                                    : Colors.grey[50],
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
                                      color: diary.liked == true
                                          ? AppTheme.danger
                                          : AppTheme.textSecondary),
                                  const SizedBox(width: 4),
                                  Text('${diary.hugCount}',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: diary.liked == true
                                              ? AppTheme.danger
                                              : AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(diary.content,
                          style: const TextStyle(fontSize: 15, height: 1.7)),
                      // Tags
                      if (diary.tags != null && diary.tags!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6, runSpacing: 4,
                          children: diary.tags!
                              .split(',')
                              .where((t) => t.trim().isNotEmpty)
                              .map((t) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.purple[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('#${t.trim()}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.purple[400])),
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
                // Replies section
                if (_replies.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('回复 (${_replies.length})',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 12),
                        ..._replies.map((c) => CommentTile(
                              comment: c,
                              isAuthor: false,
                              onReplyTap: () {
                                setState(() => _replyingTo = c.id);
                                _replyCtrl.text = '回复 ${c.anonName ?? ''}: ';
                              },
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
                    maxLines: 3, minLines: 1,
                    decoration: InputDecoration(
                      hintText: _replyingTo != null ? '回复...' : '匿名回复...',
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
                                setState(() => _replyingTo = null);
                                _replyCtrl.clear();
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sending ? null : _sendReply,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _sending ? AppTheme.textMuted : AppTheme.accent,
                      shape: BoxShape.circle,
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send, color: Colors.white, size: 18),
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
