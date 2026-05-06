import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models/diary.dart';
import '../../services/diary_service.dart';
import '../../widgets/diary_card.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state.dart';
import '../discover/diary_detail_screen.dart';

class DateDiariesScreen extends StatefulWidget {
  final String date;
  final String mood;

  const DateDiariesScreen({super.key, required this.date, required this.mood});

  @override
  State<DateDiariesScreen> createState() => _DateDiariesScreenState();
}

class _DateDiariesScreenState extends State<DateDiariesScreen> {
  List<Diary> _diaries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final diaries = await DiaryService().fetchDiariesByDate(widget.date);
      if (mounted) {
        setState(() {
          _diaries = diaries;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text('${widget.mood} ${widget.date}'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: _loading
          ? const LoadingIndicator(message: '加载日记...')
          : _diaries.isEmpty
              ? const EmptyState(
                  icon: Icons.book_outlined,
                  title: '当天没有日记',
                  subtitle: '这一天还没有写过日记')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 20),
                    itemCount: _diaries.length,
                    itemBuilder: (context, index) {
                      final d = _diaries[index];
                      return DiaryCard(
                        diary: d,
                        isTimeline: true,
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => DiaryDetailScreen(
                                diaryId: d.id, isPublic: false),
                          ));
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
