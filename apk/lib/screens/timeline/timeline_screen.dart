import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/diary_provider.dart';
import '../../widgets/diary_card.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state.dart';
import 'write_diary_screen.dart';
import '../discover/diary_detail_screen.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(diaryProvider.notifier).fetchDiaries();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final user = ref.read(authProvider).user;
    final name = user?.nickname ?? '小兔';
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了，$name';
    if (hour < 12) return '早安，$name';
    if (hour < 18) return '下午好，$name';
    return '晚上好，$name';
  }

  String _getSubGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '失眠也没关系，我陪着你';
    if (hour < 12) return '新的一天，从这里开始';
    if (hour < 18) return '喝杯茶，记录今天的点滴';
    return '回顾今天，温柔对待自己';
  }

  @override
  Widget build(BuildContext context) {
    final diaryState = ref.watch(diaryProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_getGreeting(),
                                style: AppTheme.headingLarge),
                            const SizedBox(height: 4),
                            Text(_getSubGreeting(),
                                style: AppTheme.bodyText),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const WriteDiaryScreen(isPrivateOnly: true)),
                          );
                          if (result == true) {
                            ref.read(diaryProvider.notifier).fetchDiaries();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: const Icon(Icons.add,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search bar
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMd),
                      boxShadow: [AppTheme.cardShadowSm],
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: '搜索日记...',
                        hintStyle: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search,
                            size: 18, color: AppTheme.textMuted),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  ref
                                      .read(diaryProvider.notifier)
                                      .fetchDiaries();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (v) {
                        ref.read(diaryProvider.notifier).fetchDiaries(keyword: v);
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Diary list
            Expanded(
              child: diaryState.isLoading
                  ? const LoadingIndicator(message: '加载日记中...')
                  : diaryState.diaries.isEmpty
                      ? diaryState.error != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text('加载失败:\n${diaryState.error}',
                                    style: const TextStyle(color: AppTheme.danger),
                                    textAlign: TextAlign.center),
                              ),
                            )
                          : const EmptyState(
                          icon: Icons.book_outlined,
                          title: '还没有日记',
                          subtitle: '点击右上角 + 开始写日记吧')
                      : RefreshIndicator(
                          onRefresh: () => ref
                              .read(diaryProvider.notifier)
                              .fetchDiaries(),
                          child: ListView.builder(
                            padding:
                                const EdgeInsets.only(top: 8, bottom: 20),
                            itemCount: diaryState.diaries.length,
                            itemBuilder: (context, index) {
                              final d = diaryState.diaries[index];
                              return DiaryCard(
                                diary: d,
                                isTimeline: true,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => DiaryDetailScreen(
                                          diaryId: d.id, isPublic: false),
                                    ),
                                  );
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
}
