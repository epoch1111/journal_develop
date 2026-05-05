import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../services/message_service.dart';

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

  MessageNotifier() : super(const MessageState());

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
      await _service.markRead(conversationId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> sendMessage(int conversationId, String content) async {
    try {
      final msg = await _service.sendMessage(conversationId, content);
      state = state.copyWith(messages: [...state.messages, msg]);
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
}

final messageProvider = StateNotifierProvider<MessageNotifier, MessageState>((ref) {
  return MessageNotifier();
});
