# MyChatConnect

A Flutter-based real-time chat application that enables secure messaging between users through a dedicated server backend. The app features email authentication with OTP verification, profile management with biometric security, QR code scanning for server discovery, and both voice and text messaging capabilities.

## 🌟 Key Features

- **Secure Authentication**: Email registration and login with OTP (One-Time Password) verification
- **Real-time Messaging**: Instant messaging between users powered by Socket.IO
- **Voice Communication**: Voice message recording and playback functionality
- **Speech-to-Text**: Convert spoken words to text for easier messaging
- **Biometric Security**: Fingerprint and Face ID authentication for enhanced security
- **QR Code Integration**: Scan QR codes for quick server connection setup
- **Profile Management**: Customizable user profiles with profile pictures
- **Push Notifications**: Real-time notifications for new messages
- **Persistent Storage**: Local message history and user preferences
- **Multi-session Support**: Manage multiple chat conversations simultaneously

## 🛠️ Technical Architecture

### Frontend (Flutter Client)
- **Framework**: Flutter SDK (version 3.9.2 or higher)
- **Language**: Dart
- **State Management**: Built-in Flutter state management
- **Networking**: HTTP and Socket.IO for real-time communication
- **Storage**: Shared Preferences for local data persistence
- **Audio**: Flutter Sound for voice recording/playback
- **Security**: Local Auth for biometric authentication
- **UI Components**: Custom-designed widgets with themed components

### Backend (Node.js Server)
- **Runtime**: Node.js with Express.js framework
- **Database**: MongoDB Atlas for persistent data storage
- **Authentication**: JWT (JSON Web Tokens) for session management
- **Real-time Communication**: Socket.IO for instant messaging
- **Email Services**: Nodemailer for OTP delivery
- **Security**: Bcrypt for password hashing, Speakeasy for OTP generation
- **Monitoring**: Custom-built API monitoring dashboard

## 📱 Prerequisites

- Flutter SDK (version 3.9.2 or higher)
- Dart SDK
- Android Studio or VS Code with Flutter extensions
- Compatible mobile device or emulator (Android/iOS)

## 🚀 Getting Started

1. **Clone the Repository**
   ```bash
   git clone <repository-url>
   cd mychatconnect
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure the Application**
   The application connects to a server backend. By default, it uses a deployed server URL. You can customize this by setting environment variables:
   
   ```bash
   # Set custom API URL
   flutter run --dart-define=API_URL=https://your-deployed-server-url.com
   
   # For local development, connect to:
   flutter run --dart-define=API_URL=http://localhost:7908
   
   # Set custom chat ID (default: 1767023771)
   flutter run --dart-define=CHAT_ID=your-chat-id
   ```

4. **Connect Device**
   Connect an Android or iOS device, or start an emulator

5. **Run the Application**
   ```bash
   flutter run
   ```

## 🔐 Authentication Flow

1. **Registration**: Users can register with email and password
2. **Login**: Existing users sign in with credentials
3. **OTP Verification**: After credential validation, a 6-digit OTP is sent to the user's email
4. **Session Management**: Upon successful OTP verification, a JWT token is issued for authenticated sessions
5. **Biometric Security**: Optional fingerprint/Face ID authentication for enhanced security

## 💬 Messaging Features

- **Text Messaging**: Send and receive text messages in real-time
- **Voice Messages**: Record and send voice messages with playback capability
- **Speech-to-Text**: Convert voice messages to text automatically
- **Image Sharing**: Send images between users
- **Message Persistence**: All messages are stored in MongoDB Atlas and persist between server restarts
- **Delivery Confirmation**: Visual indicators for message delivery status
- **Read Receipts**: Track when messages have been read by recipients

## 📷 QR Code Connection

1. **First Launch**: Scan the QR code displayed by the server to establish connection
2. **Security**: QR codes contain server URL encoded with XOR cipher for security
3. **Automatic Connection**: After scanning, the app automatically connects to the server
4. **Reconnection**: Easily reconnect by scanning the server's QR code again

## 🗂️ Project Structure

```
lib/
├── main.dart          # Main application with chat interface
├── profile.dart       # User profile management with biometric security
├── splash_screen.dart # Animated splash screen with biometric authentication
├── qr_scanner.dart    # QR code scanner implementation
├── auth_screen.dart   # Email authentication with OTP verification
├── config.dart        # Application configuration settings
└── widgets/
    └── qr_popup.dart  # Custom QR popup with encrypted email and profile image

