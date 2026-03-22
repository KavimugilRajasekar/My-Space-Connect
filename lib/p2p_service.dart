import 'dart:convert';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

enum P2PStatus { idle, advertising, discovering, connected }

class P2PService {
  final Strategy strategy = Strategy.P2P_STAR;
  final String serviceId = "com.myspace.chat";
  
  Map<String, ConnectionInfo> endpointMap = {};
  P2PStatus status = P2PStatus.idle;
  
  // Callbacks for UI
  Function(String endpointId, ConnectionInfo info)? onConnectionInitiated;
  Function(String endpointId)? onConnectionResult;
  Function(String endpointId)? onDisconnected;
  Function(String endpointId, Payload payload)? onPayloadReceived;
  Function(String endpointId, PayloadTransferUpdate update)? onPayloadTransferUpdate;
  Function(String endpointId, String name)? onEndpointFound;
  Function(String endpointId)? onEndpointLost;

  Future<bool> checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
    ].request();
    
    return statuses.values.every((status) => status.isGranted);
  }

  Future<void> startAdvertising(String userName) async {
    try {
      bool granted = await checkPermissions();
      if (!granted) return;

      await Nearby().startAdvertising(
        userName,
        strategy,
        onConnectionInitiated: (id, info) {
          endpointMap[id] = info;
          if (onConnectionInitiated != null) onConnectionInitiated!(id, info);
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            if (onConnectionResult != null) onConnectionResult!(id);
          } else {
            endpointMap.remove(id);
          }
        },
        onDisconnected: (id) {
          endpointMap.remove(id);
          if (onDisconnected != null) onDisconnected!(id);
        },
        serviceId: serviceId,
      );
      status = P2PStatus.advertising;
    } catch (e) {
      print("Error starting advertising: $e");
    }
  }

  Future<void> startDiscovery(String userName) async {
    try {
      bool granted = await checkPermissions();
      if (!granted) return;

      await Nearby().startDiscovery(
        userName,
        strategy,
        onEndpointFound: (id, name, serviceId) {
          if (onEndpointFound != null) onEndpointFound!(id, name);
        },
        onEndpointLost: (id) {
          if (onEndpointLost != null) onEndpointLost!(id!);
        },
        serviceId: serviceId,
      );
      status = P2PStatus.discovering;
    } catch (e) {
      print("Error starting discovery: $e");
    }
  }

  Future<void> connectToDevice(String userName, String endpointId) async {
    try {
      await Nearby().requestConnection(
        userName,
        endpointId,
        onConnectionInitiated: (id, info) {
          endpointMap[id] = info;
          if (onConnectionInitiated != null) onConnectionInitiated!(id, info);
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            if (onConnectionResult != null) onConnectionResult!(id);
          } else {
            endpointMap.remove(id);
          }
        },
        onDisconnected: (id) {
          endpointMap.remove(id);
          if (onDisconnected != null) onDisconnected!(id);
        },
      );
    } catch (e) {
      print("Error requesting connection: $e");
    }
  }

  Future<void> acceptConnection(String endpointId) async {
    await Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: (id, payload) {
        if (onPayloadReceived != null) onPayloadReceived!(id, payload);
      },
      onPayloadTransferUpdate: (id, update) {
        if (onPayloadTransferUpdate != null) onPayloadTransferUpdate!(id, update);
      },
    );
  }

  Future<void> stopAll() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    endpointMap.clear();
    status = P2PStatus.idle;
  }

  Future<void> sendMessage(String endpointId, Map<String, dynamic> data) async {
    String jsonString = jsonEncode(data);
    await Nearby().sendBytesPayload(endpointId, Uint8List.fromList(utf8.encode(jsonString)));
  }

  Future<void> sendFile(String endpointId, String filePath) async {
    await Nearby().sendFilePayload(endpointId, filePath);
  }
}
