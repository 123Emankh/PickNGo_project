// lib/data/models/chat_message_model.dart
class ChatMessageModel {
  final String? id;
  final String role; // 'user' | 'model'
  final String content;
  final DateTime createdAt;

  ChatMessageModel({
    this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  bool get isUser => role == 'user';

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id']?.toString(),
      role: json['role'] ?? 'model',
      content: json['content'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  factory ChatMessageModel.local({required String role, required String content}) {
    return ChatMessageModel(role: role, content: content, createdAt: DateTime.now());
  }
}
