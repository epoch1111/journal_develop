import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/diary.dart';
import '../services/diary_service.dart';

class DiaryState {
  final List<Diary> diaries;
  final bool isLoading;
  final bool isLoadingStats;
  final String? error;
  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? moodStats;

  const DiaryState({
    this.diaries = const [],
    this.isLoading = false,
    this.isLoadingStats = false,
    this.error,
    this.stats,
    this.moodStats,
  });

  DiaryState copyWith({
    List<Diary>? diaries,
    bool? isLoading,
    bool? isLoadingStats,
    String? error,
    Map<String, dynamic>? stats,
    Map<String, dynamic>? moodStats,
  }) {
    return DiaryState(
      diaries: diaries ?? this.diaries,
      isLoading: isLoading ?? this.isLoading,
      isLoadingStats: isLoadingStats ?? this.isLoadingStats,
      error: error,
      stats: stats ?? this.stats,
      moodStats: moodStats ?? this.moodStats,
    );
  }
}

class DiaryNotifier extends StateNotifier<DiaryState> {
  final DiaryService _service = DiaryService();

  DiaryNotifier() : super(const DiaryState());

  Future<void> fetchDiaries({String? date}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final diaries = await _service.fetchDiaries(date: date);
      state = state.copyWith(diaries: diaries, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchDiariesByDate(String date) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final diaries = await _service.fetchDiariesByDate(date);
      state = state.copyWith(diaries: diaries, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> saveDiary({
    required String mood,
    required String content,
    String? tags,
    bool isPublic = false,
    String? unlockDate,
    List<String>? imageUrls,
  }) async {
    try {
      await _service.saveDiary(
        mood: mood,
        content: content,
        tags: tags,
        isPublic: isPublic,
        unlockDate: unlockDate,
        imageUrls: imageUrls,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> updateDiary(int id, {
    String? mood, String? content, String? tags,
    bool? isPublic, List<String>? imageUrls,
  }) async {
    try {
      await _service.updateDiary(id,
        mood: mood, content: content, tags: tags,
        isPublic: isPublic, imageUrls: imageUrls,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteDiary(int id) async {
    try {
      await _service.deleteDiary(id);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<void> fetchStats() async {
    state = state.copyWith(isLoadingStats: true);
    try {
      final stats = await _service.fetchStats();
      state = state.copyWith(stats: stats, isLoadingStats: false);
    } catch (e) {
      state = state.copyWith(isLoadingStats: false, error: e.toString());
    }
  }

  Future<void> fetchMoodStats() async {
    try {
      final moodStats = await _service.fetchMoodStats();
      state = state.copyWith(moodStats: moodStats);
    } catch (_) {}
  }
}

final diaryProvider = StateNotifierProvider<DiaryNotifier, DiaryState>((ref) {
  return DiaryNotifier();
});
