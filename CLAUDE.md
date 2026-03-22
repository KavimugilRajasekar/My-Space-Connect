# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MySpace Connect is a Flutter P2P offline communication app — messaging, voice/video calls, and file sharing over Wi-Fi/Bluetooth mesh without internet. It uses `nearby_connections` for device discovery and `flutter_webrtc` for media streaming.

## Commands

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Analyze code
flutter analyze

# Run tests
flutter test

# Generate Hive type adapters (after modifying models.dart)
flutter pub run build_runner build

# Regenerate Hive adapters (if build_runner cache issues)
flutter pub run build_runner build --delete-conflicting-outputs
```

## Architecture

### App Flow
1. `main.dart` → `MyApp` → checks `user_name_saved` in SharedPreferences
2. If not saved → `AuthScreen` (enter name, generates UUID via `uuid` package)
3. If saved → `SplashScreen` (Lottie animation + optional biometric auth via `local_auth`)
4. After splash → `MySpaceScreen` (main chat interface)

### Core Services
- **P2P** (`p2p_service.dart`): Wraps `nearby_connections` with P2P_STAR strategy. Service ID: `com.myspace.chat`. Handles advertising, discovery, connection, and bytepayload messaging.
- **WebRTC** (`webrtc_service.dart`): Peer connection with STUN server (stun.l.google.com:19302). Handles offer/answer/candidate signaling via `onSignalingMessage` callback.

### Data Layer
- **Hive** (`models.dart`): `Message` (typeId: 0) and `ChatSession` (typeId: 1) models with generated adapters in `models.g.dart`. Chat sessions stored in `chat_sessions` box.
- **SharedPreferences**: User settings — `user_name`, `user_uid`, `user_name_saved`, `biometric_enabled`, `voice_to_speech_enabled`, `profile_image_path`.

### QR Pairing
- **Encoding** (`qr_popup.dart`): JSON payload `{name, uuid, profileImage}` → XOR encrypted with hardcoded key → hex string → PrettyQrView
- **Decoding** (`qr_scanner.dart`): Scan → hex decode → XOR decrypt → JSON parse → extract UUID
- Self-scan prevention: compares scanned UUID against `user_uid` from SharedPreferences

### Key Implementation Notes
- `pubspec.yaml` SDK constraint: `^3.9.2`
- Custom fonts: **Comfortaa** (primary, weights 300-700) and **PlaywriteUSModern** (weights 100-400)
- Asset directories: `assets/icons/`, `assets/bg/`, `assets/json/`
- App ID/channel: `com.example.my_space_connect/widget`
- Biometric auth is **fingerprint-only** (`biometricOnly: true`) — no PIN/pattern fallback
- `permission_handler` used for camera, bluetooth, location, storage permissions

## File Map

```
lib/
├── main.dart              # App entry, MyApp, MySpaceApp, MySpaceScreen (main UI)
├── models.dart            # Message & ChatSession Hive models
├── models.g.dart          # Generated Hive adapters (do not edit manually)
├── p2p_service.dart       # Nearby Connections wrapper (advertise/discover/connect/send)
├── webrtc_service.dart   # WebRTC peer connection (createOffer/handleSignal)
├── splash_screen.dart     # Lottie splash + biometric auth
├── auth_screen.dart       # First-time name setup, UUID generation
├── profile.dart           # Profile page, settings, statistics, logout
├── qr_scanner.dart        # Camera QR scanner with XOR decryption
└── widgets/
    └── qr_popup.dart      # QR code generator dialog with XOR encryption + share/save
```
