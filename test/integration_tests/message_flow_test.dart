import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  group('Message Flow Tests', () {
    test('Send message to localhost server', () async {
      final url = 'http://localhost:7908/api/send_message_stream';
      final requestBody = {
        'user_id': 12345,
        'chat_id': 1767023771,
        'message': 'Hello, how are you?',
        'user_name': 'TestUser',
      };

      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        );

        print(
          'Message send to localhost returned status: ${response.statusCode}',
        );
        if (response.statusCode == 200) {
          print('✓ Successfully sent message to localhost server');
          print('Response headers: ${response.headers}');
          // Note: We won't print the full response body as it's a stream
        } else {
          print(
            '⚠ Message send to localhost returned status ${response.statusCode}',
          );
        }
      } catch (e) {
        print('✗ Failed to send message to localhost server: $e');
      }
    });

    test('Send message to Vercel deployed server', () async {
      final url =
          'https://my-space-chat-server-in4jlz8zk-kavimugil-rajasekars-projects.vercel.app/api/send_message_stream';
      final requestBody = {
        'user_id': 12345,
        'chat_id': 1767023771,
        'message': 'Hello from Vercel test',
        'user_name': 'VercelTestUser',
      };

      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        );

        print('Message send to Vercel returned status: ${response.statusCode}');
        if (response.statusCode == 200) {
          print('✓ Successfully sent message to Vercel server');
          print('Response headers: ${response.headers}');
        } else {
          print(
            '⚠ Message send to Vercel returned status ${response.statusCode}',
          );
          print('Response body: ${response.body}');
        }
      } catch (e) {
        print('✗ Failed to send message to Vercel server: $e');
      }
    });

    test('Send message to ngrok forwarded server', () async {
      final url =
          'https://lennon-prosecutable-angelica.ngrok-free.dev/api/send_message_stream';
      final requestBody = {
        'user_id': 12345,
        'chat_id': 1767023771,
        'message': 'Hello from ngrok test',
        'user_name': 'NgrokTestUser',
      };

      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        );

        print('Message send to ngrok returned status: ${response.statusCode}');
        if (response.statusCode == 200) {
          print('✓ Successfully sent message to ngrok server');
          print('Response headers: ${response.headers}');
        } else {
          print(
            '⚠ Message send to ngrok returned status ${response.statusCode}',
          );
          print('Response body: ${response.body}');
        }
      } catch (e) {
        print('✗ Failed to send message to ngrok server: $e');
      }
    });

    test('Test original generate endpoint', () async {
      final url = 'http://localhost:7908/api/generate';
      final requestBody = {
        'prompt': 'Hello, how are you?',
        'model': 'gemma3:1b',
      };

      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        );

        print(
          'Generate request to localhost returned status: ${response.statusCode}',
        );
        if (response.statusCode == 200) {
          print('✓ Successfully called generate endpoint');
          print('Response headers: ${response.headers}');
        } else {
          print('⚠ Generate request returned status ${response.statusCode}');
          print('Response body: ${response.body}');
        }
      } catch (e) {
        print('✗ Failed to call generate endpoint: $e');
      }
    });

    test('Test events endpoint', () async {
      final url = 'http://localhost:7908/api/get_events';

      try {
        final response = await http.get(Uri.parse(url));
        print('Events request returned status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          expect(data.containsKey('status'), true);
          print('✓ Events endpoint working');
          print('Events status: ${data['status']}');
        } else {
          print('⚠ Events request returned status ${response.statusCode}');
        }
      } catch (e) {
        print('✗ Events request failed: $e');
      }
    });
  });
}
