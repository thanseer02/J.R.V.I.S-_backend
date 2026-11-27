import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../config/ai_config.dart';
import '../middleware/api_middleware.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../services/jarvis_ai_service.dart';

/// Builds the Shelf [Router] exposing JARVIS REST API endpoints.
class JarvisRoutes {
  final JarvisAIService _aiService;

  JarvisRoutes(this._aiService);

  Router get router {
    final router = Router();

    router.get('/api/health', _handleHealth);
    router.get('/api/conversations', _handleListConversations);
    router.post('/api/conversations', _handleCreateConversation);
    router.get('/api/conversations/<id>', _handleGetConversation);
    router.delete('/api/conversations/<id>', _handleDeleteConversation);
    router.post('/api/chat', _handleChat);

    return router;
  }

  Future<Response> _handleHealth(Request request) async {
    return jsonResponse(HttpStatus.ok, {
      'status': 'ok',
      'service': 'jarvic_backend',
      'model': AiConfig.defaultModelName,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<Response> _handleListConversations(Request request) async {
    final conversations = await _aiService.historyService.listConversations();
    return jsonResponse(
      HttpStatus.ok,
      conversations.map(_serializeConversation).toList(),
    );
  }

  Future<Response> _handleCreateConversation(Request request) async {
    final body = await _readJsonObject(request);
    final title = body['title'] as String?;

    final conversation = await _aiService.historyService.startConversation(
      title: title,
    );
    return jsonResponse(
      HttpStatus.created,
      _serializeConversation(conversation),
    );
  }

  Future<Response> _handleGetConversation(Request request, String id) async {
    final conversation = await _aiService.historyService.getConversation(id);
    if (conversation == null) {
      return jsonResponse(
        HttpStatus.notFound,
        {'error': 'Conversation "$id" not found.'},
      );
    }

    return jsonResponse(HttpStatus.ok, _serializeConversation(conversation));
  }

  Future<Response> _handleDeleteConversation(Request request, String id) async {
    final deleted = await _aiService.historyService.deleteConversation(id);
    if (!deleted) {
      return jsonResponse(
        HttpStatus.notFound,
        {'error': 'Conversation "$id" not found.'},
      );
    }

    return jsonResponse(HttpStatus.ok, {'deleted': true, 'id': id});
  }

  Future<Response> _handleChat(Request request) async {
    final body = await _readJsonObject(request);
    final message = body['message'] as String? ?? '';
    final conversationId = body['conversationId'] as String?;
    final systemPrompt = body['systemPrompt'] as String?;

    try {
      final result = await _aiService.chat(
        userMessage: message,
        conversationId: conversationId,
        customSystemPrompt: systemPrompt,
      );

      final assistantDto = _serializeMessage(
        result.assistantMessage,
        result.conversationId,
      );

      return jsonResponse(HttpStatus.ok, {
        'conversationId': result.conversationId,
        'reply': result.reply,
        'message': assistantDto,
      });
    } on InvalidMessageException catch (e) {
      return jsonResponse(HttpStatus.badRequest, {'error': e.message});
    } on ConversationNotFoundException catch (e) {
      return jsonResponse(HttpStatus.notFound, {'error': e.toString()});
    } on JarvisAiException catch (e) {
      stderr.writeln('JarvisAiException during /api/chat: ${e.cause ?? e}');
      return jsonResponse(HttpStatus.badGateway, {'error': e.message});
    }
  }

  Future<Map<String, dynamic>> _readJsonObject(Request request) async {
    final raw = await request.readAsString();
    if (raw.trim().isEmpty) {
      return <String, dynamic>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Expected a JSON object.');
    }
    return decoded.cast<String, dynamic>();
  }

  Map<String, dynamic> _serializeConversation(Conversation conversation) {
    final preview = conversation.messages.isNotEmpty
        ? conversation.messages.last.content
        : null;
    return {
      'id': conversation.conversationId,
      'title': conversation.title,
      'createdAt': conversation.createdAt.toIso8601String(),
      'updatedAt': conversation.updatedAt.toIso8601String(),
      'lastMessagePreview': preview,
      'messages': conversation.messages
          .map((m) => _serializeMessage(m, conversation.conversationId))
          .toList(),
    };
  }

  Map<String, dynamic> _serializeMessage(
    ChatMessage message,
    String conversationId,
  ) {
    return {
      'id': message.messageId,
      'conversationId': conversationId,
      'text': message.content,
      'sender': message.role == ChatRole.user ? 'user' : 'assistant',
      'timestamp': message.timestamp.toIso8601String(),
    };
  }
}
