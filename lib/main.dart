import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'profile.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as notifications;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'splash_screen.dart';
import 'qr_scanner.dart';
import 'auth_screen.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'models.dart';
import 'p2p_service.dart';
import 'webrtc_service.dart';

// Method channel for handling Android widget broadcasts
const MethodChannel platform = MethodChannel(
  'com.example.my_space_connect/widget',
);


// QuerySpace chat ID
const String QUERYSPACE_CHAT_ID = 'queryspace_help_chat';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(MessageAdapter());
  Hive.registerAdapter(ChatSessionAdapter());
  
  // Open common boxes
  await Hive.openBox<ChatSession>('chat_sessions');

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showSplash = true;
  bool _initError = false;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Check if user is already authenticated (offline identity)
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('user_name') ?? '';
      final userNameSaved = prefs.getBool('user_name_saved') ?? false;
      
      setState(() {
        _isAuthenticated = userName.isNotEmpty || userNameSaved;
      });
    } catch (e) {
      print('Error during app initialization: $e');
      setState(() {
        _initError = true;
      });
    }
  }

  void _finishSplash() {
    setState(() {
      _showSplash = false;
    });
  }

  void _handleAuthSuccess() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  void _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Clear all user-related data
    await prefs.remove('user_uid');
    await prefs.remove('user_name');
    await prefs.remove('user_name_saved');
    await prefs.remove('profile_image_path');

    // Clear Hive boxes
    await Hive.box<ChatSession>('chat_sessions').clear();

    setState(() {
      _isAuthenticated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return MaterialApp(
        home: SplashScreen(onSplashFinished: _finishSplash),
        debugShowCheckedModeBanner: false,
      );
    }

    if (_initError) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.red, size: 48),
                SizedBox(height: 16),
                Text('Failed to initialize the app'),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _initError = false;
                      _showSplash = true;
                    });
                    _initializeApp();
                  },
                  child: Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show authentication screen if user is not authenticated
    if (!_isAuthenticated) {
      return MaterialApp(
        title: 'My Space',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.yellow, // Changed to yellow accent color
          ),
          // Use custom fonts throughout the app
          fontFamily: 'Comfortaa', // Default font for the app
          // Disable sound effects
          splashFactory: NoSplash.splashFactory,
        ),
        home: AuthScreen(onAuthSuccess: _handleAuthSuccess),
        debugShowCheckedModeBanner: false,
      );
    }

    // Show main app if user is authenticated
    return MySpaceApp(onLogout: _handleLogout);
  }
}

class MySpaceApp extends StatelessWidget {
  final VoidCallback onLogout;

  const MySpaceApp({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Space',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.yellow, // Changed to yellow accent color
        ),
        // Use custom fonts throughout the app
        fontFamily: 'Comfortaa', // Default font for the app
        // Disable sound effects
        splashFactory: NoSplash.splashFactory,
      ),
      home: MySpaceScreen(onLogout: onLogout),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Models moved to models.dart

// Custom circular bot icon widget
class CircularBotIcon extends StatelessWidget {
  final double size;
  final Color backgroundColor;

  const CircularBotIcon({
    super.key,
    this.size = 28.0,
    this.backgroundColor =
        Colors.transparent, // Changed to transparent to avoid covering the icon
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size,
      backgroundColor: backgroundColor,
      child: ClipOval(
        child: Image.asset(
          'assets/icons/mychatconnect.png',
          width: size * 2,
          height: size * 2,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class MySpaceScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const MySpaceScreen({super.key, required this.onLogout});

  @override
  State<MySpaceScreen> createState() => _MySpaceScreenState();
}

class _MySpaceScreenState extends State<MySpaceScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Add WidgetsBindingObserver
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  bool _isLoading = false;
  bool _isConnected = false;

  // User name for context injection
  String _userName = 'User';

  // Saved QR code URL
  String _savedQrUrl = '';

  // Removed processed notification IDs set
  // Set to track processed notification IDs to avoid duplicates
  // final Set<int> _processedNotificationIds = <int>{};

  // Audio recording variables
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _audioPlayer = FlutterSoundPlayer();
  bool _isRecording = false;
  String _audioPath = '';
  bool _isPlaying = false;
  String _currentlyPlayingMessageId = '';

  // Speech to text variables
  late stt.SpeechToText _speechToText;
  bool _isListening = false;
  String _transcribedText = '';

  // Animation variables
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  // API endpoint - now dynamically determined
  final P2PService _p2pService = P2PService();
  final WebRTCService _webrtcService = WebRTCService();
  String _connectedEndpointId = '';
  Map<String, String> _discoveredDevices = {}; // endpointId -> name
  Map<String, String> _peerEndpointMap = {}; // peerIdentifier -> endpointId

  // Add a GlobalKey for the ScaffoldState to control the sidebar
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Add a controller for the sidebar animation
  late AnimationController _sidebarController;
  late Animation<Offset> _sidebarOffsetAnimation;

  // Add these new state variables after the existing ones (around line 235)
  String _currentChatId = '';
  final Map<String, ChatSession> _chatSessions = {};
  final List<String> _chatList = []; // Fix this line
  String _profileImagePath = ''; // Add this line

  // Image selection state variables
  final List<String> _selectedImagePaths = [];

  // Local notifications
  final notifications.FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      notifications.FlutterLocalNotificationsPlugin();
  late final ImagePicker _imagePicker;

  // Add this variable to track if the note should be shown
  bool _showNoteMessage = true;

  // Notification polling variables
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _initializeApp();
    // Add observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Initialize the sidebar animation controller
    _sidebarController = AnimationController(
      duration: const Duration(
        milliseconds: 400,
      ), // Increased duration for smoother animation
      vsync: this,
    );

    _sidebarOffsetAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _sidebarController,
            curve: Curves.easeOutCubic, // Smoother easing curve
          ),
        );

    // Ensure the sidebar is initially hidden
    _sidebarController.value = 1.0; // Set to fully hidden position

    // Initialize animation controller for mic pulse effect
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Initialize speech to text
    _speechToText = stt.SpeechToText();

    // Initialize image picker
    _imagePicker = ImagePicker();

    // Add text controller listener for icon toggling
    _textController.addListener(_onTextChanged);

    // Initialize Hive and load data
    _loadChatSessions();

    // Initialize P2P
    _initializeP2P();
    
    // Initialize WebRTC
    _webrtcService.initRenderers();
    _webrtcService.onSignalingMessage = (signal) {
      if (_connectedEndpointId.isNotEmpty) {
        _p2pService.sendMessage(_connectedEndpointId, {
          'type': 'webrtc_signal',
          'signal': signal,
        });
      }
    };
  }

  @override
  void dispose() {
    // Remove observer when disposing
    WidgetsBinding.instance.removeObserver(this);
    // Cancel notification timer when disposing
    _notificationTimer?.cancel();
    _textController.removeListener(
      _onTextChanged,
    ); // Remove listener to prevent memory leaks
    _textController.dispose();
    _scrollController.dispose();
    _audioRecorder.closeRecorder();
    _audioPlayer.closePlayer();
    _animationController.dispose(); // Dispose animation controller
    _sidebarController.dispose(); // Dispose sidebar controller
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App is in foreground
      print('App resumed - in foreground');
      // Refresh username when app resumes
      _refreshUserName();
      // Refresh messages when app comes to foreground
      _loadChatSessions();
    } else if (state == AppLifecycleState.paused) {
      // App is in background
      print('App paused - in background');
      // Save current chat state
      _saveCurrentChat();
    } else if (state == AppLifecycleState.detached) {
      // App is about to be terminated
      print('App detached - about to terminate');
      // Save current chat state
      _saveCurrentChat();
      // Removed legacy Socket.IO disconnect
    }
  }

  Future<void> _initializeNotifications() async {
    // Initialize the Flutter Local Notifications plugin
    const notifications.AndroidInitializationSettings initializationSettingsAndroid =
        notifications.AndroidInitializationSettings('@mipmap/ic_launcher');

    final notifications.InitializationSettings initializationSettings =
        notifications.InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (notifications.NotificationResponse response) async {
        // Handle notification tap when app is in background/killed
        print('Notification tapped: ${response.payload}');
        // Navigate to chat screen or perform relevant action
      },
    );

