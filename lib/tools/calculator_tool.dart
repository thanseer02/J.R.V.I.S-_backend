import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

/// Supported operations for the calculator.
enum CalculatorOperation {
  add,
  subtract,
  multiply,
  divide;

  /// Parses operation from a string safely.
  static CalculatorOperation? fromString(String op) {
    switch (op.toLowerCase().trim()) {
      case 'add':
      case '+':
        return CalculatorOperation.add;
      case 'subtract':
      case '-':
        return CalculatorOperation.subtract;
      case 'multiply':
      case '*':
        return CalculatorOperation.multiply;
      case 'divide':
      case '/':
        return CalculatorOperation.divide;
      default:
        return null;
    }
  }
}

/// Input model for calculator operations.
class CalculatorInput {
  final double a;
  final double b;
  final String operation;

  const CalculatorInput({
    required this.a,
    required this.b,
    required this.operation,
  });

  factory CalculatorInput.fromJson(Map<String, dynamic> json) {
    return CalculatorInput(
      a: (json['a'] as num).toDouble(),
      b: (json['b'] as num).toDouble(),
      operation: json['operation'] as String? ?? 'add',
    );
  }

  Map<String, dynamic> toJson() => {'a': a, 'b': b, 'operation': operation};

  static final schema = SchemanticType.from<CalculatorInput>(
    jsonSchema: {
      'type': 'object',
      'properties': {
        'a': {'type': 'number', 'description': 'The first operand'},
        'b': {'type': 'number', 'description': 'The second operand'},
        'operation': {
          'type': 'string',
          'description': 'The arithmetic operation: "add", "subtract", "multiply", or "divide"',
          'enum': ['add', 'subtract', 'multiply', 'divide'],
        },
      },
      'required': ['a', 'b', 'operation'],
    },
    parse: (json) =>
        CalculatorInput.fromJson((json as Map).cast<String, dynamic>()),
  );
}

/// Output model for calculator operations.
class CalculatorResult {
  final double? result;
  final String? error;
  final bool success;

  const CalculatorResult._({this.result, this.error, required this.success});

  factory CalculatorResult.ok(double value) =>
      CalculatorResult._(result: value, success: true);

  factory CalculatorResult.failure(String message) =>
      CalculatorResult._(error: message, success: false);

  Map<String, dynamic> toJson() => {
    'success': success,
    if (result != null) 'result': result,
    if (error != null) 'error': error,
  };

  @override
  String toString() {
    if (success) {
      // Format cleanly: drop unnecessary trailing .0
      final formatted = result! % 1 == 0
          ? result!.toInt().toString()
          : result.toString();
      return formatted;
    }
    return 'Error: $error';
  }
}

/// Pure arithmetic functions and tool definition.
class CalculatorTool {
  CalculatorTool._();

  /// Computes arithmetic operation safely.
  static CalculatorResult calculate(double a, double b, String opName) {
    final op = CalculatorOperation.fromString(opName);
    if (op == null) {
      return CalculatorResult.failure(
        'Unknown operation: "$opName". Supported operations: add, subtract, multiply, divide.',
      );
    }

    switch (op) {
      case CalculatorOperation.add:
        return CalculatorResult.ok(a + b);
      case CalculatorOperation.subtract:
        return CalculatorResult.ok(a - b);
      case CalculatorOperation.multiply:
        return CalculatorResult.ok(a * b);
      case CalculatorOperation.divide:
        if (b == 0.0) {
          return CalculatorResult.failure('Division by zero is undefined.');
        }
        return CalculatorResult.ok(a / b);
    }
  }

  /// Registers and returns the calculator tool on the given [genkit] instance.
  static Tool<CalculatorInput, String> define(Genkit genkit) {
    return genkit.defineTool<CalculatorInput, String>(
      name: 'calculator',
      description: 'Performs arithmetic calculations (addition, subtraction, multiplication, division). Handles division by zero safely.',
      inputSchema: CalculatorInput.schema,
      fn: (input, context) async {
        final res = calculate(input.a, input.b, input.operation);
        return ToolResult.response(res.toString());
      },
    );
  }
}
