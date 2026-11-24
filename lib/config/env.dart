import 'dart:io';

/// Utility for loading key-value pairs from `.env` files into Dart environment.
class Env {
  static final Map<String, String> _env = <String, String>{};
  static bool _loaded = false;

  /// Loads environment variables from the given [filePath].
  ///
  /// If variables already exist in [Platform.environment], they are preserved
  /// and take precedence over `.env` values.
  static void load({String filePath = '.env'}) {
    // Start with process environment
    _env.addAll(Platform.environment);

    final file = File(filePath);
    if (!file.existsSync()) {
      _loaded = true;
      return;
    }

    final lines = file.readAsLinesSync();
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      final separatorIndex = line.indexOf('=');
      if (separatorIndex == -1) {
        continue;
      }

      final key = line.substring(0, separatorIndex).trim();
      var value = line.substring(separatorIndex + 1).trim();

      // Remove surrounding quotes if present
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        if (value.length >= 2) {
          value = value.substring(1, value.length - 1);
        }
      }

      // Do not overwrite existing process environment variables
      _env.putIfAbsent(key, () => value);
      // But if process environment didn't have it, set it
      if (!Platform.environment.containsKey(key)) {
        _env[key] = value;
      }
    }

    _loaded = true;
  }

  /// Gets the string value for [key], or returns [defaultValue] if not found.
  static String? get(String key, {String? defaultValue}) {
    if (!_loaded) {
      load();
    }
    return _env[key] ?? defaultValue;
  }

  /// Gets the integer value for [key], or returns [defaultValue] if invalid/not found.
  static int? getInt(String key, {int? defaultValue}) {
    final value = get(key);
    if (value == null) return defaultValue;
    return int.tryParse(value) ?? defaultValue;
  }

  /// Resets loaded cache (useful for testing).
  static void resetForTesting([Map<String, String>? testEnv]) {
    _env.clear();
    if (testEnv != null) {
      _env.addAll(testEnv);
      _loaded = true;
    } else {
      _loaded = false;
    }
  }
}
