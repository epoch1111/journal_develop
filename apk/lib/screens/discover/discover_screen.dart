import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config.dart';
import '../../theme.dart';
import '../../providers/discover_provider.dart';
import '../../widgets/diary_card.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state.dart';
import 'diary_detail_screen.dart';
import '../profile/profile_screen.dart';

const _popularTags = ['生活', '工作', '学习', '情感', '美食', '旅行', '阅读', '运动'];

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discoverProvider.notifier).fetchDiaries(refresh: true);
    });
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        final state = ref.read(discoverProvider);
        if (!state.isLoading && state.hasMore) {
          ref.read(discoverProvider.notifier).fetchDiaries();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: const BoxDecoration(color: Colors.white),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('发现同频', style: AppTheme.headingLarge),
                      const Spacer(),
                      _buildFeedChip(
                          '全部', state.feedType == 'all',
                          () => ref
                              .read(discoverProvider.notifier)
                              .setFeedType('all')),
                      const SizedBox(width: 6),
                      _buildFeedChip(
                          '已关注', state.feedType == 'following',
                          () => ref
                              .read(discoverProvider.notifier)
                              .setFeedType('following')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Mood filter row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                            '全部', state.moodFilter == null,
                            () => ref
                                .read(discoverProvider.notifier)
                                .setMoodFilter(null)),
                        ...AppConfig.moodEmojis.map((m) => _buildFilterChip(
                            m, state.moodFilter == m,
                            () => ref
                                .read(discoverProvider.notifier)
                                .setMoodFilter(m))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Tag filter row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTagChip(
                            '全部', state.tagFilter == null,
                            () => ref
                                .read(discoverProvider.notifier)
                                .setTagFilter(null)),
                        ..._popularTags.map((t) => _buildTagChip(
                            t, state.tagFilter == t,
                            () => ref
                                .read(discoverProvider.notifier)
                                .setTagFilter(t))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // List
            Expanded(
              child: state.isLoading && state.diaries.isEmpty
                  ? const LoadingIndicator(message: '加载中...')
                  : state.diaries.isEmpty
                      ? state.error != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text('加载失败:\n${state.error}',
                                    style: const TextStyle(color: AppTheme.danger),
                                    textAlign: TextAlign.center),
                              ),
                            )
                          : const EmptyState(
                          icon: Icons.explore_outlined,
                          title: '暂无公开日记',
                          subtitle: '还没有人公开发布日记')
                      : RefreshIndicator(
                          onRefresh: () => ref
                              .read(discoverProvider.notifier)
                              .fetchDiaries(refresh: true),
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            padding:
                                const EdgeInsets.only(top: 8, bottom: 20),
                            itemCount: state.diaries.length +
                                (state.hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= state.diaries.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child: SizedBox(
                                          width: 20, height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppTheme.accent))),
                                );
                              }
                              final d = state.diaries[index];
                              return DiaryCard(
                                diary: d,
                                showAuthor: true,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => DiaryDetailScreen(
                                          diaryId: d.id, isPublic: true),
                                    ),
                                  );
                                },
                                onAuthorTap: () {
                                  if (d.userId > 0) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            UserProfileScreen(
                                                userId: d.userId),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppTheme.accent : Colors.grey[100],
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                color: active ? Colors.white : AppTheme.textSecondary,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: active ? AppTheme.accent : Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: active ? AppTheme.accent : Colors.grey[200]!),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: active ? Colors.white : AppTheme.textSecondary)),
        ),
      ),
    );
  }

  Widget _buildTagChip(String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            color: active ? AppTheme.accent : Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: active ? AppTheme.accent : Colors.grey[200]!),
          ),
          child: Text(label.startsWith('#') ? label : '#$label',
              style: TextStyle(
                  fontSize: 11,
                  color: active ? Colors.white : AppTheme.textSecondary)),
        ),
      ),
    );
  }
}

class UserProfileScreen extends ConsumerWidget {
  final int userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProfileScreen.external(userId: userId);
  }
}
