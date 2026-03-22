import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_space_connect/p2p_service.dart';
import 'package:nearby_connections/nearby_connections.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P2PService', () {
    test('initial status is idle', () {
      final service = P2PService();
      expect(service.status, P2PStatus.idle);
    });

    test('service ID is correctly set', () {
      final service = P2PService();
      expect(service.serviceId, 'com.myspace.chat');
    });

    test('strategy is P2P_STAR', () {
      final service = P2PService();
      expect(service.strategy, Strategy.P2P_STAR);
    });

    test('endpoint map starts empty', () {
      final service = P2PService();
      expect(service.endpointMap, isEmpty);
    });

    test('P2PStatus enum has correct values', () {
      expect(P2PStatus.values, contains(P2PStatus.idle));
      expect(P2PStatus.values, contains(P2PStatus.advertising));
      expect(P2PStatus.values, contains(P2PStatus.discovering));
      expect(P2PStatus.values, contains(P2PStatus.connected));
    });

    test('callbacks can be assigned', () {
      final service = P2PService();

      void onConnection(String id, ConnectionInfo info) {}
      void onResult(String id) {}
      void onDisconnect(String id) {}
      void onPayload(String id, Payload payload) {}
      void onTransferUpdate(String id, PayloadTransferUpdate update) {}
      void onFound(String id, String name) {}
      void onLost(String id) {}

      service.onConnectionInitiated = onConnection;
      service.onConnectionResult = onResult;
      service.onDisconnected = onDisconnect;
      service.onPayloadReceived = onPayload;
      service.onPayloadTransferUpdate = onTransferUpdate;
      service.onEndpointFound = onFound;
      service.onEndpointLost = onLost;

      expect(service.onConnectionInitiated, isNotNull);
      expect(service.onConnectionResult, isNotNull);
      expect(service.onDisconnected, isNotNull);
      expect(service.onPayloadReceived, isNotNull);
      expect(service.onPayloadTransferUpdate, isNotNull);
      expect(service.onEndpointFound, isNotNull);
      expect(service.onEndpointLost, isNotNull);
    });
  });
}
