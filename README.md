# MySpace Connect 🚀

**MySpace Connect** is a revolutionary, fully autonomous, peer-to-peer (P2P) communication platform. Built with Flutter, it operates entirely offline, enabling secure messaging, file sharing, and voice/video calling over a decentralized mesh network. No servers, no backend, no internet required.

---

## 🌟 Key Features

- **Pure P2P Mesh Networking**: Communicate directly with nearby devices using Wi-Fi and Bluetooth via Google's *Nearby Connections*.
- **WebRTC Calling**: High-quality, peer-to-peer voice and video calls with decentralized signaling.
- **Offline Identity**: Your identity is yours alone. Managed entirely on-device using secure UUIDs—zero server-side registration.
- **QR-Based Pairing**: Securely link with peers by scanning encrypted QR codes containing unique device signatures.
- **Fingerprint Security**: Mandatory biometric protection (Fingerprint-only) for ultimate local privacy.
- **QuerySpace AI**: A built-in, local-only assistant to guide you through the P2P mesh and answer app-related queries gracefully.
- **Voice-to-Speech**: Integrated transcription for voice messages, processed entirely on your device.
- **Instant Access**: Zero-cooldown biometric unlock and optimized splash transitions for a lightning-fast experience.

---

## 🛠️ Technical Architecture

### Core Technologies
- **Framework**: Flutter (Dart)
- **Local Database**: Hive (NoSQL, lightning-fast local persistence)
- **P2P Transport**: `nearby_connections` (Wi-Fi/Bluetooth Mesh)
- **Media Streaming**: `flutter_webrtc` (P2P Audio/Video)
- **Biometrics**: `local_auth` (Fingerprint specialized)
- **Storage**: `shared_preferences` (User settings & preferences)

---

## 📱 Prerequisites

- Flutter SDK (version 3.10.0 or higher)
- Android Studio or VS Code with Flutter extensions
- Physical mobile devices (P2P features require real Wi-Fi/Bluetooth hardware)

---

## 🚀 Getting Started

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

## 🔐 Privacy & Security

MySpace Connect is designed with a **Privacy-First** philosophy:
1. **Zero Data Leakage**: Your messages and metadata never leave your local mesh network.
2. **Encrypted Identity**: Peer IDs and QR data are encrypted on-device.
3. **Local-Only Vault**: All chat history is stored in a local Hive vault, protected by biometric authentication.
4. **No Servers**: There is no central point of failure or surveillance.

---

## 🗂️ Project Structure

```
lib/
├── main.dart          # Core P2P Chat Logic & UI
├── p2p_service.dart   # Nearby Connections Mesh Wrapper
├── webrtc_service.dart# P2P Calling & Signaling Logic
├── models.dart        # Decentralized Data Models (Message, Session)
├── profile.dart       # Local Identity & Fingerprint Settings
├── splash_screen.dart # Optimized Biometric Gateway
├── qr_scanner.dart    # Encrypted Peer Discovery
├── auth_screen.dart   # Local Identity Setup (Name & QR)
└── widgets/
    └── qr_popup.dart  # Encrypted Identity Broadcaster
```

---

## 📊 Connection Indicators

The `AppBar` features a real-time connection status indicator:
- **Radio Button (Large)**: Indicates your current P2P reachability.
- **Colors**:
  - 🟢 **Green**: Active P2P connection with the current peer.
  - ⚪ **Grey**: Peer is out of range or disconnected.
  - 🤖 **Always Green**: In QuerySpace (Local Assistant).

---

## 👋 Support & Community

Since this is a decentralized project, the "server" is you! 
- Use **QuerySpace** within the app for instant help.
- Open an issue for P2P protocol improvements or bug reports.

*MySpace Connect - Secure, Sovereign, and Serverless Communication.*