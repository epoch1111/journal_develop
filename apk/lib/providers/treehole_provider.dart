import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/diary.dart';
import '../models/comment.dart';
import '../services/treehole_service.dart';

class _HistoryEntry {
  final int id;
  final Diary diary;
  _HistoryEntry(this.id, this.diary);
}

class TreeholeState {
  final Diary? current;
  final List<Comment> replies;
  final bool isLoading;
  final String? error;
  final bool canGoBack;
  final bool canGoForward;

  const TreeholeState({
    this.current,
    this.replies = const [],
    this.isLoading = false,
    this.error,
    this.canGoBack = false,
    this.canGoForward = false,
  });

  TreeholeState copyWith({
    Diary? current,
    List<Comment>? replies,
    bool? isLoading,
    String? error,
    bool? canGoBack,
    bool? canGoForward,
  }) {
    return TreeholeState(
      current: current ?? this.current,
      replies: replies ?? this.replies,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      canGoBack: canGoBack ?? this.canGoBack,
      canGoForward: canGoForward ?? this.canGoForward,
    );
  }
}

class TreeholeNotifier extends StateNotifier<TreeholeState> {
  final TreeholeService _service = TreeholeService();
  final List<_HistoryEntry> _history = [];
  int _historyIdx = -1;

  TreeholeNotifier() : super(const TreeholeState());

  void _updateNavState() {
    state = state.copyWith(
      canGoBack: _historyIdx > 0,
      canGoForward: _historyIdx < _history.length - 1,
    );
  }

  Future<void> fetchRandom() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final diary = await _service.fetchRandomTreehole();
      if (diary == null) {
        state = state.copyWith(current: null, isLoading: false);
        return;
      }
      // Truncate forward history if navigating back then loading new
      if (_historyIdx != _history.length - 1) {
        _history.removeRange(_historyIdx + 1, _history.length);
      }
      _history.add(_HistoryEntry(diary.id, diary));
      _historyIdx = _history.length - 1;
      state = state.copyWith(current: diary, isLoading: false);
      _updateNavState();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void goBack() {
    if (_historyIdx <= 0) return;
    _historyIdx--;
    state = state.copyWith(current: _history[_historyIdx].diary);
    _updateNavState();
  }

  void goNext() {
    if (_historyIdx >= _history.length - 1) {
      fetchRandom();
    } else {
      _historyIdx++;
      state = state.copyWith(current: _history[_historyIdx].diary);
      _updateNavState();
    }
  }

  Future<void> fetchDetail(int id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _service.fetchTreeholeDetail(id);
      state = state.copyWith(
        current: result.diary,
        replies: result.replies,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> toggleHug(int id) async {
    if (state.current == null) return false;
    print('HUG toggle: id=$id liked=${state.current!.liked}');
    try {
      if (state.current!.liked == true) {
        await _service.unhugTreehole(id);
      } else {
        await _service.hugTreehole(id);
      }
      final updated = Diary.fromJson({
        ..._diaryToJson(state.current!),
        'liked': !(state.current!.liked == true),
        'hug_count': (state.current!.hugCount) + (state.current!.liked == true ? -1 : 1),
      });
      print('HUG updated: liked=${updated.liked} count=${updated.hugCount}');
      // Sync history entry
      if (_historyIdx >= 0 && _historyIdx < _history.length) {
        _history[_historyIdx] = _HistoryEntry(updated.id, updated);
      }
      state = state.copyWith(current: updated);
      return true;
    } catch (e) {
      print('HUG error: $e');
      return false;
    }
  }

  Future<bool> reply(String content, {int? parentReplyId, List<String>? imageUrls}) async {
    if (state.current == null) return false;
    try {
      await _service.replyToTreehole(state.current!.id, content,
          parentReplyId: parentReplyId, imageUrls: imageUrls);
      await fetchDetail(state.current!.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> likeReply(int replyId) async {
    // 乐观更新
    final oldReplies = state.replies;
    final newReplies = _toggleReplyInList(state.replies, replyId, true);
    state = state.copyWith(replies: newReplies);
    try {
      await _service.likeReply(replyId);
    } catch (e) {
      // 回滚
      state = state.copyWith(replies: oldReplies);
    }
  }

  Future<void> unlikeReply(int replyId) async {
    // 乐观更新
    final oldReplies = state.replies;
    final newReplies = _toggleReplyInList(state.replies, replyId, false);
    state = state.copyWith(replies: newReplies);
    try {
      await _service.unlikeReply(replyId);
    } catch (e) {
      // 回滚
      state = state.copyWith(replies: oldReplies);
    }
  }

  List<Comment> _toggleReplyInList(List<Comment> replies, int replyId, bool liked) {
    return replies.map((c) {
      if (c.id == replyId) {
        final newCount = (c.likeCount ?? 0) + (liked ? 1 : -1);
        return Comment(
          id: c.id, diaryId: c.diaryId, content: c.content, createdAt: c.createdAt,
          clientId: c.clientId, authorName: c.authorName, authorAvatar: c.authorAvatar,
          authorUserId: c.authorUserId, isAuthor: c.isAuthor, anonName: c.anonName,
          anonAvatar: c.anonAvatar, parentReplyId: c.parentReplyId, rootReplyId: c.rootReplyId,
          replyToIdentityId: c.replyToIdentityId, identityId: c.identityId,
          replyToNickname: c.replyToNickname, replyToAnonName: c.replyToAnonName,
          replies: c.replies,
          likeCount: newCount < 0 ? 0 : newCount,
          liked: liked,
        );
      }
      if (c.replies != null && c.replies!.isNotEmpty) {
        return Comment(
          id: c.id, diaryId: c.diaryId, content: c.content, createdAt: c.createdAt,
          clientId: c.clientId, authorName: c.authorName, authorAvatar: c.authorAvatar,
          authorUserId: c.authorUserId, isAuthor: c.isAuthor, anonName: c.anonName,
          anonAvatar: c.anonAvatar, parentReplyId: c.parentReplyId, rootReplyId: c.rootReplyId,
          replyToIdentityId: c.replyToIdentityId, identityId: c.identityId,
          replyToNickname: c.replyToNickname, replyToAnonName: c.replyToAnonName,
          replies: _toggleReplyInList(c.replies!, replyId, liked),
          likeCount: c.likeCount, liked: c.liked,
        );
      }
      return c;
    }).toList();
  }

  Map<String, dynamic> _diaryToJson(Diary d) => {
    'id': d.id, 'created_at': d.createdAt, 'mood': d.mood,
    'content': d.content, 'ai_summary': d.aiSummary, 'ai_message': d.aiMessage,
    'tags': d.tags, 'is_public': d.isPublic, 'hug_count': d.hugCount,
    'image_url': d.imageUrl, 'image_urls': d.imageUrls,
    'unlock_date': d.unlockDate, 'user_id': d.userId, 'content_type': d.contentType,
    'author_name': d.authorName, 'author_avatar': d.authorAvatar,
    'like_count': d.likeCount, 'liked': d.liked, 'comment_count': d.commentCount,
    'anon_name': d.anonName, 'anon_avatar': d.anonAvatar,
  };
}

final treeholeProvider = StateNotifierProvider<TreeholeNotifier, TreeholeState>((ref) {
  return TreeholeNotifier();
});
