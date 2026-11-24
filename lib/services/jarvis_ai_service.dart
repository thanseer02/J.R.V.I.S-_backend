import 'dart:async';

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

import '../config/ai_config.dart';
import '../config/jarvis_prompts.dart';
import '../flows/chat_flow.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import 'conversation_history_service.dart';

/// Exception thrown when the user provides an invalid message.
class InvalidMessageException implements Exception {
  final String message;
  const InvalidMessageException(this.message);

  @override
  String toString() => 'InvalidMessageException: $message';
}

/// Exception thrown when a requested conversation is not found or invalid.
class ConversationNotFoundException implements Exception {
  final String conversationId;
  const ConversationNotFoundException(this.conversationId);

  @override
  String toString() =>
      'ConversationNotFoundException: Conversation "$conversationId" not found.';
}

/// Exception thrown when AI generation fails.
class JarvisAiException implements Exception {
  final String message;
  final Object? cause;

  const JarvisAiException(this.message, [this.cause]);

  @override
  String toString() => 'JarvisAiException: $message';
}

/// Result returned from a multi-turn chat interaction.
class JarvisChatResponse {
  final String conversationId;
  final String reply;
  final ChatMessage userMessage;
  final ChatMessage assistantMessage;

  const JarvisChatResponse({
    required this.conversationId,
    required this.reply,
    required this.userMessage,
    required this.assistantMessage,
  });

  Map<String, dynamic> toJson() => {
    'conversationId': conversationId,
    'reply': reply,
    'userMessage': userMessage.toJson(),
    'assistantMessage': assistantMessage.toJson(),
  };
}

/// Abstract contract for AI generation, enabling dependency injection and testing.
abstract class AiGenerator {
  /// Generates a response given [prompt], [system] instruction, and prior [history].
  Future<String> generateText({
    required String prompt,
    String? system,
    List<ChatMessage> history = const [],
    ModelRef<GeminiOptions>? model,
  });
}

/// Implementation of [AiGenerator] that executes via the registered [JarvisChatFlow].
class FlowAiGenerator implements AiGenerator {
  final Genkit _genkit;
  late final Flow<JarvisChatInput, String, void, void> _flow;

  FlowAiGenerator([Genkit? genkit]) : _genkit = genkit ?? AiConfig.genkit {
    _flow = JarvisChatFlow.registeredFlow ?? JarvisChatFlow.define(_genkit);
  }

  @override
  Future<String> generateText({
    required String prompt,
    String? system,
    List<ChatMessage> history = const [],
    ModelRef<GeminiOptions>? model,
  }) async {
    final flowHistory = history.map((m) {
      return FlowHistoryMessage(
        role: m.role == ChatRole.user ? 'user' : 'model',
        content: m.content,
      );
    }).toList();

    final input = JarvisChatInput(
      message: prompt,
      systemPrompt: system,
      history: flowHistory,
    );

    final reply = await _flow.run(input);
    final text = reply.result.trim();
    if (text.isEmpty) {
      throw const JarvisAiException('AI flow returned an empty response.');
    }
    return text;
  }
}

/// Core AI Service for JARVIS Assistant.
///
/// Handles user message validation, orchestrates AI generation via [AiGenerator],
/// manages multi-turn history via [ConversationHistoryService], injects the JARVIS system
/// prompt, and sanitizes errors without leaking credentials.
class JarvisAIService {
  final AiGenerator _generator;
  final ConversationHistoryService _historyService;

  /// Creates a [JarvisAIService] with optional [generator] and [historyService].
  ///
  /// If omitted, [FlowAiGenerator] and an in-memory [ConversationHistoryService] are used.
  JarvisAIService({
    AiGenerator? generator,
    ConversationHistoryService? historyService,
  }) : _generator = generator ?? FlowAiGenerator(),
       _historyService = historyService ?? ConversationHistoryService();

  /// Accessor for the underlying conversation history service.
  ConversationHistoryService get historyService => _historyService;

  /// Processes a [userMessage] within a conversation, persisting history and returning
  /// a context-aware [JarvisChatResponse].
  ///
  /// - If [conversationId] is null or empty, a new conversation is started automatically.
  /// - If [conversationId] is provided, verifies that it exists, throws [ConversationNotFoundException] if missing.
  /// - Loads existing messages for context-aware multi-turn generation.
  /// - Injects the centralized JARVIS system instruction (or [customSystemPrompt] if provided).
  /// - Persists both the user message and the assistant reply atomically.
  Future<JarvisChatResponse> chat({
    required String userMessage,
    String? conversationId,
    String? customSystemPrompt,
  }) async {
    final trimmedMessage = userMessage.trim();
    if (trimmedMessage.isEmpty) {
      throw const InvalidMessageException('User message cannot be empty.');
    }

    Conversation conversation;
    if (conversationId == null || conversationId.trim().isEmpty) {
      conversation = await _historyService.startConversation();
    } else {
      final existing = await _historyService.getConversation(
        conversationId.trim(),
      );
      if (existing == null) {
        throw ConversationNotFoundException(conversationId.trim());
      }
      conversation = existing;
    }

    final targetConvId = conversation.conversationId;
    final priorHistory = List<ChatMessage>.from(conversation.messages);

    final systemInstruction = customSystemPrompt?.trim().isNotEmpty == true
        ? customSystemPrompt!.trim()
        : JarvisPrompts.systemInstruction;

    String reply;
    try {
      reply = await _generator.generateText(
        prompt: trimmedMessage,
        system: systemInstruction,
        history: priorHistory,
      );

      if (reply.isEmpty) {
        throw const JarvisAiException('AI returned an empty response.');
      }
    } on InvalidMessageException {
      rethrow;
    } on JarvisAiException {
      rethrow;
    } catch (e) {
      throw JarvisAiException(
        'Unable to complete request at this time. Please try again later.',
        e,
      );
    }

    // Persist messages in conversation history
    final savedUserMsg = await _historyService.addUserMessage(
      targetConvId,
      trimmedMessage,
    );
    final savedAssistantMsg = await _historyService.addAssistantMessage(
      targetConvId,
      reply,
    );

    return JarvisChatResponse(
      conversationId: targetConvId,
      reply: reply,
      userMessage: savedUserMsg,
      assistantMessage: savedAssistantMsg,
    );
  }

  /// Backward-compatible single-message helper preserving Phase 2/3 public API.
  Future<String> sendMessage(
    String userMessage, {
    String? customSystemPrompt,
  }) async {
    final result = await chat(
      userMessage: userMessage,
      customSystemPrompt: customSystemPrompt,
    );
    return result.reply;
  }
}
