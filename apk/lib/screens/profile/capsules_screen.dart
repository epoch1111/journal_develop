import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../models/diary.dart';
import '../../services/diary_service.dart';
import '../../widgets/diary_card.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state.dart';
import '../timeline/write_diary_screen.dart';

class CapsulesScreen extends ConsumerStatefulWidget {
  const CapsulesScreen({super.key});

  @override
  ConsumerState<CapsulesScreen> createState() => _CapsulesScreenState();
}

class _CapsulesScreenState extends ConsumerState<CapsulesScreen> {
  List<Diary> _capsules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final diaries = await DiaryService().fetchDiaries();
      if (mounted) {
        setState(() {
          _capsules =
              diaries.where((d) => d.isCapsule).toList();
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
        title: const Text('时光胶囊'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(
                      builder: (_) =>
                          const WriteDiaryScreen(isCapsule: true)))
                  .then((_) => _load());
            },
          ),
        ],
      ),
      body: _loading
          ? const LoadingIndicator()
          : _capsules.isEmpty
              ? const EmptyState(
                  icon: Icons.hourglass_empty,
                  title: '还没有时光胶囊',
                  subtitle: '点击右上角 + 创建一个胶囊')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 20),
                    itemCount: _capsules.length,
                    itemBuilder: (context, index) {
                      return DiaryCard(
                        diary: _capsules[index],
                        isTimeline: true,
                      );
                    },
                  ),
                ),
    );
  }
}
