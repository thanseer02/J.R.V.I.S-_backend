import '../models/chat_message.dart';
import '../models/conversation.dart';

/// Abstract contract for conversation persistence.
///
/// Designed to be backend-agnostic so in-memory storage can be swapped
/// with Firestore, SQLite, PostgreSQL, or Redis without altering domain logic.
abstract class ConversationRepository {
  /// Creates and saves a new [Conversation].
  Future<Conversation> createConversation(Conversation conversation);

  /// Retrieves a conversation by its [conversationId], or null if not found.
  Future<Conversation?> getConversation(String conversationId);

  /// Lists all conversations, sorted by [updatedAt] descending.
  Future<List<Conversation>> listConversations();

  /// Appends [message] to the conversation with [conversationId].
  ///
  /// Returns the updated [Conversation], or null if the conversation was not found.
  Future<Conversation?> appendMessage(
    String conversationId,
    ChatMessage message,
  );

  /// Clears all messages from the conversation with [conversationId].
  ///
  /// Returns the updated empty [Conversation], or null if not found.
  Future<Conversation?> clearHistory(String conversationId);

  /// Deletes the conversation with [conversationId].
  ///
  /// Returns true if a conversation was deleted, false if it did not exist.
  Future<bool> deleteConversation(String conversationId);
}

/// In-memory implementation of [ConversationRepository].
class InMemoryConversationRepository implements ConversationRepository {
  final Map<String, Conversation> _storage = <String, Conversation>{};

  @override
  Future<Conversation> createConversation(Conversation conversation) async {
    _storage[conversation.conversationId] = conversation;
    return conversation;
  }

  @override
  Future<Conversation?> getConversation(String conversationId) async {
    return _storage[conversationId];
  }

  @override
  Future<List<Conversation>> listConversations() async {
    final list = _storage.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<Conversation?> appendMessage(
    String conversationId,
    ChatMessage message,
  ) async {
    final current = _storage[conversationId];
    if (current == null) return null;

    final updatedMessages = List<ChatMessage>.from(current.messages)
      ..add(message);
    final updated = current.copyWith(
      messages: updatedMessages,
      updatedAt: message.timestamp,
    );
    _storage[conversationId] = updated;
    return updated;
  }

  @override
  Future<Conversation?> clearHistory(String conversationId) async {
    final current = _storage[conversationId];
    if (current == null) return null;

    final updated = current.copyWith(
      messages: <ChatMessage>[],
      updatedAt: DateTime.now(),
    );
    _storage[conversationId] = updated;
    return updated;
  }

  @override
  Future<bool> deleteConversation(String conversationId) async {
    return _storage.remove(conversationId) != null;
  }

  /// Clears entire in-memory store (useful for test isolation).
  void clearAll() {
    _storage.clear();
  }
}
