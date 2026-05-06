import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../providers/message_provider.dart';
import '../../services/message_service.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state.dart';
import 'chat_screen.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final contacts = await MessageService().fetchContacts();
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _startChat(Map<String, dynamic> user) async {
    try {
      final conversation = await MessageService().createConversation(user['id']);

      if (!mounted) return;

      await ref.read(messageProvider.notifier).fetchConversations();
      await ref.read(messageProvider.notifier).fetchUnreadCount();

      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversation.id,
          userName: user['nickname'] ?? user['username'] ?? '用户',
        ),
      ));

      if (mounted) {
        await ref.read(messageProvider.notifier).fetchConversations();
        await ref.read(messageProvider.notifier).fetchUnreadCount();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('已认识'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: _loading
          ? const LoadingIndicator(message: '加载中...')
          : _contacts.isEmpty
              ? const EmptyState(
                  icon: Icons.people_outline,
                  title: '还没有已认识的人',
                  subtitle: '和感兴趣的人打招呼吧')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _contacts.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 68),
                    itemBuilder: (context, index) {
                      final c = _contacts[index];
                      final avatar = c['avatar'] ?? '🐰';
                      final name = c['nickname'] ?? c['username'] ?? '用户';
                      final bio = c['bio'] ?? '';

                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        leading: UserAvatar(avatar: avatar, size: 44),
                        title: Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary)),
                        subtitle: bio.isNotEmpty
                            ? Text(bio,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.textSecondary))
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.chat_bubble_outline,
                              color: AppTheme.textSecondary, size: 20),
                          onPressed: () => _startChat(c),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
