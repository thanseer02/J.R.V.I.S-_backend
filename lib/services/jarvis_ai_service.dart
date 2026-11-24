import 'dart:async';

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

import '../config/ai_config.dart';
import '../config/jarvis_prompts.dart';
import '../flows/chat_flow.dart';

/// Exception thrown when the user provides an invalid message.
class InvalidMessageException implements Exception {
  final String message;
  const InvalidMessageException(this.message);

  @override
  String toString() => 'InvalidMessageException: $message';
}

/// Exception thrown when AI generation fails.
class JarvisAiException implements Exception {
  final String message;
  final Object? cause;

  const JarvisAiException(this.message, [this.cause]);

  @override
  String toString() => 'JarvisAiException: $message';
}

/// Abstract contract for AI generation, enabling dependency injection and testing.
abstract class AiGenerator {
  /// Generates a response given [prompt] and [system] instruction.
  Future<String> generateText({
    required String prompt,
    String? system,
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
    ModelRef<GeminiOptions>? model,
  }) async {
    final input = JarvisChatInput(message: prompt, systemPrompt: system);

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
/// injects the JARVIS system prompt, and sanitizes errors without leaking credentials.
class JarvisAIService {
  final AiGenerator _generator;

  /// Creates a [JarvisAIService] with an optional [generator].
  ///
  /// If [generator] is omitted, [FlowAiGenerator] is used by default.
  JarvisAIService({AiGenerator? generator})
    : _generator = generator ?? FlowAiGenerator();

  /// Processes a [userMessage] and returns JARVIS's response.
  ///
  /// - Validates that [userMessage] is not empty or whitespace.
  /// - Injects the centralized JARVIS system instruction (or [customSystemPrompt] if provided).
  /// - Catches API/network failures and wraps them in a user-safe [JarvisAiException].
  ///
  /// Throws [InvalidMessageException] if the message is blank or whitespace.
  /// Throws [JarvisAiException] if generation fails or yields an empty response.
  Future<String> sendMessage(
    String userMessage, {
    String? customSystemPrompt,
  }) async {
    final trimmedMessage = userMessage.trim();
    if (trimmedMessage.isEmpty) {
      throw const InvalidMessageException('User message cannot be empty.');
    }

    final systemInstruction = customSystemPrompt?.trim().isNotEmpty == true
        ? customSystemPrompt!.trim()
        : JarvisPrompts.systemInstruction;

    try {
      final reply = await _generator.generateText(
        prompt: trimmedMessage,
        system: systemInstruction,
      );

      if (reply.isEmpty) {
        throw const JarvisAiException('AI returned an empty response.');
      }

      return reply;
    } on InvalidMessageException {
      rethrow;
    } on JarvisAiException {
      rethrow;
    } catch (e) {
      // Shield clients and logs from internal stack traces or raw API key strings
      throw JarvisAiException(
        'Unable to complete request at this time. Please try again later.',
        e,
      );
    }
  }
}
