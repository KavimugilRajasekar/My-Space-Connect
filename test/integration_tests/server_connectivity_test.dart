import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  group('Server Connectivity Tests', () {
    // Test with localhost
    test('Health check to localhost server', () async {
      final urls = [
        'http://localhost:7908/health',
        'http://localhost:7908/api/health',
      ];

      for (final url in urls) {
        try {
          final response = await http.get(Uri.parse(url));
          print('Health check to $url returned status: ${response.statusCode}');

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            expect(data['status'], 'OK');
            print('✓ Health check passed for $url');
          } else {
            print(
              '⚠ Health check to $url returned status ${response.statusCode}',
            );
          }
        } catch (e) {
          print('✗ Health check to $url failed: $e');
        }
      }
    });

    test('Server info from localhost', () async {
      try {
        final response = await http.get(
          Uri.parse('http://localhost:7908/api/server-info'),
        );
        print('Server info request returned status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          expect(data.containsKey('url'), true);
          print('✓ Server info retrieved successfully');
          print('Server URL: ${data['url']}');
        } else {
          print('⚠ Server info request returned status ${response.statusCode}');
        }
      } catch (e) {
        print('✗ Server info request failed: $e');
      }
    });

    test('Metrics endpoint from localhost', () async {
      try {
        final response = await http.get(
          Uri.parse('http://localhost:7908/api/metrics'),
        );
        print('Metrics request returned status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          expect(data.containsKey('activeSessions'), true);
          expect(data.containsKey('totalRequests'), true);
          print('✓ Metrics retrieved successfully');
          print('Active sessions: ${data['activeSessions']}');
          print('Total requests: ${data['totalRequests']}');
        } else {
          print('⚠ Metrics request returned status ${response.statusCode}');
        }
      } catch (e) {
        print('✗ Metrics request failed: $e');
      }
    });

    // Test with Vercel deployed URL
    test('Health check to Vercel deployed server', () async {
      final urls = [
        'https://my-space-chat-server-in4jlz8zk-kavimugil-rajasekars-projects.vercel.app/health',
        'https://my-space-chat-server-in4jlz8zk-kavimugil-rajasekars-projects.vercel.app/api/health',
      ];

      for (final url in urls) {
        try {
          final response = await http.get(Uri.parse(url));
          print(
            'Vercel health check to $url returned status: ${response.statusCode}',
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            expect(data['status'], 'OK');
            print('✓ Vercel health check passed for $url');
          } else {
            print(
              '⚠ Vercel health check to $url returned status ${response.statusCode}',
            );
          }
        } catch (e) {
          print('✗ Vercel health check to $url failed: $e');
        }
      }
    });

    test('Server info from Vercel deployed server', () async {
      try {
        final response = await http.get(
          Uri.parse(
            'https://my-space-chat-server-in4jlz8zk-kavimugil-rajasekars-projects.vercel.app/api/server-info',
          ),
        );
        print(
          'Vercel server info request returned status: ${response.statusCode}',
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          expect(data.containsKey('url'), true);
          print('✓ Vercel server info retrieved successfully');
          print('Server URL: ${data['url']}');
        } else {
          print(
            '⚠ Vercel server info request returned status ${response.statusCode}',
          );
        }
      } catch (e) {
        print('✗ Vercel server info request failed: $e');
      }
    });

    test('Server info from ngrok forwarded server', () async {
      try {
        final response = await http.get(
          Uri.parse(
            'https://lennon-prosecutable-angelica.ngrok-free.dev/api/server-info',
          ),
        );
        print(
          'Ngrok server info request returned status: ${response.statusCode}',
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          expect(data.containsKey('url'), true);
          print('✓ Ngrok server info retrieved successfully');
          print('Server URL: ${data['url']}');
        } else {
          print(
            '⚠ Ngrok server info request returned status ${response.statusCode}',
          );
        }
      } catch (e) {
        print('✗ Ngrok server info request failed: $e');
      }
    });
  });
}
