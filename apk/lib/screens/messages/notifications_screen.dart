import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('通知'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationProvider.notifier).markAllRead(),
              child: const Text('全部已读',
                  style: TextStyle(fontSize: 13, color: AppTheme.accent)),
            ),
        ],
      ),
      body: state.isLoading
          ? const LoadingIndicator()
          : state.notifications.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_none,
                  title: '暂无通知',
                  subtitle: '当有人关注你或回复你时会收到通知')
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: state.notifications.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 60, color: Color(0xFFF3F4F6)),
                  itemBuilder: (context, index) {
                    final n = state.notifications[index];
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: n.isRead == 0 ? AppTheme.accentLight : AppTheme.bg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _iconForType(n.type),
                          size: 18,
                          color: n.isRead == 0 ? AppTheme.accent : AppTheme.textSecondary,
                        ),
                      ),
                      title: Text(n.message,
                          style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                              fontWeight: n.isRead == 0
                                  ? FontWeight.w600
                                  : FontWeight.normal)),
                      subtitle: Text(_formatTime(n.createdAt),
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      trailing: n.isRead == 0
                          ? Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                  color: AppTheme.accent,
                                  shape: BoxShape.circle),
                            )
                          : null,
                      onTap: () {
                        if (n.isRead == 0) {
                          ref
                              .read(notificationProvider.notifier)
                              .markRead(n.id);
                        }
                      },
                      onLongPress: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('删除通知'),
                            content: const Text('确定删除这条通知吗？'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('取消')),
                              TextButton(
                                  onPressed: () {
                                    ref
                                        .read(notificationProvider.notifier)
                                        .deleteNotification(n.id);
                                    Navigator.pop(context);
                                  },
                                  child: const Text('删除',
                                      style: TextStyle(color: AppTheme.danger))),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'follow':
        return Icons.person_add;
      case 'comment':
        return Icons.chat_bubble_outline;
      case 'like':
        return Icons.favorite_border;
      case 'hug':
        return Icons.volunteer_activism;
      case 'greet':
        return Icons.waving_hand;
      case 'message':
        return Icons.mail_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatTime(String time) {
    if (time.length >= 16) return time.substring(5, 16);
    return time;
  }
}
