import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

/// Input parameters for retrieving application metadata.
class AppInfoInput {
  const AppInfoInput();

  static final schema = SchemanticType.from<AppInfoInput>(
    jsonSchema: {'type': 'object', 'properties': {}},
    parse: (_) => const AppInfoInput(),
  );
}

/// Pure helper and Genkit tool for retrieving JARVIS application information and capabilities.
class AppInfoTool {
  AppInfoTool._();

  static const String appName = 'JARVIS AI Assistant';
  static const String appVersion = '1.0.0';
  static const List<String> capabilities = [
    'Conversational AI powered by Google Gemini',
    'Arithmetic and mathematical calculations (Calculator)',
    'Current local date and time lookup',
    'Application information and capabilities reporting',
    'Extensible Genkit flow orchestration',
  ];

  /// Returns structured application metadata.
  static Map<String, dynamic> getInfo() {
    return {
      'name': appName,
      'version': appVersion,
      'capabilities': capabilities,
      'backend': 'Dart & Firebase Genkit',
    };
  }

  /// Registers and returns the appInfo tool on the given [genkit] instance.
  static Tool<AppInfoInput, String> define(Genkit genkit) {
    return genkit.defineTool<AppInfoInput, String>(
      name: 'getAppInfo',
      description: 'Retrieves application information, assistant name, version, and available capabilities.',
      inputSchema: AppInfoInput.schema,
      fn: (input, context) async {
        final info = getInfo();
        final caps = (info['capabilities'] as List<String>)
            .map((c) => '  - $c')
            .join('\n');
        final response =
            '${info['name']} (v${info['version']})\nBackend: ${info['backend']}\nCapabilities:\n$caps';
        return ToolResult.response(response);
      },
    );
  }
}