assets/
├── icons/             # Application icons
├── json/              # Lottie animations
├── bg/                # Background images
└── fonts/             # Custom fonts (Comfortaa and PlaywriteUSModern)
```

## 📦 Core Dependencies

| Category | Package | Purpose |
|---------|---------|---------|
| Networking | `http`, `socket_io_client` | API communication and real-time messaging |
| Storage | `shared_preferences` | Local data storage |
| Audio | `flutter_sound`, `speech_to_text` | Voice recording/playback and speech recognition |
| Security | `local_auth` | Biometric authentication |
| UI/UX | `lottie`, `qr_code_scanner_plus`, `qr_flutter` | Animations and QR code functionality |
| Media | `image_picker`, `flutter_image_compress` | Profile images and media handling |
| Utilities | `device_info_plus`, `path_provider`, `permission_handler` | Device information and permissions |

## 🔐 Security Features

- **End-to-End Encryption**: Messages are secured during transmission
- **Password Hashing**: Bcrypt encryption for user passwords
- **JWT Authentication**: Token-based session management
- **Biometric Protection**: Fingerprint/Face ID for app access
- **OTP Verification**: Two-factor authentication for login
- **QR Code Security**: XOR cipher encoding for server connection

## 🎨 UI/UX Features

- **Custom Themes**: Monochromatic design with black, white, and gray tones
- **Responsive Design**: Adapts to different screen sizes
- **Animated Transitions**: Smooth page transitions and interactive elements
- **Accessibility**: Support for screen readers and accessibility features
- **Intuitive Navigation**: User-friendly interface with clear navigation

## 📱 Permissions Required

- **Microphone**: For voice messages and speech recognition
- **Storage**: For saving audio recordings and images
- **Camera**: For QR code scanning and profile pictures
- **Biometric**: For fingerprint/Face ID authentication

## 🔧 Configuration

### Environment Variables
The application can be customized using the following environment variables:
- `API_URL`: Custom server URL (default: deployed server)
- `CHAT_ID`: Custom chat identifier (default: 1767023771)

### Application Settings
- Biometric security can be enabled/disabled in profile settings
- Voice-to-speech can be toggled on/off
- Notification preferences are configurable
- Theme customization options available

## 🔄 Biometric Security

- **Supported Platforms**: Fingerprint authentication on Android, Face ID/Touch ID on iOS
- **Configuration**: Toggle biometric security in profile settings
- **Cooldown Period**: Security cooldown between authentication attempts
- **Fallback**: PIN/password fallback when biometrics fail

## 💬 Chat Session Management

- **Create Sessions**: Start new chat conversations with other users
- **Switch Chats**: Easily navigate between multiple active chats
- **Rename Sessions**: Customize chat names for better organization
- **Delete Chats**: Remove unwanted conversations
- **History Persistence**: All chat history is stored locally and on the server

## 📊 Monitoring & Analytics

- **Connection Status**: Real-time display of server connectivity
- **Performance Metrics**: Track app performance and responsiveness
- **Error Reporting**: Automatic error reporting for debugging
- **Usage Statistics**: Anonymous usage analytics for improvement

## 🛠️ Development Workflow

1. **Code Structure**: Modular architecture with separation of concerns
2. **State Management**: Efficient state handling with Flutter's built-in solutions
3. **Testing**: Widget and integration tests for quality assurance
4. **Debugging**: Comprehensive logging and debugging tools
5. **Deployment**: Ready for both development and production environments

## 🤝 Contributing

We welcome contributions to improve MyChatConnect! Here's how you can help:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

Please ensure your code follows our coding standards and includes appropriate tests.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Flutter community for the excellent framework
- Lottie for animation assets
- All open-source contributors whose packages made this project possible
- MongoDB Atlas for reliable database services
- All developers who contributed to the various packages used in this project

## 🆘 Support

For issues, questions, or feature requests, please:
1. Check the existing issues in the repository
2. Create a new issue with detailed information
3. Contact the development team through the official channels

---

*MyChatConnect - Secure, Real-time Communication Made Simple*