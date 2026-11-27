import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

import 'env.dart';

/// Centralized AI Configuration for JARVIS backend.
///
/// Manages singleton initialization of [Genkit] configured with Google Gemini provider.
class AiConfig {
  AiConfig._();

  static Genkit? _instance;
  static String? _configuredApiKey;

  /// Default model used by JARVIS.
  /// Can be overridden via `GEMINI_MODEL` environment variable.
  static String get defaultModelName =>
      Env.get('GEMINI_MODEL', defaultValue: 'gemini-3.1-flash-lite')!;

  /// Model reference for Google Gemini configured for JARVIS.
  static ModelRef<GeminiOptions> get model => googleAI.gemini(defaultModelName);

  /// Initializes and returns the singleton [Genkit] instance.
  ///
  /// Reads `GEMINI_API_KEY` (or `GOOGLE_GENAI_API_KEY` / `GOOGLE_API_KEY`) from environment.
  /// Throws [StateError] if no API key is found.
  static Genkit initialize({String? apiKey, bool isDevEnv = false}) {
    if (_instance != null) {
      return _instance!;
    }

    final key =
        apiKey ??
        Env.get('GEMINI_API_KEY') ??
        Env.get('GOOGLE_GENAI_API_KEY') ??
        Env.get('GOOGLE_API_KEY');

    if (key == null || key.trim().isEmpty) {
      throw StateError(
        'Gemini API key is not configured. '
        'Please set GEMINI_API_KEY in your .env file or environment variables.',
      );
    }

    _configuredApiKey = key.trim();

    _instance = Genkit(
      plugins: [googleAI(apiKey: _configuredApiKey)],
      model: model,
      isDevEnv: isDevEnv,
    );

    return _instance!;
  }

  /// Returns the current initialized [Genkit] instance.
  /// Throws [StateError] if [initialize] has not been called.
  static Genkit get genkit {
    if (_instance == null) {
      throw StateError(
        'AiConfig has not been initialized. Call AiConfig.initialize() before accessing genkit.',
      );
    }
    return _instance!;
  }

  /// Resets the Genkit singleton instance (primarily for testing).
  static void resetForTesting() {
    _instance = null;
    _configuredApiKey = null;
  }
}
