import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/diary.dart';
import '../models/comment.dart';
import '../services/discover_service.dart';

class DiscoverState {
  final List<Diary> diaries;
  final bool isLoading;
  final bool hasMore;
  final int page;
  final String? error;
  final String? moodFilter;
  final String? tagFilter;
  final String? keywordFilter;
  final String feedType; // 'all' or 'following'
  final Diary? selectedDiary;
  final List<Comment>? comments;

  const DiscoverState({
    this.diaries = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.page = 1,
    this.error,
    this.moodFilter,
    this.tagFilter,
    this.keywordFilter,
    this.feedType = 'all',
    this.selectedDiary,
    this.comments,
  });

  DiscoverState copyWith({
    List<Diary>? diaries,
    bool? isLoading,
    bool? hasMore,
    int? page,
    String? error,
    String? moodFilter,
    String? tagFilter,
    String? keywordFilter,
    String? feedType,
    Diary? selectedDiary,
    List<Comment>? comments,
  }) {
    return DiscoverState(
      diaries: diaries ?? this.diaries,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      error: error,
      moodFilter: moodFilter,
      tagFilter: tagFilter,
      keywordFilter: keywordFilter,
      feedType: feedType ?? this.feedType,
      selectedDiary: selectedDiary,
      comments: comments,
    );
  }
}

class DiscoverNotifier extends StateNotifier<DiscoverState> {
  final DiscoverService _service = DiscoverService();

  DiscoverNotifier() : super(const DiscoverState());

  Future<void> fetchDiaries({bool refresh = false}) async {
    if (state.isLoading) return;
    final page = refresh ? 1 : state.page;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _service.fetchPublicDiaries(
        page: page,
        mood: state.moodFilter,
        tag: state.tagFilter,
        keyword: state.keywordFilter,
        feed: state.feedType == 'following' ? 'following' : null,
      );
      final newList = refresh
          ? (result['diaries'] as List<Diary>)
          : [...state.diaries, ...(result['diaries'] as List<Diary>)];
      state = state.copyWith(
        diaries: newList,
        isLoading: false,
        hasMore: result['has_more'] ?? false,
        page: refresh ? 2 : page + 1,
      );
    } catch (e) {
      print('DISCOVER fetchDiaries ERROR: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setMoodFilter(String? mood) {
    state = state.copyWith(moodFilter: mood, diaries: [], page: 1, hasMore: true);
    fetchDiaries(refresh: true);
  }

  void setTagFilter(String? tag) {
    state = state.copyWith(tagFilter: tag, diaries: [], page: 1, hasMore: true);
    fetchDiaries(refresh: true);
  }

  void setKeywordFilter(String? keyword) {
    state = state.copyWith(keywordFilter: keyword, diaries: [], page: 1, hasMore: true);
    fetchDiaries(refresh: true);
  }

  void setFeedType(String type) {
    state = state.copyWith(feedType: type, diaries: [], page: 1, hasMore: true);
    fetchDiaries(refresh: true);
  }

  Future<void> fetchDiaryDetail(int id) async {
    state = state.copyWith(isLoading: true);
    try {
      final diary = await _service.fetchPublicDiaryById(id);
      state = state.copyWith(selectedDiary: diary, isLoading: false);
      await fetchComments(id);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchComments(int diaryId) async {
    try {
      final comments = await _service.fetchComments(diaryId);
      state = state.copyWith(comments: comments);
    } catch (_) {}
  }

  Future<bool> toggleLike(int diaryId, String clientId) async {
    try {
      final idx = state.diaries.indexWhere((d) => d.id == diaryId);
      if (idx == -1) return false;
      final diary = state.diaries[idx];
      if (diary.liked == true) {
        await _service.unlikeDiary(diaryId, clientId);
      } else {
        await _service.likeDiary(diaryId, clientId);
      }
      final newList = [...state.diaries];
      newList[idx] = Diary.fromJson({
        ..._diaryToJson(diary),
        'liked': !(diary.liked == true),
        'like_count': (diary.likeCount ?? 0) + (diary.liked == true ? -1 : 1),
      });
      state = state.copyWith(diaries: newList);
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
  };

  void clearSelected() {
    state = state.copyWith(selectedDiary: null, comments: null);
  }
}

final discoverProvider = StateNotifierProvider<DiscoverNotifier, DiscoverState>((ref) {
  return DiscoverNotifier();
});
