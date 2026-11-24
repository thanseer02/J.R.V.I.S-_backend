import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

import '../config/ai_config.dart';
import '../config/jarvis_prompts.dart';
import '../models/chat_message.dart';
import '../tools/app_info_tool.dart';
import '../tools/calculator_tool.dart';
import '../tools/date_time_tool.dart';

/// Serializable message history DTO for Genkit flow input.
class FlowHistoryMessage {
  final String role;
  final String content;

  const FlowHistoryMessage({required this.role, required this.content});

  factory FlowHistoryMessage.fromJson(Map<String, dynamic> json) {
    return FlowHistoryMessage(
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };

  static final schema = SchemanticType.from<FlowHistoryMessage>(
    jsonSchema: {
      'type': 'object',
      'properties': {
        'role': {'type': 'string'},
        'content': {'type': 'string'},
      },
      'required': ['role', 'content'],
    },
    parse: (json) =>
        FlowHistoryMessage.fromJson((json as Map).cast<String, dynamic>()),
  );
}

/// Input schema for the JARVIS chat flow with optional message history.
class JarvisChatInput {
  final String message;
  final String? systemPrompt;
  final List<FlowHistoryMessage> history;

  const JarvisChatInput({
    required this.message,
    this.systemPrompt,
    this.history = const [],
  });

  factory JarvisChatInput.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['history'] as List<dynamic>? ?? [];
    return JarvisChatInput(
      message: json['message'] as String? ?? '',
      systemPrompt: json['systemPrompt'] as String?,
      history: rawHistory
          .map((m) => FlowHistoryMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'message': message,
        if (systemPrompt != null) 'systemPrompt': systemPrompt,
        'history': history.map((m) => m.toJson()).toList(),
      };

  static final schema = SchemanticType.from<JarvisChatInput>(
    jsonSchema: {
      'type': 'object',
      'properties': {
        'message': {
          'type': 'string',
          'description': 'The user message to send to JARVIS',
        },
        'systemPrompt': {
          'type': 'string',
          'description': 'Optional custom system instruction',
        },
        'history': {
          'type': 'array',
          'description': 'Previous conversation message history',
          'items': FlowHistoryMessage.schema.jsonSchema(),
        },
      },
      'required': ['message'],
    },
    parse: (json) =>
        JarvisChatInput.fromJson((json as Map).cast<String, dynamic>()),
  );
}

/// Flow definition and registration for JARVIS chat generation with tool and history support.
class JarvisChatFlow {
  JarvisChatFlow._();

  static const String flowName = 'jarvisChatFlow';

  static Flow<JarvisChatInput, String, void, void>? _registeredFlow;
  static List<Tool>? _registeredTools;

  /// Defines and registers the tools and the chat flow on the given [genkit] instance.
  ///
  /// If [clock] is provided, it is used by the `DateTimeTool` for deterministic testing.
  static Flow<JarvisChatInput, String, void, void> define(
    Genkit genkit, {
    DateTime Function()? clock,
  }) {
    // Register tools once
    final calcTool = CalculatorTool.define(genkit);
    final dateTimeTool = DateTimeTool.define(genkit, clock: clock);
    final appInfoTool = AppInfoTool.define(genkit);

    final tools = [calcTool, dateTimeTool, appInfoTool];
    _registeredTools = tools;

    final flow = genkit.defineFlow<JarvisChatInput, String, void, void>(
      name: flowName,
      inputSchema: JarvisChatInput.schema,
      outputSchema: SchemanticType.string(),
      fn: (input, context) async {
        final userMessage = input.message.trim();
        final systemInstruction = (input.systemPrompt != null &&
                input.systemPrompt!.trim().isNotEmpty)
            ? input.systemPrompt!.trim()
            : JarvisPrompts.systemInstruction;

        // Map prior history into Genkit Message instances
        final genkitMessages = <Message>[];
        for (final item in input.history) {
          final isUser = item.role == 'user';
          genkitMessages.add(
            Message(
              role: isUser ? Role.user : Role.model,
              content: [TextPart(text: item.content)],
            ),
          );
        }

        final response = await genkit.generate(
          model: AiConfig.model,
          system: systemInstruction,
          prompt: userMessage,
          messages: genkitMessages.isNotEmpty ? genkitMessages : null,
          tools: tools,
        );

        final replyText = response.text.trim();
        if (replyText.isEmpty) {
          throw StateError('AI returned an empty response.');
        }

        return replyText;
      },
    );

    _registeredFlow = flow;
    return flow;
  }

  /// Returns the registered flow or null if not yet defined.
  static Flow<JarvisChatInput, String, void, void>? get registeredFlow =>
      _registeredFlow;

  /// Returns the registered tools or null if not yet defined.
  static List<Tool>? get registeredTools => _registeredTools;

  /// Resets registered flow and tools cache for testing.
  static void resetForTesting() {
    _registeredFlow = null;
    _registeredTools = null;
  }
}
