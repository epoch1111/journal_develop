import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/diary.dart';
import '../models/comment.dart';
import '../services/discover_service.dart';

const _unset = Object();

class DiscoverState {
  final List<Diary> diaries;
  final bool isLoading;
  final bool isLoadingMore;
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
    this.isLoadingMore = false,
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
    Object? error = _unset,
    Object? moodFilter = _unset,
    Object? tagFilter = _unset,
    Object? keywordFilter = _unset,
    String? feedType,
    Object? selectedDiary = _unset,
    Object? comments = _unset,
    bool? isLoadingMore,
  }) {
    return DiscoverState(
      diaries: diaries ?? this.diaries,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      error: identical(error, _unset) ? this.error : error as String?,
      moodFilter: identical(moodFilter, _unset)
          ? this.moodFilter
          : moodFilter as String?,
      tagFilter: identical(tagFilter, _unset)
          ? this.tagFilter
          : tagFilter as String?,
      keywordFilter: identical(keywordFilter, _unset)
          ? this.keywordFilter
          : keywordFilter as String?,
      feedType: feedType ?? this.feedType,
      selectedDiary: identical(selectedDiary, _unset)
          ? this.selectedDiary
          : selectedDiary as Diary?,
      comments: identical(comments, _unset)
          ? this.comments
          : comments as List<Comment>?,
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
    print('DISCOVER PROVIDER: fetchDiaries refresh=$refresh page=$page moodFilter=${state.moodFilter}');
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
    } catch (e, st) {
      state = state.copyWith(isLoading: false, error: e.toString());
      print('DISCOVER ERROR: $e');
      print('DISCOVER STACK: $st');
    }
  }

  void setMoodFilter(String? mood) {
    state = state.copyWith(
      moodFilter: mood,
      page: 1,
      hasMore: true,
      feedType: 'all',
    );
    fetchDiaries(refresh: true);
  }

  void setTagFilter(String? tag) {
    state = state.copyWith(
      tagFilter: tag,
      page: 1,
      hasMore: true,
      feedType: 'all',
    );
    fetchDiaries(refresh: true);
  }

  void setKeywordFilter(String? keyword) {
    state = state.copyWith(
      keywordFilter: keyword,
      page: 1,
      hasMore: true,
      feedType: 'all',
    );
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
