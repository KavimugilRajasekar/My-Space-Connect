import 'package:flutter_test/flutter_test.dart';
import 'package:my_space_connect/models.dart';

void main() {
  group('Message Model', () {
    test('creates message with required fields', () {
      final msg = Message(
        id: 1,
        text: 'Hello',
        isUser: true,
        timestamp: DateTime(2026, 3, 22),
      );

      expect(msg.id, 1);
      expect(msg.text, 'Hello');
      expect(msg.isUser, true);
      expect(msg.isAudio, false);
      expect(msg.isImage, false);
    });

    test('creates audio message', () {
      final msg = Message(
        id: 2,
        text: 'Voice note',
        isUser: false,
        timestamp: DateTime(2026, 3, 22),
        isAudio: true,
      );

      expect(msg.isAudio, true);
      expect(msg.isImage, false);
    });

    test('creates image message', () {
      final msg = Message(
        id: 3,
        text: 'Photo',
        isUser: true,
        timestamp: DateTime(2026, 3, 22),
        isImage: true,
      );

      expect(msg.isImage, true);
    });

    test('serializes to JSON and back', () {
      final original = Message(
        id: 42,
        text: 'Test message',
        isUser: true,
        timestamp: DateTime(2026, 3, 22, 10, 30),
        isAudio: false,
        isImage: true,
      );

      final json = original.toJson();
      final restored = Message.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.text, original.text);
      expect(restored.isUser, original.isUser);
      expect(restored.isAudio, original.isAudio);
      expect(restored.isImage, original.isImage);
    });

    test('fromJson handles missing fields with defaults', () {
      final msg = Message.fromJson({});

      expect(msg.id, isA<int>());
      expect(msg.text, '');
      expect(msg.isUser, false);
      expect(msg.isAudio, false);
      expect(msg.isImage, false);
    });
  });

  group('ChatSession Model', () {
    test('creates chat session with messages', () {
      final session = ChatSession(
        id: 'session-1',
        title: 'Test Chat',
        createdAt: DateTime(2026, 3, 22),
        lastUpdated: DateTime(2026, 3, 22),
        peerName: 'Alice',
        peerUuid: 'uuid-123',
      );

      expect(session.id, 'session-1');
      expect(session.title, 'Test Chat');
      expect(session.peerName, 'Alice');
      expect(session.peerUuid, 'uuid-123');
      expect(session.messages, isEmpty);
    });

    test('creates chat session with message list', () {
      final messages = [
        Message(id: 1, text: 'Hi', isUser: true, timestamp: DateTime.now()),
        Message(id: 2, text: 'Hello', isUser: false, timestamp: DateTime.now()),
      ];

      final session = ChatSession(
        id: 'session-2',
        title: 'Chat',
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
        messages: messages,
      );

      expect(session.messages.length, 2);
      expect(session.messages[0].text, 'Hi');
      expect(session.messages[1].text, 'Hello');
    });

    test('serializes to JSON and back', () {
      final messages = [
        Message(
          id: 1,
          text: 'Message 1',
          isUser: true,
          timestamp: DateTime(2026, 3, 22, 10, 0),
        ),
        Message(
          id: 2,
          text: 'Message 2',
          isUser: false,
          timestamp: DateTime(2026, 3, 22, 10, 1),
          isAudio: true,
        ),
      ];

      final original = ChatSession(
        id: 'session-json',
        title: 'JSON Test',
        createdAt: DateTime(2026, 3, 22, 9, 0),
        lastUpdated: DateTime(2026, 3, 22, 10, 1),
        peerName: 'Bob',
        peerUuid: 'uuid-bob',
        profileImageBase64: null,
        messages: messages,
      );

      final json = original.toJson();
      final restored = ChatSession.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.peerName, original.peerName);
      expect(restored.peerUuid, original.peerUuid);
      expect(restored.messages.length, 2);
      expect(restored.messages[0].text, 'Message 1');
      expect(restored.messages[1].isAudio, true);
    });

    test('copyWith creates modified copy', () {
      final original = ChatSession(
        id: 'copy-test',
        title: 'Original',
        createdAt: DateTime(2026, 3, 22),
        lastUpdated: DateTime(2026, 3, 22),
      );

      final modified = original.copyWith(title: 'Modified');

      expect(modified.id, original.id);
      expect(modified.title, 'Modified');
      expect(original.title, 'Original');
    });

    test('fromJson handles null optional fields', () {
      final session = ChatSession.fromJson({
        'id': 'null-test',
        'title': 'Test',
        'createdAt': DateTime.now().toIso8601String(),
        'lastUpdated': DateTime.now().toIso8601String(),
        'messages': null,
        'recipientId': null,
        'profileImageBase64': null,
        'lastConnected': null,
        'peerName': null,
        'peerUuid': null,
      });

      expect(session.messages, isEmpty);
      expect(session.peerName, isNull);
      expect(session.lastConnected, isNull);
    });
  });
}
