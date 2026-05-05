import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'timeline/timeline_screen.dart';
import 'discover/discover_screen.dart';
import 'treehole/treehole_screen.dart';
import 'messages/messages_screen.dart';
import 'profile/profile_screen.dart';
import '../theme.dart';

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
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.edit_note, size: 24), label: '日记'),
          BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined, size: 24), label: '发现'),
          BottomNavigationBarItem(
              icon: Icon(Icons.email_outlined, size: 24), label: '消息'),
          BottomNavigationBarItem(
              icon: Icon(Icons.nature_outlined, size: 24), label: '树洞'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline, size: 24), label: '我的'),
        ],
      ),
    );
  }
}
