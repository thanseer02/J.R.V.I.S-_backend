import 'dart:math';

import '../models/chat_message.dart';
import '../models/conversation.dart';
import 'conversation_repository.dart';

/// Service responsible for managing conversation lifecycle, generating unique IDs,
/// maintaining message ordering, and producing titles from user input.
class ConversationHistoryService {
  final ConversationRepository _repository;
  final Random _random;

  ConversationHistoryService({
    ConversationRepository? repository,
    Random? random,
  })  : _repository = repository ?? InMemoryConversationRepository(),
        _random = random ?? Random.secure();

  /// Generates a cryptographically random, collision-resistant unique identifier.
  String generateId([String prefix = 'conv']) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomHex = List.generate(4, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    return '${prefix}_${timestamp}_$randomHex';
  }

  /// Creates a new conversation with an optional custom [title] or [conversationId].
  Future<Conversation> startConversation({
    String? conversationId,
    String? title,
  }) async {
    final id = conversationId?.trim().isNotEmpty == true
        ? conversationId!.trim()
        : generateId('conv');
    final convTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : 'New Conversation';

    final conversation = Conversation(
      conversationId: id,
      title: convTitle,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      messages: const [],
    );

    return _repository.createConversation(conversation);
  }

  /// Retrieves an existing conversation, or returns null if not found.
  Future<Conversation?> getConversation(String conversationId) {
    return _repository.getConversation(conversationId.trim());
  }

  /// Lists all conversations sorted by last update time descending.
  Future<List<Conversation>> listConversations() {
    return _repository.listConversations();
  }

  /// Appends a user message to [conversationId].
  ///
  /// Automatically generates a conversation title from the first user message if the
  /// current title is the default 'New Conversation'.
  Future<ChatMessage> addUserMessage(
    String conversationId,
    String content,
  ) async {
    final msg = ChatMessage(
      messageId: generateId('msg'),
      role: ChatRole.user,
      content: content.trim(),
      timestamp: DateTime.now(),
    );

    final existing = await _repository.getConversation(conversationId);
    if (existing == null) {
      throw ArgumentError('Conversation with ID "$conversationId" does not exist.');
    }

    // Auto-update title if it's the first message and still default
    if (existing.messages.isEmpty &&
        (existing.title == 'New Conversation' || existing.title.isEmpty)) {
      final summary = generateTitle(content);
      await _repository.createConversation(existing.copyWith(title: summary));
    }

    await _repository.appendMessage(conversationId, msg);
    return msg;
  }

  /// Appends an assistant response to [conversationId].
  Future<ChatMessage> addAssistantMessage(
    String conversationId,
    String content,
  ) async {
    final msg = ChatMessage(
      messageId: generateId('msg'),
      role: ChatRole.assistant,
      content: content.trim(),
      timestamp: DateTime.now(),
    );

    final updated = await _repository.appendMessage(conversationId, msg);
    if (updated == null) {
      throw ArgumentError('Conversation with ID "$conversationId" does not exist.');
    }
    return msg;
  }

  /// Clears the history of [conversationId].
  Future<Conversation?> clearHistory(String conversationId) {
    return _repository.clearHistory(conversationId.trim());
  }

  /// Deletes the conversation with [conversationId].
  Future<bool> deleteConversation(String conversationId) {
    return _repository.deleteConversation(conversationId.trim());
  }

  /// Generates a concise title from the user's initial message.
  static String generateTitle(String firstMessage) {
    final cleaned = firstMessage.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.length <= 40) return cleaned;
    return '${cleaned.substring(0, 37)}...';
  }
}