    // Request notification permissions
    await _requestNotificationPermissions();
  }

  Future<void> _requestNotificationPermissions() async {
    final notifications.AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              notifications.AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  Future<void> _showNotification(String title, String body) async {
    const notifications.AndroidNotificationDetails androidNotificationDetails =
        notifications.AndroidNotificationDetails(
      'message_channel_id',
      'Messages',
      channelDescription: 'Notifications for new messages',
      importance: notifications.Importance.max,
      priority: notifications.Priority.high,
      showWhen: true,
    );

    const notifications.NotificationDetails notificationDetails =
        notifications.NotificationDetails(android: androidNotificationDetails);

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 1000000,
      title,
      body,
      notificationDetails,
      payload: 'chat_notification',
    );
  }

  void _initializeP2P() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('user_name') ?? 'User';
    
    _p2pService.onEndpointFound = (id, name) {
      setState(() {
        _discoveredDevices[id] = name;
      });
      // Auto-connect if it matches a known recipient email (dummy logic for now)
      // or show in a list for the user to pick.
    };
    
    _p2pService.onEndpointLost = (id) {
      setState(() {
        _discoveredDevices.remove(id);
      });
    };
    
    _p2pService.onConnectionInitiated = (id, info) {
      // Auto-accept for now
      _p2pService.acceptConnection(id);
    };
    
    _p2pService.onConnectionResult = (id) {
      setState(() {
        _connectedEndpointId = id;
        _isConnected = true;
      });
      print("Connected to P2P endpoint: $id");

      // Update lastConnected time for this peer and send profile data
      _updatePeerOnConnect(id);
    };

    _p2pService.onDisconnected = (id) {
      setState(() {
        if (_connectedEndpointId == id) {
          _connectedEndpointId = '';
          _isConnected = false;
        }
      });
    };

    _p2pService.onPayloadReceived = (id, payload) {
      if (payload.type == PayloadType.BYTES) {
        String jsonString = utf8.decode(payload.bytes!);
        Map<String, dynamic> data = jsonDecode(jsonString);

        if (data['type'] == 'message') {
          // Extract sender name if available
          String? senderName = data['senderName'];
          _handleIncomingP2PMessage(Message.fromJson(data['message']), senderName: senderName);
        } else if (data['type'] == 'webrtc_signal') {
          final signal = data['signal'];
          if (signal['type'] == 'offer' && mounted) {
            _showIncomingCallDialog(id, signal);
          } else {
            _webrtcService.handleSignal(signal);
          }
        } else if (data['type'] == 'profile_update') {
          // Handle incoming profile update from peer
          _handlePeerProfileUpdate(id, data);
        }
      }
    };

    // Start advertising and discovery
    await _p2pService.startAdvertising(userName);
    await _p2pService.startDiscovery(userName);
  }

  void _handleIncomingP2PMessage(Message message, {String? senderName}) {
    // Find the correct chat session for this sender
    String targetChatId = _currentChatId;

    if (senderName != null) {
      // Try to find a chat for this sender
      for (var entry in _chatSessions.entries) {
        if (entry.value.peerName == senderName || entry.value.recipientId == senderName) {
          targetChatId = entry.key;
          break;
        }
      }
    }

    // Add message to the correct chat's session
    if (_chatSessions.containsKey(targetChatId) && targetChatId != QUERYSPACE_CHAT_ID) {
      final updatedSession = _chatSessions[targetChatId]!.copyWith(
        messages: [..._chatSessions[targetChatId]!.messages, message],
        lastUpdated: DateTime.now(),
      );
      _chatSessions[targetChatId] = updatedSession;

      // If we're not viewing this chat, switch to it and show notification
      if (_currentChatId != targetChatId) {
        _showNotification('New Message from ${_chatSessions[targetChatId]?.title ?? 'Unknown'}', message.text);
      }
    }

    setState(() {
      _messages.add(message);
      _showNoteMessage = false;
    });
    _saveChatSessions();
    _scrollToBottom();
  }

  Future<void> _updatePeerOnConnect(String endpointId) async {
    // Find the chat session for this peer by endpoint ID or name
    String? peerName = _discoveredDevices[endpointId];
    if (peerName == null) return;

    // Find chat session by peer name or create map
    String? chatId;
    String? peerUuid;
    for (var entry in _chatSessions.entries) {
      if (entry.value.peerName == peerName || entry.value.recipientId == peerName) {
        chatId = entry.key;
        peerUuid = entry.value.peerUuid;
        break;
      }
    }

    // Store the peer -> endpoint mapping for message routing
    _peerEndpointMap[peerName] = endpointId;
    if (peerUuid != null) {
      _peerEndpointMap[peerUuid] = endpointId;
    }

    if (chatId != null) {
      // Update lastConnected time
      final updatedSession = _chatSessions[chatId]!.copyWith(
        lastConnected: DateTime.now(),
      );
      setState(() {
        _chatSessions[chatId!] = updatedSession;
      });
      await _saveChatSessions();
    }

    // Send profile data to peer
    await _sendProfileToPeer(endpointId);
  }

  Future<void> _sendProfileToPeer(String endpointId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('user_name') ?? '';
      String? profileImageBase64;

      // Load profile image if exists
      final profileImagePath = prefs.getString('profile_image_path') ?? '';
      if (profileImagePath.isNotEmpty) {
        final file = File(profileImagePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          profileImageBase64 = base64Encode(bytes);
        }
      }

      // Send profile update to peer
      await _p2pService.sendMessage(endpointId, {
        'type': 'profile_update',
        'name': userName,
        'profileImage': profileImageBase64 ?? '',
      });
      print('Sent profile update to peer: $endpointId');
    } catch (e) {
      print('Error sending profile to peer: $e');
    }
  }

  void _handlePeerProfileUpdate(String endpointId, Map<String, dynamic> data) {
    try {
      final peerName = data['name'] as String? ?? 'Unknown';
      final profileImage = data['profileImage'] as String? ?? '';

      print('Received profile update from $endpointId: name=$peerName');

      // Find and update the chat session for this peer
      String? chatId;
      for (var entry in _chatSessions.entries) {
        if (entry.value.peerName == peerName || entry.value.recipientId == peerName) {
          chatId = entry.key;
          break;
        }
      }

      if (chatId != null) {
        final updatedSession = _chatSessions[chatId]!.copyWith(
          profileImageBase64: profileImage.isNotEmpty ? profileImage : null,
          lastConnected: DateTime.now(),
        );
        setState(() {
          _chatSessions[chatId!] = updatedSession;
        });
        _saveChatSessions();
      }
    } catch (e) {
      print('Error handling peer profile update: $e');
    }
  }

  Future<void> _initializeApp() async {
    try {
      print('Initializing app...');

      // Load user name with timeout
      await _loadUserName().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          print('Loading username timed out');
          return Future.value();
        },
      );

      // Load saved QR URL
      await _loadSavedQrUrl();

      // Check if permissions are already granted with timeout
      final permissionsGranted = await _checkPermissions().timeout(
        Duration(seconds: 15),
        onTimeout: () {
          print('Permission check timed out');
          return Future.value(false);
        },
      );

      // Initialize audio recorder
      await _initAudioRecorder();

      // Initialize audio player
      await _initAudioPlayer();

      // Initialize speech to text
      _initSpeechToText();

      // Load chat sessions from storage
      await _loadChatSessions();

      // If no chats exist, create a default chat (which will be QuerySpace)
      if (_chatSessions.isEmpty) {
        _createNewChat();
      } else {
        // Ensure QuerySpace exists
        if (!_isQuerySpaceExists()) {
          await _openOrCreateQuerySpace();
        }

        // Set the first chat as current
        _currentChatId = _chatList.first;
        // Load messages for current chat
        _messages.clear();
        _messages.addAll(_chatSessions[_currentChatId]!.messages);
        // Initialize note visibility based on whether there are messages
        _showNoteMessage = _messages.isEmpty;
      }

      // Scroll to bottom to show latest messages
      if (_messages.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }

      // Removed server connection status check

      // Removed unnecessary state updates

      print('App initialization complete');
    } catch (e, s) {
      print('Error during app initialization: $e');
      print('Stack trace: $s');
      // Log error but don't try to set non-existent state fields
    }
  }

  /// Checks if QuerySpace chat exists
  bool _isQuerySpaceExists() {
    return _chatSessions.containsKey(QUERYSPACE_CHAT_ID);
  }

  /// Creates or opens QuerySpace chat
  Future<void> _openOrCreateQuerySpace() async {
    try {
      // If QuerySpace doesn't exist, create it
      if (!_isQuerySpaceExists()) {
        final newSession = ChatSession(
          id: QUERYSPACE_CHAT_ID,
          title: 'QuerySpace',
          createdAt: DateTime.now(),
          lastUpdated: DateTime.now(),
          messages: [
            Message(
              id: 1,
              text:
                  'Welcome to QuerySpace! This is your personal help assistant.\n\nI can help you understand how this application works:\n• Scan QR codes to connect with other users\n• Send text and voice messages\n• Manage your profile and settings\n• View your chat history\n\nFeel free to ask me any questions about the app!',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          ],
        );

        setState(() {
          _chatSessions[QUERYSPACE_CHAT_ID] = newSession;
          if (!_chatList.contains(QUERYSPACE_CHAT_ID)) {
            _chatList.insert(0, QUERYSPACE_CHAT_ID);
          }
          _currentChatId = QUERYSPACE_CHAT_ID;
          _messages.clear();
          _messages.addAll(newSession.messages);
        });

        // Save to persistent storage
        await _saveChatSessions();
      } else {
        // If it exists, just open it
        setState(() {
          _currentChatId = QUERYSPACE_CHAT_ID;
          _messages.clear();
          _messages.addAll(_chatSessions[QUERYSPACE_CHAT_ID]!.messages);
        });
      }
    } catch (e) {
      print('Error opening/creating QuerySpace: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening QuerySpace: $e'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Generates hardcoded responses for QuerySpace chat
  String _generateQuerySpaceResponse(String userInput) {
    final input = userInput.toLowerCase().trim();

    // Helper function to make responses more natural
    String personalize(String response) {
      final greetings = ['Hey!', 'Hi there!', 'Hello!', 'Great question!', 'I\'ve got you covered!'];
      final connectors = [
        'Here\'s how:',
        'Let me explain:',
        'I can help with that:',
        'Sure thing!',
        'Absolutely!',
        'Scanning my knowledge base...',
        'Checking the P2P protocols...',
      ];
      final random = Random();
      return '${greetings[random.nextInt(greetings.length)]} '
          '${connectors[random.nextInt(connectors.length)]}\n\n$response';
    }

    // Handle connection status queries
    if (input.contains('connection') || input.contains('connected') || input.contains('status')) {
      return personalize(
        'In QuerySpace, your connection status is shown at the top right of the AppBar:\n\n'
        '🟢 **Green Circle**: You are actively connected to the peer in this chat.\n'
        '⚪ **Grey Circle**: No active P2P connection found. Try moving closer or re-scanning their QR code.\n\n'
        '💡 **Note**: I (QuerySpace) am always green because I live right here on your device!'
      );
    }

    // Handle security/fingerprint queries
    if (input.contains('fingerprint') || input.contains('security') || input.contains('biometric')) {
      return personalize(
        'Security is our top priority! 🛡️\n\n'
        'This app uses **Fingerprint-Only** biometric security. You can enable it in your Profile settings. '
        'Once active, you\'ll need your fingerprint to open the app or change sensitive settings. '
        'No PIN or Face ID fallbacks are allowed for maximum security.'
      );
    }

    // Handle "all sort of Qury from user" (General catch-all)
    if (input.contains('what can you do') || input.contains('capabilities') || input.contains('features')) {
      return personalize(
        'I am your local offline assistant! I can guide you through:\n\n'
        '1. **P2P Identity**: Everything is stored on your device using UUIDs.\n'
        '2. **Messaging**: Text, voice messages, and image sharing—all offline!\n'
        '3. **Audio/Video Calls**: Peer-to-peer calls via WebRTC.\n'
        '4. **QR Connections**: The only way to securely link with friends nearby.\n'
        '5. **Privacy**: Zero server logs. Your data never leaves the mesh network.'
      );
    }

    // Handle greetings
    if (input.contains('hello') ||
        input.contains('hi') ||
        input.contains('hey') ||
        input.contains('greetings') ||
        input.contains('good morning') ||
        input.contains('good afternoon') ||
        input.contains('good evening')) {
      final responses = [
        'Hello there! 👋 Welcome to QuerySpace. I\'m ready to handle any query you throw at me!',
        'Hi! Nice to see you here. I\'m always connected and ready to assist.',
        'Hey! I\'m your QuerySpace assistant. How can I make your experience better today?',
        'Greetings! I\'m here to guide you through our P2P mesh world. What\'s on your mind?',
      ];
      return responses[Random().nextInt(responses.length)];
    }

    // Help/guide requests
    if (input.contains('help') ||
        input.contains('guide') ||
        input.contains('how to') ||
        input.contains('tutorial') ||
        input.contains('explain')) {
      return personalize(
        'I\'d be happy to walk you through QuerySpace! Here are the main things I can help with:\n\n'
        '• Connecting with friends using QR codes\n'
        '• Sending messages (text, voice, and images)\n'
        '• Managing your profile and fingerprint settings\n'
        '• Navigating your chats and history\n'
        '• Understanding P2P communication\n\n'
        'What specific part would you like to know more about?',
      );
    }

    // QR code related
    if (input.contains('qr') ||
        input.contains('scan') ||
        input.contains('connect') ||
        input.contains('add friend') ||
        input.contains('new contact')) {
      return personalize(
        'Connecting with others is super easy with QR codes! Here\'s the process:\n\n'
        '1. **Go to your Profile** (top left avatar icon)\n'
        '2. **Tap your QR code** to see your personal connect link\n'
        '3. **To add someone:** Use the scan icon on the chat screen\n'
        '4. **Point your camera** at their screen\n\n'
        '💡 **Tip:** Once connected, the status light in the top bar will turn green!',
      );
    }

    // Messaging/chat
    if (input.contains('message') ||
        input.contains('chat') ||
        input.contains('send') ||
        input.contains('text') ||
        input.contains('talk to')) {
      return personalize(
        'Messaging in QuerySpace is designed to be smooth and intuitive:\n\n'
        '• **Start a chat:** Connect via QR, then tap their name in the sidebar\n'
        '• **Type a message:** Use the text box at the bottom\n'
        '• **Send voice notes:** Hold 🎤 and speak (release to send)\n'
        '• **Share images:** Tap 📎 to select photos\n'
        '• **Offline Mesh**: Your messages travel directly to the peer via Nearby Connections!\n\n'
        'Everything happens in real-time, so you\'ll see messages instantly if the user is in range!',
      );
    }

    // Profile settings
    if (input.contains('profile') ||
        input.contains('setting') ||
        input.contains('account') ||
        input.contains('edit') ||
        input.contains('name') ||
        input.contains('avatar')) {
      return personalize(
        'Your profile is your identity in QuerySpace! Here\'s what you can do:\n\n'
        '🔧 **Edit Profile:**\n'
        '   - Change your display name\n'
        '   - Update your profile picture\n'
        '   - Configure Fingerprint Security\n\n'
        '👥 **Connections:**\n'
        '   - See all your P2P contacts in the sidebar\n'
        '   - Check connection status indicators\n'
        '   - Manage your local chat vault\n\n'
        'Just tap the avatar in the top left to get started!',
      );
    }

    // History/viewing
    if (input.contains('history') ||
        input.contains('view') ||
        input.contains('previous') ||
        input.contains('old') ||
        input.contains('past chat')) {
      return personalize(
        'Looking for past conversations? Your vault is safe!\n\n'
        '• **All your chats** are saved locally via Hive\n'
        '• **Scroll up** in any chat to see older messages\n'
        '• **Sidebar:** Access your full list of previous chats\n'
        '• **Privacy:** Your history never touches any server.\n\n'
        'Your chat history stays exactly where it belongs—on your phone.',
      );
    }

    // Voice messages
    if (input.contains('voice') ||
        input.contains('audio') ||
        input.contains('record') ||
        input.contains('mic') ||
        input.contains('speak')) {
      return personalize(
        'Voice messages make chatting more personal! Here\'s how:\n\n'
        '🎤 **To record:**\n'
        '   1. Press and hold the microphone button\n'
        '   2. Speak your message\n'
        '   3. Release to send immediately\n\n'
        '🔊 **To listen:**\n'
        '   • Tap any audio message to play\n'
        '   • You can play/pause at any time\n\n'
        '💡 **Note**: You can also transcribe your voice to text by enabling the "Voice to Speech" setting in your profile!',
      );
    }

    // Images/media
    if (input.contains('image') ||
        input.contains('photo') ||
        input.contains('picture') ||
        input.contains('gallery') ||
        input.contains('media') ||
        input.contains('attach')) {
      return personalize(
        'Sharing memories is easy! Here\'s how to send images:\n\n'
        '📸 **From your gallery:**\n'
        '   1. Tap the 📎 attachment icon\n'
        '   2. Select your photos\n'
        '   3. Add a caption if you want\n'
        '   4. Tap send to share via the mesh network!\n\n'
        '🖼️ **Viewing images:**\n'
        '   • Tap any image to view full screen\n'
        '   • Pinch to zoom in/out\n',
      );
    }

    // Thanks/gratitude
    if (input.contains('thank') ||
        input.contains('thanks') ||
        input.contains('appreciate') ||
        input.contains('helpful')) {
      final responses = [
        'You\'re very welcome! 😊 Happy to keep things running gracefully. Anything else?',
        'My pleasure! I\'m always here and always connected for you.',
        'Glad I could help! I\'ve updated my logs with your gratitude. What\'s next?',
        'Anytime! That\'s what a graceful assistant like me is for! 🌟',
      ];
      return responses[Random().nextInt(responses.length)];
    }

    // Farewells
    if (input.contains('bye') ||
        input.contains('goodbye') ||
        input.contains('see you') ||
        input.contains('later')) {
      final responses = [
        'Goodbye! 👋 I\'ll be right here waiting for your next query!',
        'See you later! I\'ll stay connected in the background.',
        'Bye for now! Stay secure with that fingerprint lock! 🔒',
        'Take care! I\'m always just a query away.',
      ];
      return responses[Random().nextInt(responses.length)];
    }

    // Positive feedback
    if (input.contains('good') ||
        input.contains('great') ||
        input.contains('awesome') ||
        input.contains('cool') ||
        input.contains('love') ||
        input.contains('nice')) {
      return 'That\'s wonderful to hear! 😄 I strive for graceful responses every time. '
          'Should I explain more about the P2P connection status?';
    }

    // Default response with engagement
    final defaultResponses = [
      'I\'d love to help you with that graceful request! Could you tell me a bit more about what you\'re looking for?',
      'That\'s a great query! To give you the best answer, could you specify which feature you mean?',
      'I can help with various QuerySpace features! Are you wondering about the connection status or fingerprint security?',
      'Let me help you navigate the mesh! What specific feature would you like to learn about gracefully?',
    ];

    return defaultResponses[Random().nextInt(defaultResponses.length)];
  }

  Future<void> _loadUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('SharedPreferences initialization timed out');
          throw TimeoutException(
            'SharedPreferences timeout',
            Duration(seconds: 5),
          );
        },
      );
      setState(() {
        _userName = prefs.getString('user_name') ?? 'User';
        _profileImagePath =
            prefs.getString('profile_image_path') ?? ''; // Add this line
      });
      print('Loaded username: $_userName');
      print('Loaded profile image path: $_profileImagePath'); // Add this line

      // Removed home widget update
    } catch (e) {
      print('Error loading username: $e');
      // Use default username if there's an error
      setState(() {
        _userName = 'User';
        _profileImagePath = ''; // Add this line
      });

      // Removed home widget update
    }
  }

  /// Load the saved QR code URL
  Future<void> _loadSavedQrUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _savedQrUrl = prefs.getString('scanned_qr_url') ?? '';
      });
      print('Loaded saved QR URL: $_savedQrUrl');
    } catch (e) {
      print('Error loading saved QR URL: $e');
      setState(() {
        _savedQrUrl = '';
      });
    }
  }

  /// Check if all necessary permissions are granted
  Future<bool> _checkPermissions() async {
    try {
      // Check microphone permission with timeout
      final micStatus = await Permission.microphone.status.timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('Microphone permission check timed out');
          return Future.value(PermissionStatus.denied);
        },
      );
      if (micStatus != PermissionStatus.granted) {
        return false;
      }

      // Check storage permission with timeout
      final storageStatus = await Permission.storage.status.timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('Storage permission check timed out');
          return Future.value(PermissionStatus.denied);
        },
      );
      if (storageStatus != PermissionStatus.granted) {
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking permissions: $e');
      return false;
    }
  }

  Future<void> _initAudioRecorder() async {
    try {
      // Request microphone permission first with timeout
      final micStatus = await Permission.microphone.request().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          print('Microphone permission request timed out');
          return Future.value(PermissionStatus.denied);
        },
      );
      if (micStatus != PermissionStatus.granted) {
        print('Microphone permission denied');
        // Show a message to the user about permissions
        if (mounted) {}
        return; // Don't proceed with audio initialization if permission is denied
      }

      // Also check storage permission for saving recordings (if needed) with timeout
      final storageStatus = await Permission.storage.request().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          print('Storage permission request timed out');
          return Future.value(PermissionStatus.denied);
        },
      );
      if (storageStatus != PermissionStatus.granted) {
        print('Storage permission denied - this may limit some features');
        // This is not critical, so we continue
      }

      // Add timeout to prevent hanging
      await _audioRecorder.openRecorder().timeout(Duration(seconds: 15));
    } catch (e) {
      print('Error initializing audio recorder: $e');
      // Don't let audio initialization errors crash the app
      if (mounted) {}
    }
  }

  Future<void> _initAudioPlayer() async {
    try {
      await _audioPlayer.openPlayer();

      // Add a small delay to ensure player is ready
      await Future.delayed(Duration(milliseconds: 100));
    } catch (e) {
      print('Error initializing audio player: $e');
    }
  }

  Future<void> _playAudioMessage(
    String base64Audio, {
    String messageId = '',
  }) async {
    try {
      // Stop any currently playing audio
      if (_isPlaying) {
        await _audioPlayer.stopPlayer();
        _isPlaying = false;
        _currentlyPlayingMessageId = '';
      }

      // Decode base64 audio data
      final audioBytes = base64Decode(base64Audio);

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFilePath = '${tempDir.path}/temp_audio_$timestamp.aac';

      // Write audio data to temporary file
      final tempFile = File(tempFilePath);
      await tempFile.writeAsBytes(audioBytes);

      // Play the audio file
      await _audioPlayer.startPlayer(
        fromURI: tempFilePath,
        whenFinished: () {
          // Reset playing state when finished
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _currentlyPlayingMessageId = '';
            });
          }
        },
      );

      // Update playing state
      if (mounted) {
        setState(() {
          _isPlaying = true;
          _currentlyPlayingMessageId = messageId;
        });
      }

      print('Playing audio message');
    } catch (e) {
      print('Error playing audio message: $e');
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentlyPlayingMessageId = '';
        });
      }
    }
  }

  void _initSpeechToText() {
    _speechToText = stt.SpeechToText();
  }

  // Start audio recording
  Future<void> _startAudioRecording() async {
    try {
      // Check permissions
      final micStatus = await Permission.microphone.status;
      if (micStatus != PermissionStatus.granted) {
        final requestedStatus = await Permission.microphone.request();
        if (requestedStatus != PermissionStatus.granted) {
          if (mounted) {}
          return;
        }
      }

      // Get temporary directory for audio file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _audioPath = '${tempDir.path}/audio_$timestamp.aac';

      // Start recording
      await _audioRecorder.startRecorder(toFile: _audioPath);

      setState(() {
        _isRecording = true;
      });

      print('Started audio recording to: $_audioPath');
    } catch (e) {
      print('Error starting audio recording: $e');
      if (mounted) {}
    }
  }

  // Stop audio recording and send as message
  Future<void> _stopAudioRecording() async {
    try {
      if (_isRecording) {
        await _audioRecorder.stopRecorder();

        setState(() {
          _isRecording = false;
        });

        // Send the recorded audio file
        await _sendAudioMessage(_audioPath);

        print('Stopped audio recording');
      }
    } catch (e) {
      print('Error stopping audio recording: $e');
      setState(() {
        _isRecording = false;
      });
      if (mounted) {}
    }
  }

  // Send audio message
  Future<void> _sendAudioMessage(String audioPath) async {
    try {
      // Read audio file
      final audioFile = File(audioPath);
      final audioBytes = await audioFile.readAsBytes();
      final audioBase64 = base64Encode(audioBytes);

      // Create message content indicating it's an audio file with the base64 data
      final messageContent = '[AUDIO:$audioBase64] Recorded voice message';

      // Send message with audio attachment
      await _sendMessage(messageContent);

      print('Audio message sent');
    } catch (e) {
      print('Error sending audio message: $e');
      if (mounted) {}
    }
  }

  // Disable the polling mechanism to avoid conflicts with the server
  // The server will handle all API interactions
  void _startPolling() {
    // Do nothing - polling is handled by the server
    print('Polling disabled - server handles API interactions');
  }

  Future<void> _loadChatSessions() async {
    try {
      final box = Hive.box<ChatSession>('chat_sessions');
      _chatSessions.clear();
      _chatList.clear();
      
      for (var session in box.values) {
        _chatSessions[session.id] = session;
        _chatList.add(session.id);
      }
      
      // Ensure QuerySpace is at the top of the list if it exists
      if (_chatList.contains(QUERYSPACE_CHAT_ID)) {
        _chatList.remove(QUERYSPACE_CHAT_ID);
        _chatList.insert(0, QUERYSPACE_CHAT_ID);
      }

      // Set initial chat if none is set
      if (_currentChatId.isEmpty && _chatList.isNotEmpty) {
        setState(() {
          _currentChatId = _chatList.first;
          if (_chatSessions.containsKey(_currentChatId)) {
            _messages.clear();
            _messages.addAll(_chatSessions[_currentChatId]!.messages);
            _showNoteMessage = _messages.isEmpty;
          }
        });
      }
      print('Loaded ${_chatSessions.length} chat sessions from storage');
    } catch (e) {
      print('Error loading chat sessions: $e');
      // Continue with empty chat sessions list if there's an error
      // Ensure note is shown for empty chat
      _showNoteMessage = true;
    }
  }

  Future<void> _saveChatSessions() async {
    try {
      final box = Hive.box<ChatSession>('chat_sessions');
      await box.clear();
      for (var session in _chatSessions.values) {
        await box.put(session.id, session);
      }
    } catch (e) {
      print('Error saving chat sessions: $e');
    }
  }

  void _createNewChat() {
    // Instead of creating an empty chat, open or create QuerySpace
    _openOrCreateQuerySpace();
  }

  void _switchToChat(String chatId) {
    if (_chatSessions.containsKey(chatId)) {
      setState(() {
        // Save current messages to current chat
        if (_chatSessions.containsKey(_currentChatId)) {
          _chatSessions[_currentChatId] = _chatSessions[_currentChatId]!
              .copyWith(
                messages: List.from(_messages),
                lastUpdated: DateTime.now(),
                title: _generateChatTitle(
                  _messages,
                  _chatSessions[_currentChatId]!.title,
                ),
              );
        }

        // Switch to new chat
        _currentChatId = chatId;
        _messages.clear();
        _messages.addAll(_chatSessions[chatId]!.messages);

        // Update note visibility for the new chat
        _showNoteMessage = _messages.isEmpty;
      });

      _scrollToBottom();
      _saveChatSessions();
      _closeSidebar();
    }
  }

  String _generateChatTitle(List<Message> messages, String currentTitle) {
    // Always keep the current title - don't rename based on messages
    return currentTitle.isNotEmpty ? currentTitle : 'New Chat';
  }

  void _deleteChat(String chatId) {
    // Prevent deletion of QuerySpace if it's the last chat
    if (chatId == QUERYSPACE_CHAT_ID && _chatList.length == 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'QuerySpace cannot be deleted when it is the only chat remaining.',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (_chatSessions.containsKey(chatId)) {
      setState(() {
        _chatSessions.remove(chatId);
        _chatList.remove(chatId);

        // If we deleted the current chat, switch to another one or create a new one
        if (_currentChatId == chatId) {
          if (_chatList.isNotEmpty) {
            _currentChatId = _chatList.first;
            _messages.clear();
            _messages.addAll(_chatSessions[_currentChatId]!.messages);
            _showNoteMessage = _messages.isEmpty;
          } else {
            // If all chats are deleted, automatically create/open QuerySpace
            if (!_isQuerySpaceExists()) {
              _openOrCreateQuerySpace();
            } else {
              // If QuerySpace exists, make it active
              _currentChatId = QUERYSPACE_CHAT_ID;
              _messages.clear();
              _messages.addAll(_chatSessions[QUERYSPACE_CHAT_ID]!.messages);
            }
            _showNoteMessage = _messages.isEmpty;
          }
        }
      });

      _saveChatSessions();
    }
  }

  // Removed server connection status checks

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch,
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _messages.add(message);
      _textController.clear();
      _showNoteMessage = false;
    });
    
    _scrollToBottom();
    _saveCurrentChat();
    
    // Handle QuerySpace local response
    if (_currentChatId == QUERYSPACE_CHAT_ID) {
      final responseText = _generateQuerySpaceResponse(text);
      
      // Small delay for natural feel, then add bot response
      await Future.delayed(const Duration(milliseconds: 600));
      
      if (mounted) {
        final botMessage = Message(
          id: DateTime.now().millisecondsSinceEpoch,
          text: responseText,
          isUser: false,
          timestamp: DateTime.now(),
        );
        
        setState(() {
          _messages.add(botMessage);
        });
        _scrollToBottom();
        _saveCurrentChat();
      }
      return; // Skip P2P send for QuerySpace
    }

    // Find the endpoint ID for the current peer chat
    String? targetEndpointId;
    final chatSession = _chatSessions[_currentChatId];
    if (chatSession != null) {
      // First check if we have a direct mapping
      if (_peerEndpointMap.containsKey(chatSession.peerUuid)) {
        targetEndpointId = _peerEndpointMap[chatSession.peerUuid];
      } else if (_peerEndpointMap.containsKey(chatSession.peerName)) {
        targetEndpointId = _peerEndpointMap[chatSession.peerName];
      }
      // Fallback to connected endpoint if we're in a chat with the connected peer
      else if (_connectedEndpointId.isNotEmpty) {
        targetEndpointId = _connectedEndpointId;
      }
    }

    // Send over P2P if we have a target endpoint
    if (targetEndpointId != null && targetEndpointId.isNotEmpty) {
      await _p2pService.sendMessage(targetEndpointId, {
        'type': 'message',
        'message': message.toJson(),
        'senderName': _userName,
      });
      print('Message sent to $targetEndpointId');
    } else {
      print('No endpoint found for peer - message not sent. Peer may be out of range.');
    }
  }

  Future<void> _saveCurrentChat() async {
    if (_currentChatId.isEmpty) {
      print('Cannot save chat: No current chat ID set');
      return;
    }

    if (_chatSessions.containsKey(_currentChatId)) {
      try {
        // Update the current chat session with the latest messages
        final updatedSession = _chatSessions[_currentChatId]!.copyWith(
          messages: List.from(_messages),
          lastUpdated: DateTime.now(),
          title: _generateChatTitle(
            _messages,
            _chatSessions[_currentChatId]!.title,
          ),
        );

        // Update in memory first
        setState(() {
          _chatSessions[_currentChatId] = updatedSession;
        });

        // Save all chat sessions to persistent storage
        await _saveChatSessions();
        print('Successfully saved chat session for $_currentChatId');
      } catch (e) {
        print('Error saving chat session: $e');
      }
    }
  } // Speech to text methods

  void _startListening() async {
    try {
      // Check microphone permission before starting speech recognition with timeout
      final micStatus = await Permission.microphone.status.timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('Microphone permission check timed out');
          return Future.value(PermissionStatus.denied);
        },
      );
      if (micStatus != PermissionStatus.granted) {
        // Request permission with timeout
        final requestedStatus = await Permission.microphone.request().timeout(
          Duration(seconds: 10),
          onTimeout: () {
            print('Microphone permission request timed out');
            return Future.value(PermissionStatus.denied);
          },
        );
        if (requestedStatus != PermissionStatus.granted) {
          // Show a message to the user
          if (mounted) {}
          return;
        }
      }

      if (!_isListening) {
        bool available = await _speechToText
            .initialize(
              onStatus: (status) {
                print('Speech recognition status: $status');
                // Update UI based on status
                if (status == 'listening') {
                  setState(() {
                    _isListening = true;
                  });
                } else if (status == 'notListening' || status == 'done') {
                  // Speech recognition has stopped, update UI accordingly
                  setState(() {
                    _isListening = false;
                    _transcribedText = '';
                  });
                }
              },
              onError: (error) {
                print('Speech recognition error: $error');
                setState(() {
                  _isListening = false;
                });
              },
            )
            .timeout(
              Duration(seconds: 10),
              onTimeout: () {
                print('Speech recognition initialization timed out');
                throw TimeoutException(
                  'Speech recognition timeout',
                  Duration(seconds: 10),
                );
              },
            );

        if (available) {
          setState(() => _isListening = true);
          _speechToText.listen(
            onResult: (result) {
              setState(() {
                _transcribedText = result.recognizedWords;
                // Update text field with partial results only while listening
                // But don't automatically send - user must tap send button
                _textController.text = _transcribedText;
                // Move cursor to end of text
                _textController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _textController.text.length),
                );
              });
            },
          );
        } else {
          // Show error message to user
        }
      } else {
        // Stop listening when user taps mic button again
        setState(() => _isListening = false);
        await _speechToText.stop().timeout(
          Duration(seconds: 5),
          onTimeout: () {
            print('Speech recognition stop timedout');
            return Future.value();
          },
        );

        // Don't automatically send the transcribed text
        // Only clear the temporary transcribed text variable
        setState(() {
          _transcribedText = '';
          // Do NOT clear the text field - user may want to edit or send it
        });
      }
    } catch (e) {
      print('Error in speech recognition: $e');
      // Handle error gracefully
      setState(() {
        _isListening = false;
        _transcribedText = '';
      });
      if (mounted) {}
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildLeadingAvatar() {
    // For QuerySpace chat, show the app icon
    if (_currentChatId == QUERYSPACE_CHAT_ID) {
      return ClipOval(
        child: Image.asset(
          'assets/icons/mychatconnect.png',
          width: 32,
          height: 32,
          fit: BoxFit.cover,
        ),
      );
    }

    // For peer chats, show their profile image or initial
    final chatSession = _chatSessions[_currentChatId];
    if (chatSession != null && chatSession.profileImageBase64 != null && chatSession.profileImageBase64!.isNotEmpty) {
      return ClipOval(
        child: Image.memory(
          base64Decode(chatSession.profileImageBase64!),
          width: 32,
          height: 32,
          fit: BoxFit.cover,
        ),
      );
    }

    // Show user's own profile image or initial
    if (_profileImagePath.isNotEmpty) {
      return ClipOval(
        child: Image.file(
          File(_profileImagePath),
          width: 32,
          height: 32,
          fit: BoxFit.cover,
        ),
      );
    }

    // Fallback to initial
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.grey[300],
      child: Text(
        _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black,
          fontFamily: 'Comfortaa',
        ),
      ),
    );
  }

  String _formatLastConnected(DateTime? lastConnected) {
    if (lastConnected == null) {
      return 'Never connected';
    }

    final now = DateTime.now();
    final difference = now.difference(lastConnected);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      // For older connections, show the date
      return '${lastConnected.day}/${lastConnected.month}/${lastConnected.year}';
    }
  }

  Widget _buildMessage(Message message, int index) {
    final isUser = message.isUser;
    // Changed to black/white/grey gradient scheme
    final backgroundColor = isUser ? Colors.grey[300] : Colors.white;
    final textColor = Colors.black87;
    final alignment = isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    // Simplified message display to ensure proper vertical growth
    return Column(
      key: ValueKey<int>(index),
      crossAxisAlignment: alignment,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start, // Align to top
            children: [
              if (!isUser) // Bot avatar
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: const CircularBotIcon(
                    size: 16.0,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              // Message container that grows vertically
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.black, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  child: message.isAudio
                      ? GestureDetector(
                          onTap: () {
                            // Extract base64 audio data from message text
                            if (message.text.startsWith('[AUDIO:')) {
                              final startIndex = message.text.indexOf(':') + 1;
                              final endIndex = message.text.indexOf(
                                ']',
                                startIndex,
                              );
                              if (startIndex > 0 && endIndex > startIndex) {
                                final base64Audio = message.text.substring(
                                  startIndex,
                                  endIndex,
                                );
                                // Check if this message is currently playing
                                if (_isPlaying &&
                                    _currentlyPlayingMessageId ==
                                        message.id.toString()) {
                                  // Stop currently playing audio
                                  _audioPlayer.stopPlayer();
                                  if (mounted) {
                                    setState(() {
                                      _isPlaying = false;
                                      _currentlyPlayingMessageId = '';
                                    });
                                  }
                                } else {
                                  // Play audio message
                                  _playAudioMessage(
                                    base64Audio,
                                    messageId: message.id.toString(),
                                  );
                                }
                              }
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.audio_file,
                                color: Colors.black87,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Builder(
                                builder: (context) {
                                  final isCurrentlyPlaying =
                                      _isPlaying &&
                                      _currentlyPlayingMessageId ==
                                          message.id.toString();
                                  return Text(
                                    isCurrentlyPlaying
                                        ? 'Playing...'
                                        : 'Audio Message',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 16,
                                      fontFamily: 'PlaywriteUSModern',
                                      fontWeight: isCurrentlyPlaying
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              Builder(
                                builder: (context) {
                                  final isCurrentlyPlaying =
                                      _isPlaying &&
                                      _currentlyPlayingMessageId ==
                                          message.id.toString();
                                  return Icon(
                                    isCurrentlyPlaying
                                        ? Icons.stop
                                        : Icons.play_arrow,
                                    color: Colors.black87,
                                    size: 20,
                                  );
                                },
                              ),
                            ],
                          ),
                        )
                            : (message.text.startsWith('[IMAGE]')
                                ? Container(
                                    width: 200,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.image,
                                      size: 50,
                                      color: Colors.grey[600],
                                    ),
                                  )
                            : Text(
                                message.text,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontFamily: isUser
                                      ? 'PlaywriteUSModern'
                                      : 'Comfortaa',
                                ),
                                softWrap: true, // Allow text to wrap
                              )),
                ),
              ),
              if (isUser) // User avatar
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  child: _profileImagePath.isNotEmpty
                      ? ClipOval(
                          child: Image.file(
                            File(_profileImagePath),
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                          ),
                        )
                      : CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey[300],
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              _userName.isNotEmpty
                                  ? _userName[0].toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Comfortaa',
                              ),
                            ),
                          ),
                        ),
                ),
            ],
          ),
        ),
        // Timestamp
        Container(
          margin: EdgeInsets.only(
            left: isUser ? 0 : 48,
            right: isUser ? 48 : 0,
            bottom: 8,
          ),
          child: Text(
            '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
              fontFamily: 'Comfortaa',
            ),
          ),
        ),
      ],
    );
  }

  // Add this method to check if we should show the note
  bool _shouldShowNote() {
    return _showNoteMessage && _messages.isEmpty;
  }

  // Add this method to dismiss the note
  void _dismissNote() {
    setState(() {
      _showNoteMessage = false;
    });
  }

  // Add this method to extract image description from message text
  String _extractImageDescription(String messageText) {
    if (messageText.startsWith('[IMAGE:')) {
      // Extract description after the image ID
      final colonIndex = messageText.indexOf(']:');
      if (colonIndex != -1 && colonIndex + 2 < messageText.length) {
        return messageText.substring(colonIndex + 2).trim();
      }
      return '';
    } else if (messageText.startsWith('[IMAGE]')) {
      // Extract description after [IMAGE]
      if (messageText.length > 7) {
        return messageText.substring(7).trim();
      }
      return '';
    }
    return messageText;
  }

  // Removed _getImageData as it's backend dependent

  // Method to show full-screen image dialog
  void _showFullScreenImage(String base64Image) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 4,
                    child: Image.memory(
                      base64Decode(base64Image),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Add this widget builder method to create the note message
  Widget _buildNoteMessage() {
    if (!_shouldShowNote()) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Centered grey box
          Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'If a message is sent, it cannot be modified or deleted.',
              style: TextStyle(
                fontFamily: 'Comfortaa',
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Main app UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Space',
                    style: TextStyle(
                      fontFamily: 'Comfortaa',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  if (_chatSessions.containsKey(_currentChatId))
                    Text(
                      _chatSessions[_currentChatId]!.title,
                      style: TextStyle(
                        fontFamily: 'Comfortaa',
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Connection status indicator
            Icon(
              (_currentChatId == QUERYSPACE_CHAT_ID || _isConnected)
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: Colors.black,
              size: 24,
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 3,
        shadowColor: Colors.grey.withOpacity(0.5),
        shape: Border(bottom: BorderSide(color: Colors.black, width: 1.5)),
        leading: Container(
          margin: EdgeInsets.all(4),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePage(
                    onNameUpdated: (newName) {
                      _refreshUserName();
                    },
                    onLogout: widget.onLogout,
                  ),
                ),
              );
            },
            child: _buildLeadingAvatar(),
          ),
        ),
        actions: [
          if (_currentChatId != QUERYSPACE_CHAT_ID && _currentChatId.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.call, size: 24),
              color: Colors.black,
              onPressed: () => _startCall(),
              tooltip: 'Start Voice/Video Call',
            ),
          IconButton(
            icon: const Icon(Icons.forum),
            color: Colors.black,
            onPressed: () {
              // Check if sidebar is open, if so close it, otherwise open it
              if (_sidebarController.isDismissed) {
                _openSidebar();
              } else {
                _closeSidebar();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.grey[100]!, Colors.grey[200]!],
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    color: Colors.transparent,
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _messages.length + (_shouldShowNote() ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Handle note message as first item
                        if (_shouldShowNote() && index == 0) {
                          return _buildNoteMessage();
                        }

                        // Adjust message index if note is shown
                        final messageIndex = _shouldShowNote()
                            ? index - 1
                            : index;
                        return _buildMessage(
                          _messages[messageIndex],
                          messageIndex,
                        );
                      },
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Center(
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 600),
                      child: Column(
                        children: [
                          // Display selected images
                          if (_selectedImagePaths.isNotEmpty)
                            Container(
                              height: 80,
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _selectedImagePaths.length,
                                itemBuilder: (context, index) {
                                  return Container(
                                    width: 76,
                                    height: 76,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                    ),
                                    child: Stack(
                                      children: [
                                        // Update the Container decoration in the selected images display section
                                        Container(
                                          width: 76,
                                          height: 76,
                                          margin: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              // Add this border property
                                              color: Colors
                                                  .black, // Black border color
                                              width: 3, // Border width
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              ClipOval(
                                                child: Image.file(
                                                  File(
                                                    _selectedImagePaths[index],
                                                  ),
                                                  width: 76,
                                                  height: 76,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // X icon in top right corner
                                        Positioned(
                                          top: -4,
                                          right: -4,
                                          child: GestureDetector(
                                            onTap: () => _removeImage(index),
                                            child: Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: Colors.transparent,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.transparent,
                                                  width: 2,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.red,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          // Message input area
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(30),
                                    color: Colors.white,
                                  ),
                                  child: Row(
                                    children: [
                                      // Attach file icon - Now INSIDE the message box
                                      IconButton(
                                        icon: const Icon(Icons.attach_file),
                                        onPressed: _selectImages,
                                        color: Colors.grey,
                                      ),
                                      Expanded(
                                        child: TextField(
                                          controller: _textController,
                                          maxLines:
                                              null, // Allows unlimited lines
                                          keyboardType: TextInputType
                                              .multiline, // Enables multiline input
                                          decoration: InputDecoration(
                                            hintText: _isListening
                                                ? 'Listening...'
                                                : (_isRecording
                                                      ? 'Recording...'
                                                      : 'Type a message...'),
                                            hintStyle: TextStyle(
                                              fontFamily: 'Comfortaa',
                                              color: _isListening
                                                  ? Colors.black
                                                  : Colors.grey[600],
                                            ),
                                            border: InputBorder
                                                .none, // Remove default border
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 16,
                                                ),
                                            filled:
                                                false, // No fill since container has color
                                          ),
                                          style: TextStyle(
                                            fontFamily: 'Comfortaa',
                                          ),
                                          onSubmitted: (text) {
                                            if (text.trim().isNotEmpty) {
                                              _sendMessage(text);
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FloatingActionButton(
                                onPressed: () async {
                                  final text = _textController.text;
                                  if (text.trim().isNotEmpty ||
                                      _selectedImagePaths.isNotEmpty) {
                                    // Send message when there's text or images selected
                                    _sendMessage(text);
                                  } else {
                                    // Check voice-to-speech setting
                                    bool isVoiceToSpeechEnabled = await _loadVoiceToSpeechSetting();

                                    if (isVoiceToSpeechEnabled) {
                                      // Toggle voice-to-speech when there's no text and no images
                                      _startListening();
                                    } else {
                                      // Toggle audio recording when voice-to-speech is disabled
                                      if (_isRecording) {
                                        _stopAudioRecording();
                                      } else {
                                        _startAudioRecording();
                                      }
                                    }
                                  }
                                },
                                backgroundColor: Colors.white,
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  side: BorderSide(
                                    color: const Color.fromARGB(
                                      255,
                                      175,
                                      172,
                                      172,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.black,
                                              ),
                                        ),
                                      )
                                    : ((_textController.text.trim().isEmpty &&
                                              _selectedImagePaths.isEmpty)
                                          ? Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                if (_isListening ||
                                                    _isRecording)
                                                  ScaleTransition(
                                                    scale: _pulseAnimation,
                                                    child: Container(
                                                      width: 48,
                                                      height: 48,
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey
                                                            .withOpacity(0.5),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                  ),
                                                Icon(
                                                  _isListening
                                                      ? Icons.mic
                                                      : (_isRecording
                                                            ? Icons.stop
                                                            : Icons.mic),
                                                  color:
                                                      _isListening ||
                                                          _isRecording
                                                      ? Colors.redAccent
                                                      : Colors.black,
                                                ),
                                              ],
                                            )
                                          : const Icon(
                                              Icons.send,
                                              color: Colors.black,
                                            )),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Sidebar overlay - Updated with Chats header
          SlideTransition(
            position: _sidebarOffsetAnimation,
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                // Close sidebar when swiping left
                if (details.primaryVelocity! > 0) {
                  _closeSidebar();
                }
              },
              onTap: _closeSidebar, // Close sidebar when tapping anywhere
              child: Container(
                color: Colors.transparent, // No overlay background
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.7,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        left: BorderSide(color: Colors.black, width: 1.5),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Chats header at the top
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment
                                .spaceBetween, // Space between text and icon
                            children: [
                              Text(
                                'Chats',
                                style: TextStyle(
                                  fontFamily: 'Comfortaa',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.post_add,
                                  color:
                                      (_currentChatId == QUERYSPACE_CHAT_ID &&
                                          _isQuerySpaceExists())
                                      ? Colors.grey
                                      : Colors.black,
                                ),
                                onPressed: _openOrCreateQuerySpace,
                              ),
                            ],
                          ),
                        ),
                        // Chat history list
                        Expanded(
                          child: ListView.builder(
                            itemCount: _chatList.length,
                            itemBuilder: (context, index) {
                              final chatId = _chatList[index];
                              final chatSession = _chatSessions[chatId]!;
                              final isSelected = chatId == _currentChatId;

                              return Container(
                                margin: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.grey[300]
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.grey[300]!,
                                    width: 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: Colors.grey.withOpacity(0.4),
                                            spreadRadius: 1,
                                            blurRadius: 3,
                                            offset: Offset(0, 2),
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: Colors.grey.withOpacity(0.1),
                                            spreadRadius: 1,
                                            blurRadius: 2,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                ),
                                child: Stack(
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        _switchToChat(chatId);
                                      },
                                      onLongPress: () {
                                        // Show options menu for chat management
                                        showModalBottomSheet(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return Container(
                                              padding: EdgeInsets.all(16),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    chatSession.title,
                                                    style: TextStyle(
                                                      fontFamily: 'Comfortaa',
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  SizedBox(height: 16),
                                                  ListTile(
                                                    leading: Icon(
                                                      Icons.delete,
                                                      color: Colors.red,
                                                    ),
                                                    title: Text(
                                                      'Delete',
                                                      style: TextStyle(
                                                        fontFamily: 'Comfortaa',
                                                        fontSize: 16,
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                    onTap: () {
                                                      Navigator.of(
                                                        context,
                                                      ).pop();
                                                      // Show confirmation dialog before deleting
                                                      showDialog(
                                                        context: context,
                                                        builder: (BuildContext context) {
                                                          return AlertDialog(
                                                            title: Text(
                                                              'Delete Chat',
                                                            ),
                                                            content: Text(
                                                              'Are you sure you want to delete "${chatSession.title}"?',
                                                            ),
                                                            actions: <Widget>[
                                                              TextButton(
                                                                child: Text(
                                                                  'Cancel',
                                                                ),
                                                                onPressed: () {
                                                                  Navigator.of(
                                                                    context,
                                                                  ).pop();
                                                                },
                                                              ),
                                                              TextButton(
                                                                child: Text(
                                                                  'Delete',
                                                                ),
                                                                onPressed: () {
                                                                  Navigator.of(
                                                                    context,
                                                                  ).pop();
                                                                  _deleteChat(
                                                                    chatId,
                                                                  );
                                                                },
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12.0,
                                          vertical: 10.0,
                                        ),
                                        child: Row(
                                          children: [
                                            // Profile image or app icon with improved styling
                                            Container(
                                              width: 42,
                                              height: 42,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isSelected
                                                      ? Colors.black
                                                      : Colors.grey[400]!,
                                                  width: 1.0,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.grey
                                                        .withOpacity(0.3),
                                                    spreadRadius: 1,
                                                    blurRadius: 2,
                                                    offset: Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                              child: ClipOval(
                                                child:
                                                    chatId == QUERYSPACE_CHAT_ID
                                                    ? Image.asset(
                                                        'assets/icons/mychatconnect.png',
                                                        width: 42,
                                                        height: 42,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : (chatSession.profileImageBase64 !=
                                                              null &&
                                                          chatSession
                                                              .profileImageBase64!
                                                              .isNotEmpty)
                                                    ? Image.memory(
                                                        base64Decode(
                                                          chatSession
                                                              .profileImageBase64!,
                                                        ),
                                                        width: 42,
                                                        height: 42,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Container(
                                                        color: Colors.grey[200],
                                                        child: Center(
                                                          child: Text(
                                                            chatSession
                                                                    .title
                                                                    .isNotEmpty
                                                                ? chatSession
                                                                      .title[0]
                                                                      .toUpperCase()
                                                                : 'U',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Colors
                                                                  .black87,
                                                              fontSize: 18,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                            ),
                                            SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    chatSession.title,
                                                    style: TextStyle(
                                                      fontFamily: 'Comfortaa',
                                                      fontSize: 18,
                                                      fontWeight: isSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.w500,
                                                      color: isSelected
                                                          ? Colors.black
                                                          : Colors.grey[800],
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    chatId == QUERYSPACE_CHAT_ID
                                                        ? 'Your assistant'
                                                        : _formatLastConnected(chatSession.lastConnected),
                                                    style: TextStyle(
                                                      fontFamily: 'Comfortaa',
                                                      fontSize: 13,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 4,
                                      bottom: 4,
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: Icon(
                                            Icons.delete,
                                            color: Colors.grey[600],
                                            size: 16,
                                          ),
                                          onPressed: () {
                                            // Show confirmation dialog before deleting
                                            showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  title: Text('Delete Chat'),
                                                  content: Text(
                                                    'Are you sure you want to delete "${chatSession.title}"?',
                                                  ),
                                                  actions: <Widget>[
                                                    TextButton(
                                                      child: Text('Cancel'),
                                                      onPressed: () {
                                                        Navigator.of(
                                                          context,
                                                        ).pop();
                                                      },
                                                    ),
                                                    TextButton(
                                                      child: Text('Delete'),
                                                      onPressed: () {
                                                        Navigator.of(
                                                          context,
                                                        ).pop();
                                                        _deleteChat(chatId);
                                                      },
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        // QR Code button at the bottom
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          child: ElevatedButton(
                            onPressed: () async {
                              _closeSidebar();
                              // Open QR scanner screen
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => QRScannerScreen(),
                                ),
                              );
                              // Process the scanned QR code and create a new chat
                              await _processScannedQrCode();
                              // Refresh the saved QR URL when returning from the scanner
                              _refreshUserName();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.black,
                                  width: 1.5,
                                ),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              minimumSize: Size(double.infinity, 50),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.qr_code_scanner,
                                  color: Colors.black,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Scan QR Code',
                                  style: TextStyle(
                                    fontFamily: 'Comfortaa',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Method to select images
  Future<void> _selectImages() async {
    try {
      // Check if we've reached the limit of 3 images
      if (_selectedImagePaths.length >= 3) {
        // Show a message to the user
        return;
      }

      // Pick multiple images
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage();

      if (pickedFiles.isNotEmpty) {
        // Calculate how many more images we can add
        final int remainingSlots = 3 - _selectedImagePaths.length;
        final int imagesToAdd = pickedFiles.length > remainingSlots
            ? remainingSlots
            : pickedFiles.length;

        // Add the selected images to our list
        setState(() {
          for (int i = 0; i < imagesToAdd; i++) {
            _selectedImagePaths.add(pickedFiles[i].path);
          }
        });
      }
    } catch (e) {
      print('Error selecting images: $e');
    }
  }

  // Method to remove an image
  void _removeImage(int index) {
    setState(() {
      _selectedImagePaths.removeAt(index);
    });
  }

  // Removed _fetchEventsFromServer as it's backend dependent

  // Add a method to refresh the username from SharedPreferences
  Future<void> _refreshUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('SharedPreferences initialization timed out');
          throw TimeoutException(
            'SharedPreferences timeout',
            Duration(seconds: 5),
          );
        },
      );
      setState(() {
        _userName = prefs.getString('user_name') ?? 'User';
        _savedQrUrl = prefs.getString('scanned_qr_url') ?? '';
        _profileImagePath =
            prefs.getString('profile_image_path') ?? ''; // Add this line
      });
      print('Username refreshed: $_userName');
      print('Saved QR URL refreshed: $_savedQrUrl');
      print(
        'Profile image path refreshed: $_profileImagePath',
      ); // Add this line

      // Removed home widget update
    } catch (e) {
      print('Error refreshing username: $e');
      // Keep current username if there's an error
    }
  }

  /// Clear the saved QR code URL
  Future<void> _clearSavedQrUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('scanned_qr_url');
      setState(() {
        _savedQrUrl = '';
      });
      print('Cleared saved QR URL');
    } catch (e) {
      print('Error clearing saved QR URL: $e');
    }
  }

  Future<void> _processScannedQrCode() async {
    try {
      await _loadSavedQrUrl();
      if (_savedQrUrl.isNotEmpty) {
        // Create a new chat session for the scanned peer
        await _createChatForScannedUser(_savedQrUrl);
        await _clearSavedQrUrl();
      }
    } catch (e) {
      print('Error processing scanned QR code: $e');
    }
  }

  Future<void> _createChatForScannedUser(String peerInfo) async {
    try {
      // Parse peer info - could be JSON (new format) or legacy UUID string
      String peerName = peerInfo;
      String peerUuid = peerInfo;
      String? profileImagePath;

      try {
        final jsonData = jsonDecode(peerInfo);
        if (jsonData is Map<String, dynamic>) {
          // New format with structured user data
          peerName = jsonData['name'] as String? ?? peerInfo;
          peerUuid = jsonData['uuid'] as String? ?? peerInfo;
          profileImagePath = jsonData['profileImage'] as String?;
          print('Parsed QR data - name: $peerName, uuid: $peerUuid');
        }
      } catch (e) {
        // Not JSON format, use legacy behavior (peerInfo is the UUID)
        print('Legacy QR format detected');
        peerName = peerInfo;
        peerUuid = peerInfo;
      }

      // Generate a unique chat ID based on peer UUID
      final chatId = 'chat_${peerUuid.hashCode}';

      if (_chatSessions.containsKey(chatId)) {
        setState(() {
          _currentChatId = chatId;
          _messages.clear();
          _messages.addAll(_chatSessions[chatId]!.messages);
          _showNoteMessage = _messages.isEmpty;
        });
        return;
      }

      // Create new chat session for the P2P peer
      final newSession = ChatSession(
        id: chatId,
        title: peerName.isNotEmpty ? peerName : 'Unknown User', // Use parsed name as title
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
        recipientId: peerUuid,
        peerName: peerName,
        peerUuid: peerUuid,
        profileImageBase64: null, // Will be updated when peer connects
        messages: [],
      );

      setState(() {
        _chatSessions[chatId] = newSession;
        if (!_chatList.contains(chatId)) {
          _chatList.add(chatId);
        }
        _currentChatId = chatId;
        _messages.clear();
        _messages.addAll(newSession.messages);
        _showNoteMessage = _messages.isEmpty;
      });

      await _saveChatSessions();
    } catch (e) {
      print('Error creating chat for scanned peer: $e');
    }
  }

  // Removed _verifyUserExists and _fetchUserProfile as they're backend dependent

  // Method to open the sidebar
  void _openSidebar() {
    _sidebarController.forward();
  }

  // Method to close the sidebar
  void _closeSidebar() {
    _sidebarController.reverse();
  }

  // Listener for text changes to update UI
  void _onTextChanged() {
    // This will trigger a rebuild when text changes, allowing the icon to switch
    setState(() {});
  }

  Future<bool> _loadVoiceToSpeechSetting() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('voice_to_speech_enabled') ?? true;
  }

  // WebRTC Call methods
  void _startCall() async {
    if (_currentChatId == QUERYSPACE_CHAT_ID || _currentChatId.isEmpty) return;

    // Find the correct endpoint for the current peer chat
    String? targetEndpointId;
    final chatSession = _chatSessions[_currentChatId];
    if (chatSession != null) {
      if (_peerEndpointMap.containsKey(chatSession.peerUuid)) {
        targetEndpointId = _peerEndpointMap[chatSession.peerUuid];
      } else if (_peerEndpointMap.containsKey(chatSession.peerName)) {
        targetEndpointId = _peerEndpointMap[chatSession.peerName];
      } else if (_connectedEndpointId.isNotEmpty) {
        targetEndpointId = _connectedEndpointId;
      }
    }

    if (targetEndpointId == null || targetEndpointId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Peer is not connected. Please ensure they are in range.')),
      );
      return;
    }

    // Show calling dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Column(
          children: [
            _buildPeerAvatar(chatSession, 40),
            const SizedBox(height: 16),
            Text(
              'Calling ${chatSession?.title ?? "User"}...',
              style: const TextStyle(fontFamily: 'Comfortaa', fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Establishing Peer-to-Peer Connection...',
              style: TextStyle(fontFamily: 'Comfortaa', fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Colors.black),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _webrtcService.dispose();
              Navigator.pop(context);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    try {
      await _webrtcService.initRenderers();
      await _webrtcService.initPeerConnection();

      // Set up signaling callback to send to the correct endpoint
      _webrtcService.onSignalingMessage = (signal) {
        if (targetEndpointId != null && targetEndpointId.isNotEmpty) {
          _p2pService.sendMessage(targetEndpointId, {
            'type': 'webrtc_signal',
            'signal': signal,
          });
        }
      };

      await _webrtcService.createOffer();
    } catch (e) {
      print('Error starting WebRTC call: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start call: $e')),
        );
      }
    }
  }

  Widget _buildPeerAvatar(ChatSession? chatSession, double size) {
    if (chatSession != null && chatSession.profileImageBase64 != null && chatSession.profileImageBase64!.isNotEmpty) {
      return ClipOval(
        child: Image.memory(
          base64Decode(chatSession.profileImageBase64!),
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    // Fallback to initial
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.grey[300],
      child: Text(
        (chatSession?.title ?? 'U')[0].toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black,
          fontFamily: 'Comfortaa',
          fontSize: size / 2,
        ),
      ),
    );
  }

  void _showIncomingCallDialog(String endpointId, Map<String, dynamic> offer) {
    String peerName = _discoveredDevices[endpointId] ?? 'Unknown Peer';

    // Find the chat session for this peer to get their profile image
    ChatSession? peerChat;
    for (var entry in _chatSessions.entries) {
      if (entry.value.peerName == peerName || entry.value.recipientId == peerName) {
        peerChat = entry.value;
        break;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Column(
          children: [
            _buildPeerAvatar(peerChat, 48),
            const SizedBox(height: 16),
            Text('Incoming Call from $peerName',
              style: const TextStyle(fontFamily: 'Comfortaa', fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: const Text(
          'Would you like to accept the peer-to-peer voice/video call?',
          style: TextStyle(fontFamily: 'Comfortaa'),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Reject logic could go here
            },
            child: const Text('Decline', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _webrtcService.initRenderers();
                await _webrtcService.initPeerConnection();

                // Set up signaling callback
                _webrtcService.onSignalingMessage = (signal) {
                  if (endpointId.isNotEmpty) {
                    _p2pService.sendMessage(endpointId, {
                      'type': 'webrtc_signal',
                      'signal': signal,
                    });
                  }
                };

                await _webrtcService.handleSignal(offer);
              } catch (e) {
                print('Error accepting call: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Accept', style: TextStyle(fontFamily: 'Comfortaa', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ChatSession moved to models.dart
