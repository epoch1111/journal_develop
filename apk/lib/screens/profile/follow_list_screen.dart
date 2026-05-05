import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../models/user.dart';
import '../../services/follow_service.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state.dart';
import 'profile_screen.dart';

class FollowListScreen extends ConsumerStatefulWidget {
  final String type;
  const FollowListScreen({super.key, required this.type});

  @override
  ConsumerState<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends ConsumerState<FollowListScreen> {
  List<User> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = widget.type == 'following'
          ? await FollowService().fetchFollowing()
          : await FollowService().fetchFollowers();
      if (mounted) {
        setState(() {
          _users = users;
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.type == 'following' ? '我的关注' : '我的粉丝'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: _loading
          ? const LoadingIndicator()
          : _users.isEmpty
              ? EmptyState(
                  icon: Icons.people_outline,
                  title: widget.type == 'following' ? '还没有关注' : '还没有粉丝')
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
                  itemBuilder: (context, index) {
                    final u = _users[index];
                    return ListTile(
                      leading: UserAvatar(avatar: u.avatar, size: 42),
                      title: Text(u.nickname,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary)),
                      subtitle: Text(u.bio,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                ProfileScreen.external(userId: u.id)));
                      },
                    );
                  },
                ),
    );
  }
}
