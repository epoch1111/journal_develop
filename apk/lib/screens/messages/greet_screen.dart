import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../services/api_client.dart';
import '../../models/greet_request.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state.dart';

class GreetScreen extends ConsumerStatefulWidget {
  const GreetScreen({super.key});

  @override
  ConsumerState<GreetScreen> createState() => _GreetScreenState();
}

class _GreetScreenState extends ConsumerState<GreetScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<GreetRequest> _received = [];
  List<GreetRequest> _sent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final receivedData =
          await ApiClient().get('/api/greet/requests/received');
      final sentData = await ApiClient().get('/api/greet/requests/sent');
      if (mounted) {
        setState(() {
          _received = (receivedData['data'] as List? ?? [])
              .map((r) => GreetRequest.fromJson(r))
              .toList();
          _sent = (sentData['data'] as List? ?? [])
              .map((r) => GreetRequest.fromJson(r))
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept(int id) async {
    await ApiClient().post('/api/greet/requests/$id/accept');
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已同意')));
    _load();
  }

  Future<void> _reject(int id) async {
    await ApiClient().post('/api/greet/requests/$id/reject');
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已拒绝')));
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('打招呼'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.accent,
          tabs: [
            Tab(text: '收到的 (${_received.length})'),
            Tab(text: '发出的 (${_sent.length})'),
          ],
        ),
      ),
      body: _loading
          ? const LoadingIndicator()
          : TabBarView(
              controller: _tabCtrl,
              children: [_buildList(_received, true), _buildList(_sent, false)],
            ),
    );
  }

  Widget _buildList(List<GreetRequest> list, bool isReceived) {
    if (list.isEmpty) {
      return const EmptyState(
          icon: Icons.waving_hand_outlined, title: '暂无数据');
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 68),
      itemBuilder: (context, index) {
        final r = list[index];
        final userName = isReceived
            ? (r.fromUserName ?? '用户')
            : (r.toUserName ?? '用户');
        final userAvatar = isReceived
            ? (r.fromUserAvatar ?? '🐰')
            : (r.toUserAvatar ?? '🐰');

        return ListTile(
          leading: UserAvatar(avatar: userAvatar, size: 40),
          title: Text(userName,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          subtitle: Text(_statusLabel(r.status),
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          trailing: isReceived && r.status == 'pending'
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                        onPressed: () => _accept(r.id),
                        child: const Text('同意',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.accent))),
                    TextButton(
                        onPressed: () => _reject(r.id),
                        child: const Text('拒绝',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.danger))),
                  ],
                )
              : null,
        );
      },
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return '等待回应';
      case 'accepted':
        return '已接受';
      case 'rejected':
        return '已拒绝';
      case 'cancelled':
        return '已取消';
      default:
        return s;
    }
  }
}
