import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

const Map<String, String> _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers':
      'Origin, Content-Type, Accept, Authorization, X-Client',
};

/// Adds CORS headers to all responses and short-circuits `OPTIONS` preflight requests.
Middleware corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response(HttpStatus.noContent, headers: _corsHeaders);
      }

      final response = await innerHandler(request);
      return response.change(headers: _corsHeaders);
    };
  };
}

/// Catches unhandled exceptions and returns sanitized JSON error responses.
Middleware jsonErrorMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      try {
        return await innerHandler(request);
      } on FormatException catch (e) {
        return jsonResponse(
          HttpStatus.badRequest,
          {'error': 'Invalid request payload: ${e.message}'},
        );
      } catch (e, st) {
        stderr.writeln('Unhandled server error: $e\n$st');
        return jsonResponse(
          HttpStatus.internalServerError,
          {'error': 'Internal server error. Please try again later.'},
        );
      }
    };
  };
}

/// Helper to create a JSON [Response] with proper content-type header.
Response jsonResponse(int statusCode, Object body) {
  return Response(
    statusCode,
    body: jsonEncode(body),
    headers: const {'Content-Type': 'application/json; charset=utf-8'},
  );
}
