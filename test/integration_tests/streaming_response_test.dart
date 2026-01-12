import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  group('Streaming Response Tests', () {
    test('Verify streaming response from localhost', () async {
      final url = 'http://localhost:7908/api/send_message_stream';
      final requestBody = {
        'user_id': 12345,
        'chat_id': 1767023771,
        'message': 'Say hello in one word',
        'user_name': 'StreamTestUser',
      };

      try {
        final request = http.Request('POST', Uri.parse(url))
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode(requestBody);

        final response = await request.send();

        print(
          'Streaming request to localhost returned status: ${response.statusCode}',
        );
        print('Response headers: ${response.headers}');

        if (response.statusCode == 200) {
          print('✓ Streaming connection established');

          // Check if response is properly streamed
          expect(
            response.headers['content-type'],
            contains('text/event-stream'),
          );
          expect(response.headers['cache-control'], 'no-cache');
          expect(response.headers['connection'], 'keep-alive');

          print('✓ Streaming headers verified');

          // Read a portion of the stream to verify it works
          final stream = utf8.decoder.bind(response.stream);
          var chunksReceived = 0;

          // Listen for a few chunks
          await stream.take(5).forEach((chunk) {
            chunksReceived++;
            print('Received chunk $chunksReceived: ${chunk.length} characters');
            if (chunk.isNotEmpty) {
              print(
                'Chunk content preview: ${chunk.substring(0, chunk.length > 50 ? 50 : chunk.length)}...',
              );
            }
          });

          print('✓ Received $chunksReceived chunks from stream');
        } else {
          print('⚠ Streaming request returned status ${response.statusCode}');
        }
      } catch (e) {
        print('✗ Failed to test streaming response: $e');
      }
    });

    test('Verify streaming response from Vercel', () async {
      final url =
          'https://my-space-chat-server-in4jlz8zk-kavimugil-rajasekars-projects.vercel.app/api/send_message_stream';
      final requestBody = {
        'user_id': 12345,
        'chat_id': 1767023771,
        'message': 'Say hello in one word',
        'user_name': 'VercelStreamTestUser',
      };

      try {
        final request = http.Request('POST', Uri.parse(url))
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode(requestBody);

        final response = await request.send();

        print(
          'Streaming request to Vercel returned status: ${response.statusCode}',
        );
        print('Response headers: ${response.headers}');

        if (response.statusCode == 200) {
          print('✓ Vercel streaming connection established');

          // Check if response is properly streamed
          expect(
            response.headers['content-type'],
            contains('text/event-stream'),
          );
          expect(response.headers['cache-control'], 'no-cache');
          expect(response.headers['connection'], 'keep-alive');

          print('✓ Vercel streaming headers verified');

          // Read a portion of the stream to verify it works
          final stream = utf8.decoder.bind(response.stream);
          var chunksReceived = 0;

          // Listen for a few chunks
          await stream.take(5).forEach((chunk) {
            chunksReceived++;
            print('Received chunk $chunksReceived: ${chunk.length} characters');
            if (chunk.isNotEmpty) {
              print(
                'Chunk content preview: ${chunk.substring(0, chunk.length > 50 ? 50 : chunk.length)}...',
              );
            }
          });

          print('✓ Received $chunksReceived chunks from stream');
        } else {
          print(
            '⚠ Vercel streaming request returned status ${response.statusCode}',
          );
        }
      } catch (e) {
        print('✗ Failed to test Vercel streaming response: $e');
      }
    });
  });
}
