import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../middleware/api_middleware.dart';
import '../routes/jarvis_routes.dart';
import '../services/jarvis_ai_service.dart';

/// Creates the configured Shelf [Handler] pipeline for the JARVIS backend.
Handler createJarvisHandler(JarvisAIService aiService, {bool enableLogging = true}) {
  final routes = JarvisRoutes(aiService);

  var pipeline = const Pipeline()
      .addMiddleware(corsMiddleware())
      .addMiddleware(jsonErrorMiddleware());

  if (enableLogging) {
    pipeline = pipeline.addMiddleware(logRequests());
  }

  return pipeline.addHandler(routes.router.call);
}

/// Starts the Shelf HTTP server on [host]:[port] using [aiService].
Future<HttpServer> startJarvisServer({
  required JarvisAIService aiService,
  String host = 'localhost',
  int port = 8080,
  bool enableLogging = true,
}) {
  final handler = createJarvisHandler(aiService, enableLogging: enableLogging);
  return shelf_io.serve(handler, host, port);
}
