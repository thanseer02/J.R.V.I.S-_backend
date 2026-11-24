import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

/// Input parameters for date and time queries.
class DateTimeInput {
  /// Type of date/time representation requested: "date", "time", or "datetime".
  final String format;

  const DateTimeInput({this.format = 'datetime'});

  factory DateTimeInput.fromJson(Map<String, dynamic> json) {
    return DateTimeInput(format: (json['format'] as String?) ?? 'datetime');
  }

  static final schema = SchemanticType.from<DateTimeInput>(
    jsonSchema: {
      'type': 'object',
      'properties': {
        'format': {
          'type': 'string',
          'description': 'Requested date/time format: "date" (YYYY-MM-DD), "time" (HH:MM:SS), or "datetime" (full local date and time). Defaults to "datetime".',
          'enum': ['date', 'time', 'datetime'],
        },
      },
    },
    parse: (json) =>
        DateTimeInput.fromJson((json as Map).cast<String, dynamic>()),
  );
}

/// Pure helper and Genkit tool for retrieving the current local date and time.
class DateTimeTool {
  DateTimeTool._();

  /// Formats [now] according to the requested [format] ('date', 'time', or 'datetime').
  static String formatDateTime(DateTime now, {String format = 'datetime'}) {
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');

    final dateStr = '$year-$month-$day';
    final timeStr = '$hour:$minute:$second';

    switch (format.toLowerCase().trim()) {
      case 'date':
        return dateStr;
      case 'time':
        return timeStr;
      case 'datetime':
      default:
        return '$dateStr $timeStr (local time)';
    }
  }

  /// Registers and returns the dateTime tool on the given [genkit] instance.
  static Tool<DateTimeInput, String> define(
    Genkit genkit, {
    DateTime Function()? clock,
  }) {
    return genkit.defineTool<DateTimeInput, String>(
      name: 'getDateTime',
      description: 'Gets the current local date, time, or full date and time. Useful when the user asks what day, date, or time it is.',
      inputSchema: DateTimeInput.schema,
      fn: (input, context) async {
        final now = (clock != null) ? clock() : DateTime.now();
        final formatted = formatDateTime(now, format: input.format);
        return ToolResult.response(formatted);
      },
    );
  }
}
