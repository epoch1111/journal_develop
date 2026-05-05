import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';

class NotificationState {
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? error,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationService _service = NotificationService();

  NotificationNotifier() : super(const NotificationState());

  Future<void> fetchNotifications({bool unreadOnly = false}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final notifications =
          await _service.fetchNotifications(unreadOnly: unreadOnly);
      state = state.copyWith(notifications: notifications, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      final count = await _service.fetchUnreadCount();
      state = state.copyWith(unreadCount: count);
    } catch (_) {}
  }

  Future<void> markRead(int id) async {
    await _service.markRead(id);
    final newList = state.notifications.map((n) {
      if (n.id == id) {
        return AppNotification(
          id: n.id, type: n.type, message: n.message,
          relatedId: n.relatedId, isRead: 1, createdAt: n.createdAt,
        );
      }
      return n;
    }).toList();
    state = state.copyWith(notifications: newList,
        unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0);
  }

  Future<void> markAllRead() async {
    await _service.markAllRead();
    final newList = state.notifications.map((n) {
      return AppNotification(
        id: n.id, type: n.type, message: n.message,
        relatedId: n.relatedId, isRead: 1, createdAt: n.createdAt,
      );
    }).toList();
    state = state.copyWith(notifications: newList, unreadCount: 0);
  }

  Future<void> deleteNotification(int id) async {
    await _service.deleteNotification(id);
    final newList = state.notifications.where((n) => n.id != id).toList();
    state = state.copyWith(notifications: newList);
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier();
});
