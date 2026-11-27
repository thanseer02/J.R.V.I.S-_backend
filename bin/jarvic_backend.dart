import 'dart:io';

import 'package:jarvic_backend/config/ai_config.dart';
import 'package:jarvic_backend/config/env.dart';
import 'package:jarvic_backend/services/jarvis_ai_service.dart';
import 'package:jarvic_backend/server/jarvis_server.dart';

Future<void> main(List<String> arguments) async {
  Env.load();

  final host = Env.get('HOST', defaultValue: 'localhost')!;
  final port = Env.getInt('PORT', defaultValue: 8080)!;

  AiConfig.initialize();
  final aiService = JarvisAIService();

  final server = await startJarvisServer(
    aiService: aiService,
    host: host,
    port: port,
  );

  stdout.writeln(
    'JARVIS backend listening on http://${server.address.host}:${server.port} '
    '(model: ${AiConfig.defaultModelName})',
  );
}
