import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../models/user.dart';
import '../../services/safety_service.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state.dart';

class SafetyScreen extends ConsumerStatefulWidget {
  const SafetyScreen({super.key});

  @override
  ConsumerState<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends ConsumerState<SafetyScreen> {
  List<User> _blocked = [];
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final blocked = await SafetyService().fetchBlockedUsers();
      final reports = await SafetyService().fetchMyReports();
      if (mounted) {
        setState(() {
          _blocked = blocked;
          _reports = reports;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblock(int userId) async {
    await SafetyService().unblockUser(userId);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已解除拉黑')));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('安全中心'),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: AppTheme.textPrimary,
          bottom: TabBar(
            labelColor: AppTheme.accent,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.accent,
            tabs: [
              Tab(text: '拉黑列表 (${_blocked.length})'),
              Tab(text: '举报记录 (${_reports.length})'),
            ],
          ),
        ),
        body: _loading
            ? const LoadingIndicator()
            : TabBarView(
                children: [_buildBlockedList(), _buildReportsList()],
              ),
      ),
    );
  }

  Widget _buildBlockedList() {
    if (_blocked.isEmpty) {
      return const EmptyState(
          icon: Icons.block_outlined, title: '没有拉黑的用户');
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _blocked.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
      itemBuilder: (context, index) {
        final u = _blocked[index];
        return ListTile(
          leading: UserAvatar(avatar: u.avatar, size: 40),
          title: Text(u.nickname,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          trailing: TextButton(
            onPressed: () => _unblock(u.id),
            child: const Text('解除拉黑',
                style: TextStyle(fontSize: 12, color: AppTheme.danger)),
          ),
        );
      },
    );
  }

  Widget _buildReportsList() {
    if (_reports.isEmpty) {
      return const EmptyState(
          icon: Icons.flag_outlined, title: '没有提交过举报');
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _reports.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 16, color: Color(0xFFF3F4F6)),
      itemBuilder: (context, index) {
        final r = _reports[index];
        return ListTile(
          leading: Icon(_iconForType(r['report_type'] ?? ''),
              color: AppTheme.textSecondary),
          title: Text(r['reason'] ?? '',
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.textPrimary)),
          subtitle: Text('举报类型: ${r['report_type']}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        );
      },
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'user':
        return Icons.person_off;
      case 'diary':
        return Icons.book;
      case 'comment':
        return Icons.chat_bubble;
      case 'treehole':
        return Icons.nature;
      default:
        return Icons.flag;
    }
  }
}
