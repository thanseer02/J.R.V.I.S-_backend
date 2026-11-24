/// Represents the role of the message participant.
enum ChatRole {
  user,
  assistant,
  system;

  /// Parses [value] into a [ChatRole], defaulting to [user] if unrecognized.
  static ChatRole fromString(String value) {
    switch (value.toLowerCase().trim()) {
      case 'assistant':
      case 'model':
        return ChatRole.assistant;
      case 'system':
        return ChatRole.system;
      case 'user':
      default:
        return ChatRole.user;
    }
  }

  /// String name for API representation.
  String toJson() => name;
}

/// A single message in a conversation.
class ChatMessage {
  final String messageId;
  final ChatRole role;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.messageId,
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['messageId'] as String,
      role: ChatRole.fromString(json['role'] as String? ?? 'user'),
      content: json['content'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'messageId': messageId,
        'role': role.toJson(),
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          messageId == other.messageId &&
          role == other.role &&
          content == other.content &&
          timestamp == other.timestamp;

  @override
  int get hashCode =>
      messageId.hashCode ^ role.hashCode ^ content.hashCode ^ timestamp.hashCode;
}
