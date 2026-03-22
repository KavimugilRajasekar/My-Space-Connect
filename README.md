# MySpace Connect

A fully autonomous, peer-to-peer (P2P) offline communication platform built with Flutter. Enable secure messaging, file sharing, and voice/video calling over a decentralized mesh network without internet or servers.

---

## Key Features

- **Pure P2P Mesh Networking** — Communicate directly with nearby devices using Wi-Fi and Bluetooth via Google's *Nearby Connections* API (P2P_STAR strategy)
- **WebRTC Calling** — High-quality, peer-to-peer voice and video calls with STUN-based signaling
- **Offline Identity** — Device identity managed entirely on-device using UUID — zero server-side registration
- **QR-Based Pairing** — Securely link with peers by scanning XOR-encrypted QR codes containing device signatures
- **Biometric Security** — Optional fingerprint authentication (fingerprint-only, no PIN/pattern fallback)
- **Voice-to-Speech** — Integrated speech-to-text transcription for voice messages, processed on-device
- **Audio Messaging** — Record and send voice audio messages using flutter_sound
- **Local Storage** — All chat history stored in a local Hive NoSQL database
- **Share & Save** — Export QR codes as images or share directly to other apps
- **Instant Access** — Biometric unlock with zero cooldown and optimized splash transitions

---

## Technical Architecture

### Core Technologies
| Component | Technology |
|-----------|------------|
| Framework | Flutter (Dart) |
| Local Database | Hive (NoSQL) |
| P2P Transport | `nearby_connections` (Wi-Fi/Bluetooth Mesh) |
| Media Streaming | `flutter_webrtc` (P2P Audio/Video) |
| Biometrics | `local_auth` (Fingerprint-only) |
| Speech Recognition | `speech_to_text` |
| Audio Recording | `flutter_sound` |
| Storage | `shared_preferences` (Settings) |

### Project Structure
```
lib/
├── main.dart           # App entry, splash, auth, MySpaceScreen
├── models.dart         # Message & ChatSession Hive models
├── models.g.dart       # Generated Hive type adapters
├── p2p_service.dart    # Nearby Connections wrapper
├── webrtc_service.dart # WebRTC peer connection & signaling
├── splash_screen.dart  # Lottie splash + biometric gateway
├── auth_screen.dart    # Local identity setup
├── profile.dart        # Profile & settings management
├── qr_scanner.dart     # QR code scanner with XOR decryption
└── widgets/
    └── qr_popup.dart   # QR code generator with XOR encryption
```

---

## Prerequisites

- Flutter SDK 3.10.0+
- Android Studio or VS Code with Flutter extensions
- Physical mobile devices (P2P features require real Wi-Fi/Bluetooth hardware)

---

## Getting Started

1. **Clone the Repository**
   ```bash
   git clone <repository-url>
   cd my-space-connect
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the Application**
   ```bash
   flutter run
   ```

---

## Privacy & Security

MySpace Connect is designed with a **Privacy-First** philosophy:

1. **Zero Data Leakage** — Messages and metadata never leave your local mesh network
2. **Encrypted Identity** — Peer IDs and QR data are XOR-encrypted on-device
3. **Local-Only Vault** — All chat history stored in Hive, protected by optional biometric authentication
4. **No Servers** — No central point of failure or surveillance

---

## Connection Indicators

The app bar features a real-time connection status indicator:
- 🟢 **Green** — Active P2P connection with current peer
- ⚪ **Grey** — Peer out of range or disconnected

---

## Permissions Required

The app requests the following permissions:
- **Location** — Required for Wi-Fi/Bluetooth discovery on Android
- **Bluetooth** — For P2P device discovery
- **Camera** — For QR code scanning
- **Microphone** — For voice/video calls and audio messages
- **Storage** — For profile images and QR export
- **Biometrics** — For fingerprint authentication

---

## App Flow

1. **Splash Screen** — Lottie animation plays; if biometric security is enabled, fingerprint is required
2. **Auth Screen** — First-time users enter their display name to generate a unique device UUID
3. **Main Screen** — View chat sessions, discover peers, start new conversations
4. **Profile** — Manage name, profile image, fingerprint security, voice-to-speech settings, and view statistics

---

## Dependencies

```yaml
# Core
flutter_webrtc: any
nearby_connections: any
hive: any
hive_flutter: any
shared_preferences: any

# Audio & Speech
flutter_sound: ^9.8.0
speech_to_text: ^7.0.0

# Security
local_auth: ^3.0.0

# QR Codes
qr_code_scanner_plus: ^2.0.13
qr_flutter: ^4.1.0
pretty_qr_code: ^3.3.0

# UI & Media
lottie: ^3.3.2
image_picker: ^1.0.4
flutter_image_compress: ^2.3.0

# Utilities
uuid: any
path_provider: ^2.1.5
permission_handler: ^11.3.1
share_plus: ^12.0.1
flutter_local_notifications: ^18.0.0
device_info_plus: ^10.1.0
google_sign_in: ^6.2.1
```

---

*MySpace Connect — Secure, Sovereign, and Serverless Communication.*
