import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

import '../config/ai_config.dart';
import '../config/jarvis_prompts.dart';
import '../tools/app_info_tool.dart';
import '../tools/calculator_tool.dart';
import '../tools/date_time_tool.dart';

/// Input schema for the JARVIS chat flow.
class JarvisChatInput {
  final String message;
  final String? systemPrompt;

  const JarvisChatInput({required this.message, this.systemPrompt});

  factory JarvisChatInput.fromJson(Map<String, dynamic> json) {
    return JarvisChatInput(
      message: json['message'] as String? ?? '',
      systemPrompt: json['systemPrompt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'message': message,
    if (systemPrompt != null) 'systemPrompt': systemPrompt,
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
      },
      'required': ['message'],
    },
    parse: (json) =>
        JarvisChatInput.fromJson((json as Map).cast<String, dynamic>()),
  );
}

/// Flow definition and registration for JARVIS chat generation with tool support.
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
        final systemInstruction =
            (input.systemPrompt != null &&
                input.systemPrompt!.trim().isNotEmpty)
            ? input.systemPrompt!.trim()
            : JarvisPrompts.systemInstruction;

        final response = await genkit.generate(
          model: AiConfig.model,
          system: systemInstruction,
          prompt: userMessage,
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
