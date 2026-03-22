import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  // Signaling callback
  Function(Map<String, dynamic> signal)? onSignalingMessage;
  Function(MediaStream stream)? onRemoteStream;

  Future<void> initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  void dispose() {
    localRenderer.dispose();
    remoteRenderer.dispose();
    _localStream?.dispose();
    _peerConnection?.dispose();
  }

  Future<void> initPeerConnection() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"},
      ]
    };

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": [],
    };

    _peerConnection = await createPeerConnection(configuration, offerSdpConstraints);

    _peerConnection!.onIceCandidate = (candidate) {
      if (onSignalingMessage != null) {
        onSignalingMessage!({
          'type': 'candidate',
          'candidate': candidate.toMap(),
        });
      }
    };

    _peerConnection!.onAddStream = (stream) {
      remoteRenderer.srcObject = stream;
      if (onRemoteStream != null) onRemoteStream!(stream);
    };

    _localStream = await _getUserMedia();
    _peerConnection!.addStream(_localStream!);
    localRenderer.srcObject = _localStream;
  }

  Future<MediaStream> _getUserMedia() async {
    final Map<String, dynamic> constraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
      },
    };
    return await navigator.mediaDevices.getUserMedia(constraints);
  }

  Future<void> createOffer() async {
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    if (onSignalingMessage != null) {
      onSignalingMessage!({
        'type': 'offer',
        'sdp': offer.sdp,
      });
    }
  }

  Future<void> handleSignal(Map<String, dynamic> signal) async {
    String type = signal['type'];
    if (type == 'offer') {
      RTCSessionDescription description = RTCSessionDescription(signal['sdp'], 'offer');
      await _peerConnection!.setRemoteDescription(description);
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      if (onSignalingMessage != null) {
        onSignalingMessage!({
          'type': 'answer',
          'sdp': answer.sdp,
        });
      }
    } else if (type == 'answer') {
      RTCSessionDescription description = RTCSessionDescription(signal['sdp'], 'answer');
      await _peerConnection!.setRemoteDescription(description);
    } else if (type == 'candidate') {
      RTCIceCandidate candidate = RTCIceCandidate(
        signal['candidate']['candidate'],
        signal['candidate']['sdpMid'],
        signal['candidate']['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);
    }
  }
}
