import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../providers/diary_provider.dart';
import '../../widgets/loading_indicator.dart';
import 'date_diaries_screen.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  int _calYear = DateTime.now().year;
  int _calMonth = DateTime.now().month - 1; // 0-indexed

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
                  // Monthly calendar
                  if (stats != null && stats['calendar_data'] != null) ...[
                    const SizedBox(height: 24),
                    _buildMonthlyCalendar(stats['calendar_data']),
                  ],
                  // Recent mood overview
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

  Widget _buildMonthlyCalendar(dynamic calendarData) {
    // calendar_data is Map<String, String>: {"2026-05-05": "😊", ...}
    final Map<String, String> calMap;
    if (calendarData is Map) {
      calMap = calendarData.map((k, v) => MapEntry(k.toString(), v.toString()));
    } else if (calendarData is List) {
      calMap = {};
      for (final item in calendarData) {
        final key = item['date']?.toString() ?? '';
        final val = item['mood']?.toString() ?? '';
        if (key.isNotEmpty) calMap[key] = val;
      }
    } else {
      calMap = {};
    }

    final monthLabel = '${_calYear}年${_calMonth + 1}月';
    final daysInMonth = DateTime(_calYear, _calMonth + 2, 0).day;
    // Monday = 0, Sunday = 6 for first day of month
    final firstDow = (DateTime(_calYear, _calMonth + 1, 1).weekday + 6) % 7;

    const weekDays = ['一', '二', '三', '四', '五', '六', '日'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Column(
        children: [
          // Month header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _calMonth--;
                  if (_calMonth < 0) { _calMonth = 11; _calYear--; }
                }),
                child: const Icon(Icons.chevron_left, color: AppTheme.textSecondary),
              ),
              Text(monthLabel,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              GestureDetector(
                onTap: () => setState(() {
                  _calMonth++;
                  if (_calMonth > 11) { _calMonth = 0; _calYear++; }
                }),
                child: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Weekday header
          Row(
            children: weekDays.map((d) {
              return SizedBox(
                width: (MediaQuery.of(context).size.width - 72) / 7,
                child: Center(
                  child: Text(d,
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textSecondary)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          // Day grid
          Wrap(
            children: [
              // Leading blanks
              for (var i = 0; i < firstDow; i++)
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 72) / 7,
                  height: 36,
                ),
              // Days
              for (var day = 1; day <= daysInMonth; day++)
                _buildDayCell(day, daysInMonth, calMap),
            ],
          ),
          const SizedBox(height: 4),
          const Text('点击有心情的日期查看当天日记',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildDayCell(int day, int daysInMonth, Map<String, String> calMap) {
    final cellWidth = (MediaQuery.of(context).size.width - 72) / 7;
    final dateKey =
        '${_calYear}-${(_calMonth + 1).toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final mood = calMap[dateKey];

    if (mood != null) {
      return GestureDetector(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DateDiariesScreen(date: dateKey, mood: mood),
          ));
        },
        child: Container(
          width: cellWidth,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.accentLight,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(mood, style: const TextStyle(fontSize: 16)),
        ),
      );
    }

    return SizedBox(
      width: cellWidth,
      height: 36,
      child: Center(
        child: Text('$day',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
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
