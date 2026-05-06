import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/profile_service.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/loading_indicator.dart';
import 'edit_profile_screen.dart';
import 'stats_screen.dart';
import 'capsules_screen.dart';
import 'follow_list_screen.dart';
import 'safety_screen.dart';
import '../../services/update_service.dart';
import '../../widgets/update_dialog.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final int? userId;
  const ProfileScreen({super.key, this.userId});

  static Widget external({required int userId}) => ProfileScreen(userId: userId);

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  User? _user;
  bool _loading = true;
  bool _isFollowing = false;

  bool get _isMyProfile => widget.userId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      if (_isMyProfile) {
        final user = await ProfileService().fetchMyProfile();
        if (mounted) {
          setState(() {
            _user = user;
            _isFollowing = false;
            _loading = false;
          });
        }
      } else {
        final user = await ProfileService().fetchUserProfile(widget.userId!);
        if (mounted) {
          setState(() {
            _user = user;
            _isFollowing = user.isFollowing == true;
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_user == null) return;
    try {
      if (_isFollowing) {
        await ApiClient().delete('/api/users/${_user!.id}/follow');
      } else {
        await ApiClient().post('/api/users/${_user!.id}/follow');
      }
      setState(() => _isFollowing = !_isFollowing);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    if (_loading) {
      return const Scaffold(
          body: Center(child: LoadingIndicator(message: '加载中...')));
    }

    final user = _isMyProfile ? (auth.user ?? _user) : _user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('加载失败')));
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Profile header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
                ),
                child: Column(
                  children: [
                    // Header row
                    Row(
                      children: [
                        Expanded(
                          child: Text(_isMyProfile ? '我的' : '主页',
                              style: AppTheme.headingLarge),
                        ),
                        if (_isMyProfile)
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, size: 22),
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const SafetyScreen(),
                              ));
                            },
                            color: AppTheme.textSecondary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Avatar + name
                    Row(
                      children: [
                        UserAvatar(avatar: user.avatar, size: 60),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.nickname,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary)),
                              const SizedBox(height: 4),
                              Text('@${user.username}',
                                  style: const TextStyle(
                                      fontSize: 13, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        if (!_isMyProfile)
                          GestureDetector(
                            onTap: _toggleFollow,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isFollowing
                                    ? Colors.grey[50]
                                    : AppTheme.accent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: _isFollowing
                                        ? const Color(0xFFD1D5DB)
                                        : AppTheme.accent),
                              ),
                              child: Text(
                                _isFollowing ? '已关注' : '关注',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _isFollowing
                                        ? AppTheme.textSecondary
                                        : Colors.white),
                              ),
                            ),
                          ),
                        if (_isMyProfile)
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context)
                                  .push(MaterialPageRoute(
                                    builder: (_) => const EditProfileScreen(),
                                  ))
                                  .then((_) => _load());
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: const Text('编辑资料',
                                  style: TextStyle(
                                      fontSize: 13, color: AppTheme.textSecondary)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Bio + interests
                    if (user.bio.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(user.bio,
                            style: const TextStyle(
                                fontSize: 13, color: AppTheme.textSecondary)),
                      ),
                    if (user.interests.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          children: user.interests
                              .split(',')
                              .where((t) => t.trim().isNotEmpty)
                              .map((t) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(t.trim(),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF60A5FA))),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    // Follow stats
                    Row(
                      children: [
                        _statItem('关注', user.followingCount ?? 0,
                            () => _openFollowList('following')),
                        const SizedBox(width: 24),
                        _statItem('粉丝', user.followerCount ?? 0,
                            () => _openFollowList('followers')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Menu items (my profile only)
              if (_isMyProfile) ...[
                _buildMenuItem(Icons.bar_chart, '统计看板', () {
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StatsScreen()));
                }),
                _buildMenuItem(Icons.hourglass_empty, '时光胶囊', () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const CapsulesScreen()));
                }),
                _buildMenuItem(Icons.security, '安全中心', () {
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SafetyScreen()));
                }),
                _buildMenuItem(Icons.dns_outlined, '服务器设置', () {
                  Navigator.of(context).pushNamed('/server-config');
                }),
                _buildMenuItem(Icons.system_update, '检查更新', () async {
                  final info = await UpdateService().checkForUpdate();
                  if (!mounted) return;
                  if (info.hasUpdate) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => UpdateDialog(info: info),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已是最新版本')),
                    );
                  }
                }),
              ],
              const SizedBox(height: 20),
              // Logout
              if (_isMyProfile)
                TextButton(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (mounted) {
                      Navigator.of(context)
                          .pushReplacementNamed('/login');
                    }
                  },
                  child: const Text('退出登录',
                      style: TextStyle(color: AppTheme.danger)),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(String label, int count, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count ',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          Text(label,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  void _openFollowList(String type) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FollowListScreen(type: type)));
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.textPrimary)),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
