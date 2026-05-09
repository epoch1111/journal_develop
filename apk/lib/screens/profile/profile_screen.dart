import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import '../../api/client.dart';
import '../../services/profile_service.dart';
import '../../services/safety_service.dart';
import '../../services/greet_service.dart';
import '../../services/message_service.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/loading_indicator.dart';
import 'edit_profile_screen.dart';
import 'stats_screen.dart';
import 'capsules_screen.dart';
import 'follow_list_screen.dart';
import 'safety_screen.dart';
import '../../services/update_service.dart';
import '../../widgets/update_dialog.dart';
import '../messages/greet_screen.dart';
import '../discover/diary_detail_screen.dart';

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
  String _greetStatus = 'none'; // none|pending|accepted|self
  String _greetDirection = 'none'; // sent|received|none

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
          _loadGreetStatus(user.id);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadGreetStatus(int userId) async {
    try {
      final data = await GreetService().fetchGreetStatus(userId);
      if (mounted) {
        setState(() {
          _greetStatus = data['status'] ?? 'none';
          _greetDirection = data['direction'] ?? 'none';
        });
      }
    } catch (_) {}
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

  Future<void> _showGreetDialog() async {
    if (_user == null) return;
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('向 ${_user!.nickname} 打个招呼'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '写点什么让 TA 认识你...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('发送'),
          ),
        ],
      ),
    );
    if (result == true && controller.text.trim().isNotEmpty) {
      try {
        await GreetService().createGreetRequest(
          receiverId: _user!.id,
          message: controller.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('招呼已经送到 ✨')),
          );
          _loadGreetStatus(_user!.id);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('发送失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _blockUser() async {
    if (_user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('拉黑用户'),
        content: const Text('确定要拉黑 TA 吗？拉黑后 TA 将无法关注、打招呼或给你发消息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定拉黑'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await SafetyService().blockUser(_user!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已拉黑该用户')),
          );
          _load();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('操作失败: $e')),
          );
        }
      }
    }
  }

  void _reportUser() {
    if (_user == null) return;
    final reasons = ['骚扰', '垃圾信息', '色情内容', '暴力内容', '侵犯隐私', '诈骗', '其他'];
    String? selectedReason;
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInnerState) => AlertDialog(
          title: const Text('举报用户'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('举报原因', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: reasons.map((r) => GestureDetector(
                    onTap: () => setInnerState(() => selectedReason = r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selectedReason == r ? AppTheme.dangerLight : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(r, style: TextStyle(fontSize: 13, color: selectedReason == r ? AppTheme.danger : AppTheme.textSecondary)),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                const Text('补充说明（必填）', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: '请描述具体情况...', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: selectedReason != null && descCtrl.text.trim().isNotEmpty
                  ? () async {
                      Navigator.pop(ctx);
                      try {
                        await SafetyService().createReport(
                          reportType: 'user',
                          targetId: _user!.id,
                          reason: selectedReason!,
                          description: descCtrl.text.trim(),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('举报成功')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('举报失败: $e')),
                          );
                        }
                      }
                    }
                  : null,
              child: const Text('提交'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _unblockUser() async {
    if (_user == null) return;
    try {
      await SafetyService().unblockUser(_user!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已解除拉黑')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  Future<void> _openChat() async {
    if (_user == null) return;
    try {
      await MessageService().createConversation(_user!.id);
      if (mounted) {
        Navigator.of(context).pushNamed('/messages');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
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
                    // Follow stats + diary count (my profile)
                    if (_isMyProfile)
                      Row(
                        children: [
                          _statItem('日记', user.publicDiaryCount ?? 0, null),
                          const SizedBox(width: 24),
                          _statItem('关注', user.followingCount ?? 0,
                              () => _openFollowList('following')),
                          const SizedBox(width: 24),
                          _statItem('粉丝', user.followerCount ?? 0,
                              () => _openFollowList('followers')),
                        ],
                      )
                    else
                      Row(
                        children: [
                          _statItem('粉丝', user.followerCount ?? 0, null),
                          const SizedBox(width: 24),
                          _statItem('关注', user.followingCount ?? 0, null),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Author profile: blocked state
              if (!_isMyProfile && user.blocked == true)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: [AppTheme.cardShadow],
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.block, size: 40, color: AppTheme.textMuted),
                      const SizedBox(height: 12),
                      Text(user.message ?? '由于安全设置，暂时无法查看该用户主页',
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textSecondary),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _unblockUser,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('解除拉黑',
                                  style: TextStyle(
                                      fontSize: 13, color: AppTheme.textSecondary)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _reportUser,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('举报 TA',
                                  style: TextStyle(
                                      fontSize: 13, color: AppTheme.danger)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // Author profile: greet button + score + block/report
              if (!_isMyProfile && user.blocked != true) ...[
                // Greet button
                _buildActionBtn(
                  _getGreetBtnText(),
                  _getGreetBtnColor(),
                  _getGreetBtnBgColor(),
                  _greetStatus == 'self' ? null : _handleGreetTap,
                ),
                // 发消息 button (after greet accepted)
                if (_greetStatus == 'accepted') ...[
                  const SizedBox(height: 8),
                  _buildActionBtn(
                    '发消息',
                    const Color(0xFF4F46E5),
                    const Color(0xFFEEF2FF),
                    _openChat,
                  ),
                ],
                const SizedBox(height: 10),
                // Same-frequency score
                if (user.sameFrequencyScore != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFECFDF5), Color(0xFFFFFBEB)],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${user.sameFrequencyScore}%',
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF059669)),
                        ),
                        Text(
                            '你们有 ${user.sameFrequencyScore}% 的同频感',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                // Block + Report
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _blockUser,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            child: const Center(
                              child: Text('拉黑 TA',
                                  style: TextStyle(
                                      fontSize: 12, color: AppTheme.textMuted)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: _reportUser,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            child: const Center(
                              child: Text('举报 TA',
                                  style: TextStyle(
                                      fontSize: 12, color: AppTheme.textMuted)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Mood keywords (both my and author profile)
              if ((user.moodKeywords.isNotEmpty) &&
                  user.blocked != true) ...[
                const SizedBox(height: 10),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: [AppTheme.cardShadow],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🧠 情绪关键词',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textMuted)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: user.moodKeywords
                            .map((k) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(k,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFFD97706))),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],

              // Recent public diaries
              if (user.recentPublicDiaries.isNotEmpty &&
                  user.blocked != true) ...[
                const SizedBox(height: 10),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: [AppTheme.cardShadow],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isMyProfile
                            ? '📖 最近公开日记'
                            : '📖 TA 最近的公开日记（${user.publicDiaryCount ?? user.recentPublicDiaries.length}篇）',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 10),
                      ...user.recentPublicDiaries.map((d) => _buildRecentDiary(d)),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // My profile menu items
              if (_isMyProfile && user.blocked != true) ...[
                _buildMenuItem(Icons.mail_outline, '打招呼中心', () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const GreetScreen(),
                  ));
                }),
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

  Widget _buildActionBtn(String text, Color textColor, Color bgColor, VoidCallback? onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: [AppTheme.cardShadowSm],
          ),
          child: Center(
            child: Text(text,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor)),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentDiary(Map<String, dynamic> d) {
    return GestureDetector(
      onTap: () {
        final id = d['id'] as int?;
        if (id != null) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DiaryDetailScreen(diaryId: id, isPublic: true),
          ));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(d['mood'] ?? '📝', style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  _formatDate(d['created_at'] ?? ''),
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              d['content'] ?? '',
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (d['tags'] != null && (d['tags'] as String).isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: (d['tags'] as String).split(',').where((t) => t.trim().isNotEmpty).map((t) => Text(
                  '#${t.trim()}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String date) {
    if (date.length >= 16) return date.substring(5, 16);
    if (date.length >= 10) return date.substring(5, 10);
    return date;
  }

  String _getGreetBtnText() {
    if (_greetStatus == 'self') return '';
    if (_greetStatus == 'none') return '打个招呼';
    if (_greetStatus == 'pending' && _greetDirection == 'sent') return '等待回应';
    if (_greetStatus == 'pending' && _greetDirection == 'received') return '回应 TA';
    if (_greetStatus == 'accepted') return '已认识';
    return '重新打招呼';
  }

  Color _getGreetBtnColor() {
    if (_greetStatus == 'self') return Colors.transparent;
    if (_greetStatus == 'none') return const Color(0xFF9333EA);
    if (_greetStatus == 'pending' && _greetDirection == 'sent') return const Color(0xFFD97706);
    if (_greetStatus == 'pending' && _greetDirection == 'received') return const Color(0xFF059669);
    if (_greetStatus == 'accepted') return const Color(0xFF047857);
    return const Color(0xFF9333EA);
  }

  Color _getGreetBtnBgColor() {
    if (_greetStatus == 'self') return Colors.transparent;
    if (_greetStatus == 'none') return const Color(0xFFF3E8FF);
    if (_greetStatus == 'pending' && _greetDirection == 'sent') return const Color(0xFFFEF3C7);
    if (_greetStatus == 'pending' && _greetDirection == 'received') return const Color(0xFFD1FAE5);
    if (_greetStatus == 'accepted') return const Color(0xFFECFDF5);
    return const Color(0xFFF3E8FF);
  }

  void _handleGreetTap() {
    if (_greetStatus == 'pending' && _greetDirection == 'sent') {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const GreetScreen(),
      ));
    } else if (_greetStatus == 'pending' && _greetDirection == 'received') {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const GreetScreen(),
      ));
    } else if (_greetStatus == 'accepted') {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const GreetScreen(),
      ));
    } else {
      _showGreetDialog();
    }
  }

  Widget _statItem(String label, int count, VoidCallback? onTap) {
    final child = Row(
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
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: child);
    }
    return child;
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
