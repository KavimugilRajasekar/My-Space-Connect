import 'package:hive/hive.dart';

part 'models.g.dart';

@HiveType(typeId: 0)
class Message extends HiveObject {
  @HiveField(0)
  final int id;
  
  @HiveField(1)
  String text;
  
  @HiveField(2)
  final bool isUser;
  
  @HiveField(3)
  final DateTime timestamp;
  
  @HiveField(4)
  final bool isAudio;
  
  @HiveField(5)
  final bool isImage;

  Message({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isAudio = false,
    this.isImage = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch,
      text: json['text'] ?? '',
      isUser: json['isUser'] ?? false,
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      isAudio: json['isAudio'] ?? false,
      isImage: json['isImage'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'isAudio': isAudio,
      'isImage': isImage,
    };
  }
}

@HiveType(typeId: 1)
class ChatSession extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  final DateTime lastUpdated;

  @HiveField(4)
  final List<Message> messages;

  @HiveField(5)
  final String? recipientId;

  @HiveField(6)
  final String? profileImageBase64;

  @HiveField(7)
  DateTime? lastConnected;

  @HiveField(8)
  String? peerName;

  @HiveField(9)
  String? peerUuid;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastUpdated,
    this.recipientId,
    this.profileImageBase64,
    this.lastConnected,
    this.peerName,
    this.peerUuid,
    List<Message>? messages,
  }) : messages = messages ?? [];

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final messagesList = json['messages'] as List<dynamic>? ?? [];
    return ChatSession(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      recipientId: json['recipientId'] as String?,
      profileImageBase64: json['profileImageBase64'] as String?,
      lastConnected: json['lastConnected'] != null
          ? DateTime.parse(json['lastConnected'] as String)
          : null,
      peerName: json['peerName'] as String?,
      peerUuid: json['peerUuid'] as String?,
      messages: messagesList
          .map((msg) => Message.fromJson(msg as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'recipientId': recipientId,
      'profileImageBase64': profileImageBase64,
      'lastConnected': lastConnected?.toIso8601String(),
      'peerName': peerName,
      'peerUuid': peerUuid,
      'messages': messages.map((msg) => msg.toJson()).toList(),
    };
  }

  ChatSession copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? lastUpdated,
    List<Message>? messages,
    String? recipientId,
    String? profileImageBase64,
    DateTime? lastConnected,
    String? peerName,
    String? peerUuid,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      messages: messages ?? this.messages,
      recipientId: recipientId ?? this.recipientId,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
      lastConnected: lastConnected ?? this.lastConnected,
      peerName: peerName ?? this.peerName,
      peerUuid: peerUuid ?? this.peerUuid,
    );
  }
}
