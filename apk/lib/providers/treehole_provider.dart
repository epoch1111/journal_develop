import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/diary.dart';
import '../models/comment.dart';
import '../services/treehole_service.dart';

class TreeholeState {
  final Diary? current;
  final List<Comment> replies;
  final bool isLoading;
  final String? error;

  const TreeholeState({
    this.current,
    this.replies = const [],
    this.isLoading = false,
    this.error,
  });

  TreeholeState copyWith({
    Diary? current,
    List<Comment>? replies,
    bool? isLoading,
    String? error,
  }) {
    return TreeholeState(
      current: current ?? this.current,
      replies: replies ?? this.replies,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class TreeholeNotifier extends StateNotifier<TreeholeState> {
  final TreeholeService _service = TreeholeService();

  TreeholeNotifier() : super(const TreeholeState());

  Future<void> fetchRandom() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final diary = await _service.fetchRandomTreehole();
      state = state.copyWith(current: diary, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchDetail(int id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final diary = await _service.fetchTreeholeDetail(id);
      state = state.copyWith(current: diary, isLoading: false,
        replies: diary.commentCount != null ? state.replies : []);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> toggleHug(int id) async {
    try {
      if (state.current?.liked == true) {
        await _service.unhugTreehole(id);
      } else {
        await _service.hugTreehole(id);
      }
      final updated = Diary.fromJson({
        ..._diaryToJson(state.current!),
        'liked': !(state.current!.liked == true),
        'hug_count': (state.current!.hugCount) + (state.current!.liked == true ? -1 : 1),
      });
      state = state.copyWith(current: updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> reply(String content, {int? parentReplyId}) async {
    try {
      await _service.replyToTreehole(state.current!.id, content,
          parentReplyId: parentReplyId);
      await fetchDetail(state.current!.id);
      return true;
    } catch (_) {
      return false;
    }
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
