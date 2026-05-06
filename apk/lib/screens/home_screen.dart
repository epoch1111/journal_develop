import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'timeline/timeline_screen.dart';
import 'discover/discover_screen.dart';
import 'treehole/treehole_screen.dart';
import 'messages/messages_screen.dart';
import 'profile/profile_screen.dart';
import '../theme.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import '../providers/message_provider.dart';
import '../providers/notification_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final _screens = const [
    TimelineScreen(),
    DiscoverScreen(),
    MessagesScreen(),
    TreeholeScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _autoCheckUpdate();
  }

  Future<void> _autoCheckUpdate() async {
    final svc = UpdateService();
    if (!await svc.shouldAutoCheck()) return;
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    final info = await svc.checkForUpdate();
    if (info.hasUpdate && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => UpdateDialog(info: info),
      );
    }
  }

  int get _totalUnread {
    final msgState = ref.watch(messageProvider);
    final notifState = ref.watch(notificationProvider);
    return (msgState.unreadCount ?? 0) + (notifState.unreadCount ?? 0);
  }

  Widget _buildBadgeIcon(IconData icon, int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: 24),
        if (count > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 99 ? '99+' : '',
                style: const TextStyle(color: Colors.white, fontSize: 9),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.accent,
        unselectedItemColor: AppTheme.textSecondary,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 0,
        items: [
          const BottomNavigationBarItem(
              icon: Icon(Icons.edit_note, size: 24), label: '日记'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined, size: 24), label: '发现'),
          BottomNavigationBarItem(
              icon: _buildBadgeIcon(Icons.email_outlined, _totalUnread),
              label: '消息'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.nature_outlined, size: 24), label: '树洞'),
          const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline, size: 24), label: '我的'),
        ],
      ),
    );
  }
}
