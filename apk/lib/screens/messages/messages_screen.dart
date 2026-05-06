import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../providers/message_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state.dart';
import 'chat_screen.dart';
import 'contacts_screen.dart';
import 'notifications_screen.dart';
import 'greet_screen.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messageProvider.notifier).connectRealtime();
      ref.read(messageProvider.notifier).fetchConversations();
      ref.read(messageProvider.notifier).fetchUnreadCount();
      ref.read(notificationProvider.notifier).fetchUnreadCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final msgState = ref.watch(messageProvider);
    final notifState = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
              ),
              child: const Text('消息中心', style: AppTheme.headingLarge),
            ),
            // Entry cards
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Private messages
                  _buildEntryCard(
                    icon: Icons.mail_outline,
                    title: '私信',
                    badge: msgState.unreadCount,
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ConversationsListScreen(),
                      ));
                    },
                  ),
                  const SizedBox(height: 10),
                  // Contacts
                  _buildEntryCard(
                    icon: Icons.people_outline,
                    title: '已认识',
                    badge: null,
                    accentColor: AppTheme.accent,
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ContactsScreen(),
                      ));
                    },
                  ),
                  const SizedBox(height: 10),
                  // Greet requests
                  _buildEntryCard(
                    icon: Icons.waving_hand_outlined,
                    title: '打招呼',
                    badge: null,
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const GreetScreen(),
                      ));
                    },
                  ),
                  const SizedBox(height: 10),
                  // Notifications
                  _buildEntryCard(
                    icon: Icons.notifications_outlined,
                    title: '通知',
                    badge: notifState.unreadCount,
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard({
    required IconData icon,
    required String title,
    int? badge,
    Color? accentColor,
    required VoidCallback onTap,
  }) {
    final iconColor = accentColor ?? AppTheme.textSecondary;
    final bgColor = accentColor != null ? AppTheme.accentLight : AppTheme.bg;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary)),
            ),
            if (badge != null && badge > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.danger,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$badge',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// Conversations list (sub-screen)
class ConversationsListScreen extends ConsumerStatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  ConsumerState<ConversationsListScreen> createState() =>
      _ConversationsListScreenState();
}

class _ConversationsListScreenState
    extends ConsumerState<ConversationsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messageProvider.notifier).fetchConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messageProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('私信'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: state.isLoading
          ? const LoadingIndicator()
          : state.conversations.isEmpty
              ? const EmptyState(
                  icon: Icons.mail_outline, title: '暂无会话',
                  subtitle: '和好友打个招呼开始聊天吧')
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: state.conversations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final c = state.conversations[index];
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      leading: UserAvatar(
                          avatar: c.otherUserAvatar ?? '🐰', size: 44),
                      title: Text(c.otherUserName ?? '用户',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                      subtitle: Text(c.lastMessage ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textSecondary)),
                      trailing: (c.unreadCount != null && c.unreadCount! > 0)
                          ? Container(
                              width: 20, height: 20,
                              decoration: const BoxDecoration(
                                  color: AppTheme.danger,
                                  shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Text('${c.unreadCount}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 10)),
                            )
                          : null,
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              ChatScreen(conversationId: c.id,
                                  userName: c.otherUserName ?? '用户',
                                  userAvatar: c.otherUserAvatar ?? '🐰'),
                        ));
                        if (mounted) {
                          ref.read(messageProvider.notifier).fetchConversations();
                          ref.read(messageProvider.notifier).fetchUnreadCount();
                        }
                      },
                    );
                  },
                ),
    );
  }
}
