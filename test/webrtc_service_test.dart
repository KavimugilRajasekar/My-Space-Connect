import 'package:flutter_test/flutter_test.dart';
import 'package:my_space_connect/webrtc_service.dart';

void main() {
  group('WebRTCService', () {
    test('creates WebRTCService instance', () {
      final service = WebRTCService();
      expect(service, isA<WebRTCService>());
    });

    test('onSignalingMessage callback can be set', () {
      final service = WebRTCService();

      void handler(Map<String, dynamic> signal) {}

      service.onSignalingMessage = handler;
      expect(service.onSignalingMessage, isNotNull);
    });

    test('onRemoteStream callback can be set', () {
      final service = WebRTCService();

      void handler(dynamic stream) {}

      service.onRemoteStream = handler;
      expect(service.onRemoteStream, isNotNull);
    });

    test('has localRenderer and remoteRenderer', () {
      final service = WebRTCService();
      expect(service.localRenderer, isNotNull);
      expect(service.remoteRenderer, isNotNull);
    });

    test('dispose can be called safely', () {
      final service = WebRTCService();
      expect(() => service.dispose(), returnsNormally);
    });
  });
}
