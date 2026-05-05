import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../providers/diary_provider.dart';
import '../../widgets/loading_indicator.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(diaryProvider.notifier).fetchStats();
      ref.read(diaryProvider.notifier).fetchMoodStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(diaryProvider);
    final stats = state.stats;
    final moodStats = state.moodStats;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('统计看板'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: state.isLoadingStats
          ? const LoadingIndicator(message: '加载统计数据...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mood distribution
                  if (stats != null && stats['mood_distribution'] != null) ...[
                    const Text('心情分布',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 12),
                    ...((stats['mood_distribution'] as List)
                        .map((item) => _buildMoodBar(
                              item['mood'] ?? '',
                              item['count'] ?? 0,
                              item['label'] ?? '',
                              stats['total_diaries'] ?? 1,
                            ))),
                    const SizedBox(height: 24),
                  ],
                  // Stats numbers
                  if (stats != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        boxShadow: [AppTheme.cardShadow],
                      ),
                      child: Column(
                        children: [
                          _buildStatRow('日记总数', '${stats['total_diaries'] ?? 0}'),
                          const Divider(height: 24),
                          _buildStatRow('公开日记', '${stats['public_diaries'] ?? 0}'),
                          const Divider(height: 24),
                          _buildStatRow('时光胶囊', '${stats['capsules'] ?? 0}'),
                        ],
                      ),
                    ),
                  ],
                  // Calendar heatmap
                  if (stats != null && stats['calendar_data'] != null) ...[
                    const SizedBox(height: 24),
                    const Text('日记日历',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: (stats['calendar_data'] as List)
                          .map((item) => _buildCalendarDot(
                                item['moods'] is List && (item['moods'] as List).isNotEmpty
                                    ? (item['moods'] as List).first.toString()
                                    : '',
                                item['count'] ?? 0,
                              ))
                          .toList(),
                    ),
                  ],
                  // Mood stats
                  if (moodStats != null && moodStats['recent'] != null) ...[
                    const SizedBox(height: 24),
                    const Text('最近心情',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (moodStats['recent'] as List)
                          .map((item) => _buildRecentMood(
                                item['mood'] ?? '',
                                item['date'] ?? '',
                              ))
                          .toList(),
                    ),
                  ],
                  if (stats == null && moodStats == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('暂无数据，去写一篇日记吧',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildMoodBar(String mood, int count, String label, int total) {
    final pct = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(mood, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
          const SizedBox(width: 4),
          Text('$count', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.grey[100],
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        Text(value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary)),
      ],
    );
  }

  Widget _buildCalendarDot(String mood, int count) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: count > 0 ? AppTheme.accentLight : Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(mood.isNotEmpty ? mood : '',
          style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildRecentMood(String mood, String date) {
    final shortDate = date.length >= 10
        ? '${date.substring(5, 7)}/${date.substring(8, 10)}'
        : date;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(mood, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(shortDate,
              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
