import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config.dart';
import '../../theme.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/discover_provider.dart';
import '../../widgets/diary_card.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/user_avatar.dart';
import 'diary_detail_screen.dart';
import '../profile/profile_screen.dart';
import '../timeline/write_diary_screen.dart';

const _popularTags = ['生活', '工作', '学习', '情感', '美食', '旅行', '阅读', '运动'];

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  Timer? _searchTimer;
  String _searchMode = 'diary'; // 'diary' | 'user'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(discoverProvider.notifier).fetchDiaries(refresh: true);
      }
    });
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {}); // rebuild to show/hide clear button
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final keyword = _searchCtrl.text.trim();
      if (_searchMode == 'user') {
        ref.read(discoverProvider.notifier).searchUsers(keyword);
      } else {
        ref.read(discoverProvider.notifier).setKeywordFilter(keyword.isEmpty ? null : keyword);
      }
    });
  }

  void _onScroll() {
    if (!mounted) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      final state = ref.read(discoverProvider);
      if (!state.isLoading && state.hasMore) {
        ref.read(discoverProvider.notifier).fetchDiaries();
      }
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WriteDiaryScreen()),
          );
          if (result == true) {
            ref.read(discoverProvider.notifier).fetchDiaries(refresh: true);
          }
        },
        backgroundColor: AppTheme.accent,
        child: const Icon(Icons.edit, color: Colors.white, size: 22),
      ),
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
                  // Search bar with diary/user mode tabs
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(color: Colors.grey[200]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: _searchMode == 'diary'
                                  ? '搜索日记、标签、昵称或心情'
                                  : '搜索用户名或昵称',
                              hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                              prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textMuted),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? GestureDetector(
                                      onTap: () {
                                        _searchCtrl.clear();
                                        ref.read(discoverProvider.notifier).setKeywordFilter(null);
                                      },
                                      child: const Icon(Icons.close, size: 16, color: AppTheme.textMuted),
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          children: [
                            _buildSearchModeTab('日记', _searchMode == 'diary', () {
                              setState(() => _searchMode = 'diary');
                              ref.read(discoverProvider.notifier).setKeywordFilter(null);
                              _searchCtrl.clear();
                            }),
                            _buildSearchModeTab('用户', _searchMode == 'user', () {
                              setState(() => _searchMode = 'user');
                              ref.read(discoverProvider.notifier).searchUsers('');
                              _searchCtrl.clear();
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (state.feedType == 'all' && _searchMode == 'diary') ...[
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
                ],
              ),
            ),
            // List
            Expanded(
              child: _searchMode == 'user'
                  ? _buildUserSearchView(state)
                  : _buildDiaryListView(state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiaryListView(DiscoverState state) {
    return state.isLoading && state.diaries.isEmpty
        ? const LoadingIndicator(message: '加载中...')
        : state.diaries.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.explore_outlined, size: 48, color: AppTheme.textMuted),
                      const SizedBox(height: 16),
                      Text(
                        state.error != null
                            ? '加载失败:\n${state.error}'
                            : '暂无公开日记',
                        style: TextStyle(
                          color: state.error != null
                              ? AppTheme.danger
                              : AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (state.error == null) ...[
                        const SizedBox(height: 8),
                        const Text(
                          '还没有人公开发布日记',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            final result = await Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const WriteDiaryScreen()),
                            );
                            if (result == true) {
                              ref
                                  .read(discoverProvider.notifier)
                                  .fetchDiaries(refresh: true);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('写一篇公开日记'),
                        ),
                      ] else ...[
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref
                              .read(discoverProvider.notifier)
                              .fetchDiaries(refresh: true),
                          child: const Text('重试'),
                        ),
                      ],
                    ],
                  ),
                ),
              )
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
                    final isAllFeed = state.feedType == 'all';
                    return DiaryCard(
                      diary: d,
                      showAuthor: true,
                      showLike: isAllFeed,
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
                      onLike: isAllFeed
                          ? () async {
                              final auth = ref.read(authProvider);
                              final clientId = 'user:${auth.user?.id ?? '0'}';
                              await ref.read(discoverProvider.notifier).toggleLike(d.id, clientId);
                            }
                          : null,
                    );
                  },
                ),
              );
  }

  Widget _buildUserSearchView(DiscoverState state) {
    final keyword = state.keywordFilter ?? '';
    if (keyword.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_search, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            const Text('搜索用户名或昵称',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
            const SizedBox(height: 4),
            const Text('找到志同道合的日记作者',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ],
        ),
      );
    }
    if (state.isLoading && state.userResults.isEmpty) {
      return const LoadingIndicator(message: '搜索中...');
    }
    if (state.diaries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_outlined, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            const Text('没有找到相关用户',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
            const SizedBox(height: 4),
            const Text('换个用户名或昵称试试',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      itemCount: state.userResults.length,
      itemBuilder: (context, index) {
        final u = state.userResults[index];
        return _buildUserCard(u);
      },
    );
  }

  Widget _buildUserCard(User u) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(userId: u.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                UserAvatar(
                  avatar: u.avatar,
                  size: 44,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(userId: u.id),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.nickname,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary),
                      ),
                      Text(
                        '@${u.username} · ${u.followerCount ?? 0} 粉丝',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textMuted),
                      ),
                      if (u.bio.isNotEmpty)
                        Text(
                          u.bio,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 16, color: AppTheme.textMuted),
              ],
            ),
          ),
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

  Widget _buildSearchModeTab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
              : null,
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w500 : FontWeight.normal,
                color: active ? AppTheme.accent : AppTheme.textSecondary)),
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
