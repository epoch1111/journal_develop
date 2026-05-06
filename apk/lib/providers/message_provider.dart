import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../services/message_service.dart';
import '../services/websocket_service.dart';
import '../services/local_notification_service.dart';

class MessageState {
  final List<Conversation> conversations;
  final List<ChatMessage> messages;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  const MessageState({
    this.conversations = const [],
    this.messages = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  MessageState copyWith({
    List<Conversation>? conversations,
    List<ChatMessage>? messages,
    int? unreadCount,
    bool? isLoading,
    String? error,
  }) {
    return MessageState(
      conversations: conversations ?? this.conversations,
      messages: messages ?? this.messages,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MessageNotifier extends StateNotifier<MessageState> {
  final MessageService _service = MessageService();
  final WebSocketService _ws = WebSocketService();
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  int? _activeConversationId;

  MessageNotifier() : super(const MessageState());

  Future<void> connectRealtime() async {
    await _ws.connect();

    await _wsSub?.cancel();
    _wsSub = _ws.messages.listen((event) async {
      final type = event['type'];

      if (type == 'new_message') {
        await _handleNewMessage(event);
      } else if (type == 'message_sent') {
        await _handleMessageSent(event);
      } else if (type == 'message_unread_count_update') {
        final count = event['unread_count'] ?? event['count'];
        if (count is int) {
          state = state.copyWith(unreadCount: count);
        }
      }
    });
  }

  void openConversation(int conversationId) {
    _activeConversationId = conversationId;
  }

  void closeConversation() {
    _activeConversationId = null;
  }

  Future<void> _handleNewMessage(Map<String, dynamic> event) async {
    final raw = event['message'];
    if (raw is! Map) {
      await fetchConversations();
      await fetchUnreadCount();
      return;
    }

    final msg = ChatMessage.fromJson(Map<String, dynamic>.from(raw));
    final convId = msg.conversationId;

    if (_activeConversationId == convId) {
      final exists = state.messages.any((m) => m.id == msg.id);
      if (!exists) {
        state = state.copyWith(
          messages: [...state.messages, msg],
        );
      }

      await markRead(convId);
      await fetchUnreadCount();
      await fetchConversations();
    } else {
      // Show notification for new message
      // Find sender name from conversation list
      String senderName = '用户';
      try {
        final conversations = state.conversations;
        final conv = conversations.where((c) => c.id == convId).firstOrNull;
        if (conv != null && conv.otherUserName != null) {
          senderName = conv.otherUserName!;
        }
      } catch (_) {}
      final notif = LocalNotificationService();
      await notif.showMessageNotification(
        conversationId: convId,
        senderName: senderName,
        content: msg.content,
      );
      await fetchConversations();
      await fetchUnreadCount();
    }
  }

  Future<void> _handleMessageSent(Map<String, dynamic> event) async {
    await fetchConversations();
    await fetchUnreadCount();
  }

  Future<void> fetchConversations() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final conversations = await _service.fetchConversations();
      state = state.copyWith(conversations: conversations, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchMessages(int conversationId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final messages = await _service.fetchMessages(conversationId);
      state = state.copyWith(messages: messages, isLoading: false);
      await markRead(conversationId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> sendMessage(int conversationId, String content) async {
    try {
      final msg = await _service.sendMessage(conversationId, content);
      final exists = state.messages.any((m) => m.id == msg.id);
      if (!exists) {
        state = state.copyWith(messages: [...state.messages, msg]);
      }
      await fetchConversations();
      await fetchUnreadCount();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      final count = await _service.fetchUnreadCount();
      state = state.copyWith(unreadCount: count);
    } catch (_) {}
  }

  Future<void> markRead(int conversationId) async {
    try {
      await _service.markRead(conversationId);
      await fetchUnreadCount();
      await fetchConversations();
    } catch (_) {}
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _ws.disconnect();
    super.dispose();
  }
}

final messageProvider = StateNotifierProvider<MessageNotifier, MessageState>((ref) {
  return MessageNotifier();
});
