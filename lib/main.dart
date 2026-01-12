import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
// Add audio recording dependencies
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'profile.dart'; // Add profile page
// Add local notifications
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// Add speech to text
import 'package:speech_to_text/speech_to_text.dart' as stt;
// Add animation
import 'package:flutter/animation.dart';
// Add transitions
import 'package:flutter/widgets.dart';
// Add device info
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // Add MethodChannel
import 'dart:io'; // Add this import for File
import 'package:image_picker/image_picker.dart'; // Add image picker
import 'package:flutter_image_compress/flutter_image_compress.dart'; // Add image compression
import 'package:socket_io_client/socket_io_client.dart' as socketio;

// Add splash screen
import 'splash_screen.dart';
// Add QR scanner
import 'qr_scanner.dart';
// Add authentication screen
import 'auth_screen.dart';
import 'config.dart'; // Import config file

// Import the QR popup widget
import 'widgets/qr_popup.dart';

// Method channel for handling Android widget broadcasts
const MethodChannel platform = MethodChannel(
  'com.example.my_space_connect/widget',
);

// Hardcoded key for storing user email
const String USER_EMAIL_KEY = AppConfig.USER_EMAIL_KEY;

// QuerySpace chat ID
const String QUERYSAPCE_CHAT_ID = 'queryspace_help_chat';
const String QUERYSPACE_CHAT_ID = 'queryspace_help_chat';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  bool _hasShownPermissionsDialog = false;
  bool _biometricAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Check if user is already authenticated
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString(USER_EMAIL_KEY) ?? '';
      setState(() {
        _isAuthenticated = userEmail.isNotEmpty;
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
    // Get user data from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString(USER_EMAIL_KEY) ?? '';
    final userUid = prefs.getString('user_uid') ?? '';

    // Call server logout endpoint
    if (userEmail.isNotEmpty && userUid.isNotEmpty) {
      try {
        final headers = <String, String>{'Content-Type': 'application/json'};

        // Add JWT token if available
        final token = prefs.getString('auth_token');
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }

        // For logout, we'll use the default server URL since it's a simple operation
        await http.post(
          Uri.parse('${AppConfig.SERVER_URL}/api/auth/logout'),
          headers: headers,
          body: jsonEncode({'uid': userUid, 'email': userEmail}),
        );
      } catch (e) {
        print('Error calling logout endpoint: $e');
      }
    }

    // Clear all user-related data from SharedPreferences
    await prefs.remove(USER_EMAIL_KEY);
    await prefs.remove('user_uid');
    await prefs.remove('user_name');
    await prefs.remove('user_name_saved');
    await prefs.remove('profile_image_path');
    await prefs.remove('scanned_qr_url');
    await prefs.remove('chat_list');
    await prefs.remove('auth_token'); // Remove JWT token

    // Clear all chat data
    final String? chatListJson = prefs.getString('chat_list');
    if (chatListJson != null) {
      try {
        final List<dynamic> chatListData = json.decode(chatListJson);
        for (String chatId in chatListData) {
          await prefs.remove('chat_$chatId');
        }
      } catch (e) {
        print('Error clearing chat data: $e');
      }
    }

    // Update authentication state
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

class Message {
  final int id;
  String text; // Make text mutable for streaming updates
  final bool isUser;
  final DateTime timestamp;
  final bool isAudio; // New field to identify audio messages

  Message({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isAudio = false, // Default to false for text messages
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch,
      text: json['text'] ?? '',
      isUser: json['isUser'] ?? false,
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      isAudio: json['isAudio'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'isAudio': isAudio,
    };
  }
}

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
  bool _isInitialized = false; // New flag to track initialization status
  bool _initError = false; // New flag to track initialization errors
  bool _isConnected = false; // New flag to track server connection status
  String _initErrorMessage = ''; // To store error message

  // Caching mechanism for messages
  final Map<String, List<Message>> _cachedMessages = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);
  int _lastUpdateId = 0;
  socketio.Socket? _socket; // Socket.IO client
  static const int CHAT_ID = int.fromEnvironment(
    'CHAT_ID',
    defaultValue: 1767023771,
  ); // Configurable chat ID

  // User ID - will be set from server or SharedPreferences
  String _userUid = '';

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
  String get _apiUrl {
    // If we have a saved QR URL, use it as the base for API calls
    if (_savedQrUrl.isNotEmpty) {
      // The QR code contains the base server URL, so we just need to ensure it doesn't end with a slash
      if (_savedQrUrl.endsWith('/')) {
        return _savedQrUrl.substring(0, _savedQrUrl.length - 1);
      } else {
        return _savedQrUrl;
      }
    }
    // Fallback to the default API URL (remove /api since we append it in individual calls)
    String defaultUrl = String.fromEnvironment(
      'API_URL',
      defaultValue: AppConfig.SERVER_URL, // Deployed URL
    );
    // Remove /api suffix if present
    if (defaultUrl.endsWith('/api')) {
      return defaultUrl.substring(0, defaultUrl.length - 4); // Remove '/api'
    } else if (defaultUrl.endsWith('/api/')) {
      return defaultUrl.substring(0, defaultUrl.length - 5); // Remove '/api/'
    }
    return defaultUrl;
  }

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
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
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

    // Initialize Socket.IO connection
    _initializeSocketIO();

    // Start periodic connection status checks
    Timer.periodic(Duration(seconds: 30), (timer) {
      _updateConnectionStatus();
    });

    // Start periodic Socket.IO connection checks
    Timer.periodic(Duration(seconds: 60), (timer) {
      // Check if Socket.IO is connected, reconnect if not
      if (_socket != null && !_socket!.connected) {
        print('Socket.IO not connected, attempting to reconnect...');
        _reconnectSocketIO();
      }
    });

    // Start periodic message fetching with better error handling
    Timer.periodic(Duration(seconds: 15), (timer) {
      // Only fetch messages when app is in foreground to save battery
      bool isForeground =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (isForeground) {
        _fetchMessages().catchError((error) {
          print('Error in periodic message fetch: $error');
        });
      }
    });

    // Start periodic notification polling with better error handling
    _notificationTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _fetchNotifications().catchError((error) {
        print('Error in periodic notification fetch: $error');
      });
    });

    // Add listener to text controller to update UI when text changes
    _textController.addListener(_onTextChanged);

    // Removed MethodChannel handler for Android widget broadcasts
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
      _fetchMessages();
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
      // Disconnect Socket.IO
      if (_socket != null && _socket!.connected) {
        _socket!.disconnect();
      }
    }
  }

  Future<void> _initializeNotifications() async {
    // Initialize the Flutter Local Notifications plugin
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap when app is in background/killed
        print('Notification tapped: ${response.payload}');
        // Navigate to chat screen or perform relevant action
      },
    );

    // Request notification permissions
    await _requestNotificationPermissions();
  }

  Future<void> _requestNotificationPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  Future<void> _showNotification(String title, String body) async {
    // Check if app is in foreground
    bool isForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'my_chat_channel',
          'My Chat Channel',
          channelDescription: 'Channel for chat notifications',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          // Enable heads-up notification for immediate attention
          enableLights: true,
          enableVibration: true,
          // Show notification even when app is in foreground
          showWhen: true,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch %
          1000000, // Unique ID for each notification
      title,
      body,
      platformChannelSpecifics,
      payload: 'chat_notification', // Payload for handling notification taps
    );
  }

  // Initialize Socket.IO connection
  void _initializeSocketIO() async {
    try {
      // Get user data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString(USER_EMAIL_KEY) ?? '';
      final userUid = prefs.getString('user_uid') ?? '';
      final userName = prefs.getString('user_name') ?? 'User';

      if (userEmail.isNotEmpty && userUid.isNotEmpty) {
        // Create Socket.IO connection with reconnection options
        _socket =
            socketio.io('$_apiUrl', <String, dynamic>{
                  'transports': ['websocket'],
                  'autoConnect': false,
                  'reconnection': true,
                  'reconnectionAttempts': 5,
                  'reconnectionDelay': 1000,
                  'reconnectionDelayMax': 5000,
                  'randomizationFactor': 0.5,
                  'timeout': 20000,
                })
                as socketio.Socket?;

        // Listen for connection events
        _socket!.on('connect', (_) {
          print('Socket.IO connected');
          if (mounted) {
            setState(() {
              _isConnected = true;
            });
          }

          // Join room with user data when connected
          _socket!.emit('join', {
            'userId': userUid,
            'email': userEmail,
            'name': userName,
          });
        });

        _socket!.on('disconnect', (reason) {
          print('Socket.IO disconnected: $reason');
          if (mounted) {
            setState(() {
              _isConnected = false;
            });
          }

          // Attempt to reconnect if disconnected unexpectedly
          if (reason != 'io client disconnect') {
            print('Attempting to reconnect...');
            Future.delayed(Duration(seconds: 2), () {
              if (_socket != null && !_socket!.connected) {
                _socket!.connect();
              }
            });
          }
        });

        _socket!.on('connect_error', (error) {
          print('Socket.IO connection error: $error');
        });

        _socket!.on('reconnect', (attemptNumber) {
          print('Socket.IO reconnected after $attemptNumber attempts');
        });

        _socket!.on('reconnect_attempt', (attemptNumber) {
          print('Socket.IO reconnect attempt #$attemptNumber');
        });

        _socket!.on('reconnect_failed', (_) {
          print('Socket.IO failed to reconnect');
        });

        // Listen for new messages
        _socket!.on('newMessage', (data) async {
          print('Received new message via Socket.IO: $data');

          // Add message to UI
          if (mounted) {
            final message = Message(
              id: data['id'] ?? DateTime.now().millisecondsSinceEpoch,
              text: data['message'] ?? '',
              isUser: false, // This is a received message
              timestamp: DateTime.parse(
                data['timestamp'] ?? DateTime.now().toIso8601String(),
              ),
            );

            // Get sender information from the message data
            final fromUserId = data['fromUserId'] as String?;
            final senderEmail = data['fromUserEmail'] as String?;
            final senderName = data['fromUserName'] as String?;
            final profileImageBase64 = data['fromUserProfileImage'] as String?;

            // If we have sender email and this is a new user, create a chat session for them
            if (senderEmail != null && senderEmail.isNotEmpty) {
              final chatId = 'chat_${senderEmail.hashCode}';

              // Check if chat session already exists
              if (!_chatSessions.containsKey(chatId)) {
                // Create new chat session for the sender
                final chatTitle = senderName ?? senderEmail.split('@')[0];

                final newSession = ChatSession(
                  id: chatId,
                  title: chatTitle,
                  createdAt: DateTime.now(),
                  lastUpdated: DateTime.now(),
                  recipientEmail: senderEmail,
                  profileImageBase64: profileImageBase64,
                  messages: [],
                );

                setState(() {
                  // Add new chat session
                  _chatSessions[chatId] = newSession;

                  // Add to chat list if not already present
                  if (!_chatList.contains(chatId)) {
                    _chatList.add(chatId);
                  }
                });

                // Save all chat sessions
                await _saveChatSessions();
              } else if (profileImageBase64 != null) {
                // Update existing chat session with profile image if it wasn't set before
                setState(() {
                  _chatSessions[chatId] = _chatSessions[chatId]!.copyWith(
                    profileImageBase64: profileImageBase64,
                  );
                });

                // Save updated chat session
                await _saveChatSessions();
              }

              // If this is the current chat, update the messages
              if (_currentChatId == chatId) {
                setState(() {
                  _messages.add(message);
                  _scrollToBottom();
                });

                // Save chat to persist the new message
                await _saveCurrentChat();
              } else {
                // If this is not the current chat, just add to the chat session
                final updatedSession = _chatSessions[chatId]!.copyWith(
                  messages: List.from(_chatSessions[chatId]!.messages)
                    ..add(message),
                  lastUpdated: DateTime.now(),
                );

                setState(() {
                  _chatSessions[chatId] = updatedSession;
                });

                // Save updated chat session
                await _saveChatSessions();
              }
            } else {
              // For existing chat or QuerySpace, add message to current display
              setState(() {
                _messages.add(message);
                _scrollToBottom();
              });

              // Save chat to persist the new message
              await _saveCurrentChat();
            }

            // Show notification for new message
            _showNotification(
              'New Message',
              data['message'] ?? 'You received a new message',
            );
          }
        });

        // Listen for message delivery confirmation
        _socket!.on('messageSent', (data) {
          print('Message sent confirmation: $data');
          // Handle message sent confirmation if needed
        });

        // Listen for user join events
        _socket!.on('userJoined', (data) {
          print('User joined: $data');
          // Handle user join events if needed
        });

        // Connect to server
        _socket!.connect();
      }
    } catch (e) {
      print('Error initializing Socket.IO: $e');
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

      // Check initial connection status
      await _updateConnectionStatus();

      setState(() {
        _isInitialized = true;
        _initError = false;
      });

      print('App initialization complete');
    } catch (e, s) {
      print('Error during app initialization: $e');
      print('Stack trace: $s');
      setState(() {
        _isInitialized = true;
        _initError = true;
        _initErrorMessage = e.toString();
      });
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
      final greetings = ['Hey!', 'Hi there!', 'Hello!', 'Great question!'];
      final connectors = [
        'Here\'s how:',
        'Let me explain:',
        'I can help with that:',
        'Sure thing!',
        'Absolutely!',
      ];
      final random = Random();
      return '${greetings[random.nextInt(greetings.length)]} '
          '${connectors[random.nextInt(connectors.length)]}\n\n$response';
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
        'Hello there! 👋 Welcome to QuerySpace. How can I help you today?',
        'Hi! Nice to see you here. What would you like to know about the app?',
        'Hey! I\'m your QuerySpace assistant. Ready to help you explore the app!',
        'Greetings! I\'m here to guide you through QuerySpace. What\'s on your mind?',
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
        '• Managing your profile and settings\n'
        '• Navigating your chats and history\n'
        '• Troubleshooting any issues\n\n'
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
        'Connecting with others is super easy with QR codes! Here\'s the simple process:\n\n'
        '1. **Go to your Profile** (bottom right icon)\n'
        '2. **Tap your QR code** to see/share your personal code\n'
        '3. **To add someone:** Tap the scan icon and point at their QR code\n'
        '4. **To share yours:** Show your phone screen or share the code image\n\n'
        '💡 **Tip:** You can also save your QR as an image to share anytime!',
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
        '• **Start a chat:** Tap any contact from your main list\n'
        '• **Type a message:** Use the text box at the bottom\n'
        '• **Send voice notes:** Hold 🎤 and speak (release to send)\n'
        '• **Share images:** Tap 📎 to select photos\n'
        '• **See status:** Blue check = sent, Double check = delivered\n\n'
        'Everything happens in real-time, so you\'ll see messages instantly!',
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
        '   - View your unique QR code\n\n'
        '👥 **Connections:**\n'
        '   - See all your contacts\n'
        '   - Check connection status\n'
        '   - Manage chat histories\n\n'
        'Just tap the Profile tab to get started!',
      );
    }

    // History/viewing
    if (input.contains('history') ||
        input.contains('view') ||
        input.contains('previous') ||
        input.contains('old') ||
        input.contains('past chat')) {
      return personalize(
        'Looking for past conversations? No problem!\n\n'
        '• **All your chats** are saved automatically\n'
        '• **Scroll up** in any chat to see older messages\n'
        '• **Search feature:** Coming soon to find specific messages\n'
        '• **Media history:** Images and files are organized by date\n\n'
        'Your chat history stays private and only visible to you.',
      );
    }

    // Voice messages
    if (input.contains('voice') ||
        input.contains('audio') ||
        input.contains('record') ||
        input.contains('mic') ||
        input.contains('speak')) {
      return personalize(
        'Voice messages make chatting more personal! Here\'s how they work:\n\n'
        '🎤 **To record:**\n'
        '   1. Press and hold the microphone button\n'
        '   2. Speak your message (you\'ll see the waveform)\n'
        '   3. Release to send immediately\n'
        '   4. Swipe left to cancel if needed\n\n'
        '🔊 **To listen:**\n'
        '   • Tap any voice message to play\n'
        '   • Adjust volume with your phone buttons\n'
        '   • Messages auto-play in order when tapped',
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
        '   2. Select "Gallery" or "Photos"\n'
        '   3. Choose up to 3 images at once\n'
        '   4. Add a caption if you want\n'
        '   5. Tap send to share!\n\n'
        '🖼️ **Viewing images:**\n'
        '   • Tap any image to view full screen\n'
        '   • Pinch to zoom in/out\n'
        '   • Swipe to see other images in the chat',
      );
    }

    // Thanks/gratitude
    if (input.contains('thank') ||
        input.contains('thanks') ||
        input.contains('appreciate') ||
        input.contains('helpful')) {
      final responses = [
        'You\'re very welcome! 😊 Happy to help. Is there anything else you\'d like to know?',
        'My pleasure! Let me know if you have any other questions about QuerySpace.',
        'Glad I could help! Feel free to ask if anything else comes to mind.',
        'Anytime! I\'m here whenever you need guidance with the app.',
      ];
      return responses[Random().nextInt(responses.length)];
    }

    // Farewells
    if (input.contains('bye') ||
        input.contains('goodbye') ||
        input.contains('see you') ||
        input.contains('later')) {
      final responses = [
        'Goodbye! 👋 Enjoy using QuerySpace!',
        'See you later! Happy chatting!',
        'Bye for now! Don\'t hesitate to come back with questions.',
        'Take care! Remember I\'m here if you need help.',
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
      return 'That\'s wonderful to hear! 😄 I\'m glad you\'re enjoying QuerySpace. '
          'Is there something specific you\'d like me to explain?';
    }

    // Default response with engagement
    final defaultResponses = [
      'I\'d love to help you with that! Could you tell me a bit more about what you\'re looking for?',
      'That\'s a great question! To give you the best answer, could you specify which part of the app you mean?',
      'I can help with various QuerySpace features! Are you wondering about messaging, profiles, QR codes, or something else?',
      'Let me help you navigate QuerySpace! What specific feature would you like to learn about?',
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

      // Load chat list
      final String? chatListJson = prefs.getString('chat_list');
      if (chatListJson != null) {
        try {
          final List<dynamic> chatListData = json.decode(chatListJson);
          _chatList.clear();
          _chatList.addAll(List<String>.from(chatListData));
          print('Loaded chat list with ${_chatList.length} chats');
        } catch (e) {
          print('Error parsing chat list: $e');
          _chatList.clear();
        }
      }

      // Load each chat session
      for (String chatId in _chatList) {
        try {
          final String? chatJson = prefs.getString('chat_$chatId');
          if (chatJson != null) {
            final Map<String, dynamic> chatData = json.decode(chatJson);
            final ChatSession chatSession = ChatSession.fromJson(chatData);
            _chatSessions[chatId] = chatSession;
            print(
              'Loaded chat session $chatId with ${chatSession.messages.length} messages',
            );

            // For chats with recipients, fetch updated profile data if needed
            if (chatSession.recipientEmail != null &&
                chatSession.recipientEmail!.isNotEmpty &&
                chatId != QUERYSPACE_CHAT_ID) {
              // Fetch updated user profile data
              final userProfile = await _fetchUserProfile(
                chatSession.recipientEmail!,
              );
              if (userProfile != null) {
                final displayName = userProfile['displayName'] as String?;
                final profileImageBase64 =
                    userProfile['profileImageBase64'] as String?;

                // Update chat session if profile data has changed
                bool needsUpdate = false;
                String newTitle = chatSession.title;
                String? newProfileImage = chatSession.profileImageBase64;

                if (displayName != null && displayName != chatSession.title) {
                  newTitle = displayName;
                  needsUpdate = true;
                }

                if (profileImageBase64 != null &&
                    profileImageBase64 != chatSession.profileImageBase64) {
                  newProfileImage = profileImageBase64;
                  needsUpdate = true;
                }

                if (needsUpdate) {
                  _chatSessions[chatId] = chatSession.copyWith(
                    title: newTitle,
                    profileImageBase64: newProfileImage,
                  );
                }
              }
            }
          }
        } catch (e) {
          print('Error loading chat session $chatId: $e');
          // Remove corrupted chat session
          _chatList.remove(chatId);
        }
      }

      print('Loaded ${_chatSessions.length} chat sessions from storage');

      // Save updated chat sessions if any changes were made
      await _saveChatSessions();

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
    } catch (e) {
      print('Error loading chat sessions: $e');
      // Continue with empty chat sessions list if there's an error
      // Ensure note is shown for empty chat
      _showNoteMessage = true;
    }
  }

  Future<void> _saveChatSessions() async {
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

      // Save chat list
      await prefs.setString('chat_list', json.encode(_chatList));

      // Save each chat session
      for (String chatId in _chatList) {
        if (_chatSessions.containsKey(chatId)) {
          await prefs.setString(
            'chat_$chatId',
            json.encode(_chatSessions[chatId]!.toJson()),
          );
        }
      }

      print('Saved ${_chatSessions.length} chat sessions to storage');
    } catch (e) {
      print('Error saving chat sessions: $e');
      // Continue without saving if there's an error
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

  /// Test network connectivity to our server API
  Future<bool> _testNetworkConnectivity() async {
    try {
      final url = Uri.parse('${_apiUrl}/health');
      final response = await http.get(url).timeout(Duration(seconds: 10));
      print('Network test response status: ${response.statusCode}');
      print('Network test response body: ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('Network test failed: $e');
      return false;
    }
  }

  /// Update the connection status indicator
  Future<void> _updateConnectionStatus() async {
    final isConnected = await _testNetworkConnectivity();
    if (mounted) {
      setState(() {
        _isConnected = isConnected;
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    // Check if there's an active chat
    if (_currentChatId.isEmpty) {
      // If no active chat, ensure QuerySpace exists and make it active
      if (!_isQuerySpaceExists()) {
        await _openOrCreateQuerySpace();
      } else {
        // If QuerySpace exists, make it active
        setState(() {
          _currentChatId = QUERYSPACE_CHAT_ID;
          _messages.clear();
          _messages.addAll(_chatSessions[QUERYSPACE_CHAT_ID]!.messages);
        });
      }
    }

    if (text.trim().isEmpty && _selectedImagePaths.isEmpty) return;

    // Hide note if this is the first message
    if (_messages.isEmpty && _showNoteMessage) {
      _dismissNote();
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Add user message to UI immediately
      final isAudioMessage = text.startsWith('[AUDIO');
      final userMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch,
        text: text.isNotEmpty ? text : '[Image]',
        isUser: true,
        timestamp: DateTime.now(),
        isAudio: isAudioMessage,
      );

      setState(() {
        _messages.add(userMessage);
        _textController.clear();
        // Clear selected images after sending
        _selectedImagePaths.clear();
      });

      _scrollToBottom();
      _saveCurrentChat();

      // Get user data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userEmail =
          prefs.getString(
            'fbba7f175ebcb54045564072f6a79bcb61fd9b05ab10f8101f8cbfcbc8ae0780',
          ) ??
          '';

      // Use persistent user UID
      String senderUid = _userUid;

      // If userUid is empty, try to fetch it from the server
      if (senderUid.isEmpty && userEmail.isNotEmpty) {
        try {
          final userResponse = await http.get(
            Uri.parse(
              '${_apiUrl}/api/user-by-email/${Uri.encodeComponent(userEmail)}',
            ),
          );

          if (userResponse.statusCode == 200) {
            final userData = jsonDecode(userResponse.body);
            senderUid = userData['uid'] as String;
            // Save the UID for future use
            _userUid = senderUid;
            await prefs.setString('user_uid', senderUid);
          }
        } catch (e) {
          print('Error fetching sender UID: $e');
        }
      }

      // Determine recipient based on current chat
      String? recipientEmail;
      if (_chatSessions.containsKey(_currentChatId) &&
          _chatSessions[_currentChatId]!.recipientEmail != null) {
        recipientEmail = _chatSessions[_currentChatId]!.recipientEmail;
      } else {
        // Fallback to default recipient for QuerySpace or other special chats
        recipientEmail = 'default_recipient@example.com';
      }

      // Fetch the recipient's actual UID from the server
      String recipientUid =
          'uid_${recipientEmail.hashCode}'; // Default fallback
      if (recipientEmail != 'default_recipient@example.com' &&
          recipientEmail != null) {
        try {
          final headers = await _getAuthHeaders();
          final userResponse = await http.get(
            Uri.parse(
              '${_apiUrl}/api/user-by-email/${Uri.encodeComponent(recipientEmail)}',
            ),
            headers: headers,
          );

          if (userResponse.statusCode == 200) {
            final userData = jsonDecode(userResponse.body);
            recipientUid = userData['uid'] as String;
          }
        } catch (e) {
          print('Error fetching recipient UID: $e');
          // Fall back to the hash-based UID if server lookup fails
        }
      }

      // Prepare message content
      String messageContent = text;
      if (_selectedImagePaths.isNotEmpty) {
        // If we have images, upload them and include them in the message
        messageContent = '[IMAGE]${text.isNotEmpty ? ': $text' : ''}';

        // For each image, upload to server and get image ID
        for (int i = 0; i < _selectedImagePaths.length; i++) {
          final imagePath = _selectedImagePaths[i];
          try {
            // Read image file
            final imageFile = File(imagePath);

            // Compress image
            final compressedImage = await FlutterImageCompress.compressWithFile(
              imageFile.absolute.path,
              minWidth: 800,
              minHeight: 600,
              quality: 80,
            );

            // Convert to base64
            final imageBase64 = base64Encode(compressedImage!);

            // Upload image to server
            final headers = await _getAuthHeaders();
            final uploadResponse = await http.post(
              Uri.parse('${_apiUrl}/api/upload-image'),
              headers: headers,
              body: jsonEncode({
                'imageData': imageBase64,
                'fileName':
                    'image_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
              }),
            );

            if (uploadResponse.statusCode == 200) {
              final uploadData = jsonDecode(uploadResponse.body);
              final imageId = uploadData['imageId'];

              // Update message content to include image ID
              messageContent =
                  '[IMAGE:$imageId]${text.isNotEmpty ? ': $text' : ''}';

              // For multiple images, we'll just use the last one for simplicity
              // In a real app, you'd want to handle multiple images differently
              break;
            }
          } catch (e) {
            print('Error uploading image: $e');
          }
        }
      }

      // Special handling for QuerySpace - use hardcoded responses
      if (_currentChatId == QUERYSPACE_CHAT_ID) {
        // Simulate processing delay
        await Future.delayed(const Duration(seconds: 1));

        // Generate hardcoded response based on user input
        String responseText = _generateQuerySpaceResponse(text);

        // Create response message
        final responseMessage = Message(
          id: DateTime.now().millisecondsSinceEpoch + 1,
          text: responseText,
          isUser: false,
          timestamp: DateTime.now(),
        );

        setState(() {
          _messages.add(responseMessage);
        });

        _scrollToBottom();
        await _saveCurrentChat();
      } else {
        // Send message via Socket.IO for real-time communication
        if (_socket != null && _socket!.connected) {
          // Emit message through Socket.IO
          _socket!.emit('sendMessage', {
            'fromUserId': senderUid,
            'toUserId': recipientUid,
            'message': messageContent,
          });

          print('Message sent via Socket.IO');

          // For real-time chat, we don't need to simulate a response
          // The recipient will receive it via Socket.IO 'newMessage' event
        } else {
          // Fallback to HTTP API if Socket.IO is not connected
          print('Socket.IO not connected, falling back to HTTP');
          final headers = await _getAuthHeaders();
          final response = await http.post(
            Uri.parse('${_apiUrl}/api/user-message'),
            headers: headers,
            body: jsonEncode({
              'fromUserId': senderUid,
              'toUserId': recipientUid,
              'message': messageContent,
            }),
          );

          if (response.statusCode == 200) {
            final responseData = jsonDecode(response.body);
            print('Message sent successfully: ${responseData['messageId']}');
          } else {
            throw Exception('Failed to send message: ${response.body}');
          }
        }

        // Save current chat after sending message
        await _saveCurrentChat();
      }
    } catch (e) {
      print('Error sending message: $e');

      // Create a simple error message
      final errorMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch + 1,
        text: 'Sorry, I encountered an error. Please try again.',
        isUser: false,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(errorMessage);
      });

      _scrollToBottom();
      await _saveCurrentChat();
    } finally {
      setState(() {
        _isLoading = false;
      });
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
    } else {
      print('No chat session found for $_currentChatId');
    }
  }

  // Reconnect Socket.IO connection
  Future<void> _reconnectSocketIO() async {
    if (_socket != null) {
      try {
        print('Reconnecting Socket.IO...');
        _socket!.disconnect();
        await Future.delayed(Duration(milliseconds: 500));
        _socket!.connect();
        print('Socket.IO reconnection initiated');
      } catch (e) {
        print('Error reconnecting Socket.IO: $e');
      }
    }
  }

  // Helper function to get authorization headers with JWT token
  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final headers = <String, String>{'Content-Type': 'application/json'};

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // Load user UID from SharedPreferences
  Future<void> _loadUserUid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userUid = prefs.getString('user_uid') ?? '';

      // If no UID found, try to fetch from server
      if (_userUid.isEmpty) {
        final userEmail = prefs.getString(USER_EMAIL_KEY) ?? '';
        if (userEmail.isNotEmpty) {
          await _fetchAndSaveUserUid(userEmail);
        }
      }

      print('Loaded user UID: $_userUid');
    } catch (e) {
      print('Error loading user UID: $e');
    }
  }

  // Fetch and save user UID from server
  Future<void> _fetchAndSaveUserUid(String userEmail) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${_apiUrl}/api/user-by-email/${Uri.encodeComponent(userEmail)}',
        ),
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        _userUid = userData['uid'] as String;

        // Save the UID for future use
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_uid', _userUid);
        print('Fetched and saved user UID: $_userUid');
      }
    } catch (e) {
      print('Error fetching user UID: $e');
    }
  }

  // Load voice-to-speech setting from shared preferences
  Future<bool> _loadVoiceToSpeechSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('voice_to_speech_enabled') ??
          true; // Default to true
    } catch (e) {
      print('Error loading voice-to-speech setting: $e');
      return true; // Default to true if error
    }
  }

  // Fetch messages from Firebase through server API
  Future<void> _fetchMessages() async {
    // Don't fetch messages for QuerySpace as it uses hardcoded responses
    if (_currentChatId == QUERYSPACE_CHAT_ID) {
      return;
    }

    // Check if we have valid cached messages
    if (_cachedMessages.containsKey(_currentChatId)) {
      final cacheTime = _cacheTimestamps[_currentChatId];
      if (cacheTime != null &&
          DateTime.now().difference(cacheTime) < _cacheExpiry) {
        // Use cached messages
        if (mounted) {
          setState(() {
            _messages.clear();
            _messages.addAll(_cachedMessages[_currentChatId]!);
          });
        }
        print('Using cached messages for chat $_currentChatId');
        return;
      }
    }

    try {
      // Get user data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userEmail =
          prefs.getString(
            'fbba7f175ebcb54045564072f6a79bcb61fd9b05ab10f8101f8cbfcbc8ae0780',
          ) ??
          '';
      final userUid = prefs.getString('user_uid') ?? '';

      // If userUid is empty, try to fetch it from the server
      String currentUserUid = userUid;
      if (currentUserUid.isEmpty && userEmail.isNotEmpty) {
        try {
          final userResponse = await http.get(
            Uri.parse(
              '${_apiUrl}/api/user-by-email/${Uri.encodeComponent(userEmail)}',
            ),
          );

          if (userResponse.statusCode == 200) {
            final userData = jsonDecode(userResponse.body);
            currentUserUid = userData['uid'] as String;
            // Save the UID for future use
            await prefs.setString('user_uid', currentUserUid);
          }
        } catch (e) {
          print('Error fetching user UID: $e');
          return;
        }
      }

      if (currentUserUid.isEmpty) {
        print('User not authenticated');
        return;
      }

      // Helper function to get authorization headers with JWT token
      Future<Map<String, String>> _getAuthHeaders() async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');

        final headers = <String, String>{'Content-Type': 'application/json'};

        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }

        return headers;
      }

      // Fetch messages from server API with pagination
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse(
          '${_apiUrl}/api/user-messages/$currentUserUid?page=1&limit=50',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Process received messages
        final receivedMessages = List<Map<String, dynamic>>.from(
          responseData['receivedMessages'] as List,
        );
        final sentMessages = List<Map<String, dynamic>>.from(
          responseData['sentMessages'] as List,
        );

        // Get pagination info if available
        final pagination = responseData['pagination'] as Map<String, dynamic>?;

        // Combine and sort messages by timestamp
        final allMessages = <Map<String, dynamic>>[];
        allMessages.addAll(receivedMessages);
        allMessages.addAll(sentMessages);

        allMessages.sort(
          (a, b) => DateTime.parse(
            a['timestamp'] as String,
          ).compareTo(DateTime.parse(b['timestamp'] as String)),
        );

        // Convert to Message objects
        final messageObjects = <Message>[];
        for (final msg in allMessages) {
          final messageText = msg['message'] as String;
          final isAudioMessage = messageText.startsWith('[AUDIO');

          messageObjects.add(
            Message(
              id: msg['id'] is int
                  ? msg['id'] as int
                  : DateTime.now().millisecondsSinceEpoch,
              text: messageText,
              isUser: msg['fromUserId'] == currentUserUid,
              timestamp: DateTime.parse(msg['timestamp'] as String),
              isAudio: isAudioMessage,
            ),
          );
        }

        // Update UI with messages and cache them
        if (mounted) {
          setState(() {
            _messages.clear();
            _messages.addAll(messageObjects);
          });

          // Cache the messages
          _cachedMessages[_currentChatId] = List.from(messageObjects);
          _cacheTimestamps[_currentChatId] = DateTime.now();

          _scrollToBottom();
          _saveCurrentChat();
        }

        print(
          'Messages fetched successfully: ${messageObjects.length} messages',
        );
      } else {
        print('Failed to fetch messages: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching messages: $e');
    }
  }

  // Fetch notifications from server API
  Future<void> _fetchNotifications() async {
    try {
      // Only fetch notifications when app is in background or not actively chatting
      bool isForeground =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

      // Fetch notifications from server API
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('${_apiUrl}/api/notifications'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final notifications = responseData['notifications'] as List;

        // Process notifications
        for (final notification in notifications) {
          final notificationData = notification as Map<String, dynamic>;

          // Check if it's a user message notification
          if (notificationData['data'] != null &&
              notificationData['data']['type'] == 'user_message') {
            // Show a local notification
            await _showNotification(
              notificationData['title'] as String,
              notificationData['body'] as String,
            );

            // Refresh messages to get the new message only if app is in foreground
            if (isForeground) {
              await _fetchMessages();
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching notifications: $e');
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
                            ? FutureBuilder<String?>(
                                future: _getImageData(message.text),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    // Loading placeholder
                                    return GestureDetector(
                                      onTap: () {
                                        // Do nothing while loading
                                      },
                                      child: Container(
                                        width: 200,
                                        height: 200,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.black,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.grey[600]!,
                                                ),
                                          ),
                                        ),
                                      ),
                                    );
                                  } else if (snapshot.hasData &&
                                      snapshot.data != null) {
                                    // Display actual image
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            _showFullScreenImage(
                                              snapshot.data!,
                                            );
                                          },
                                          child: Container(
                                            width: 200,
                                            height: 200,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.black,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Image.memory(
                                                base64Decode(snapshot.data!),
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      // Fallback to placeholder if image fails to load
                                                      return Container(
                                                        color: Colors.grey[300],
                                                        child: Icon(
                                                          Icons.broken_image,
                                                          size: 50,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                      );
                                                    },
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (message.text.length > 7)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: Text(
                                              _extractImageDescription(
                                                message.text,
                                              ),
                                              style: TextStyle(
                                                color: textColor,
                                                fontSize: 14,
                                                fontFamily: isUser
                                                    ? 'PlaywriteUSModern'
                                                    : 'Comfortaa',
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  } else {
                                    // Fallback to placeholder
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            // Show a message that the image couldn't be loaded
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Image could not be loaded',
                                                ),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            width: 200,
                                            height: 200,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[300],
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                                          ),
                                        ),
                                        if (message.text.length > 7)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: Text(
                                              _extractImageDescription(
                                                message.text,
                                              ),
                                              style: TextStyle(
                                                color: textColor,
                                                fontSize: 14,
                                                fontFamily: isUser
                                                    ? 'PlaywriteUSModern'
                                                    : 'Comfortaa',
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  }
                                },
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

  // Add this method to get image data from the server
  Future<String?> _getImageData(String messageText) async {
    try {
      // Extract image ID from message text
      if (messageText.startsWith('[IMAGE:')) {
        final colonIndex = messageText.indexOf(':');
        final closeBracketIndex = messageText.indexOf(']');

        if (colonIndex != -1 &&
            closeBracketIndex != -1 &&
            colonIndex < closeBracketIndex) {
          final imageId = messageText.substring(
            colonIndex + 1,
            closeBracketIndex,
          );

          // Fetch image data from server
          final headers = await _getAuthHeaders();
          final response = await http.get(
            Uri.parse('${_apiUrl}/api/image/$imageId'),
            headers: headers,
          );

          if (response.statusCode == 200) {
            final imageData = jsonDecode(response.body);
            return imageData['data'] as String?;
          }
        }
      }
      return null;
    } catch (e) {
      print('Error fetching image data: $e');
      return null;
    }
  }

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
              _isConnected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: _isConnected ? Colors.black : Colors.black,
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
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: ClipOval(
              child: Image.asset(
                'assets/icons/mychatconnect.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
            onPressed: () {
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
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
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
                                    final isVoiceToSpeechEnabled =
                                        await _loadVoiceToSpeechSetting();

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
                                                    '${chatSession.messages.length} messages',
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

  // Add a method to fetch events from the server
  Future<List<Map<String, dynamic>>> _fetchEventsFromServer() async {
    try {
      print('Fetching events from server...');

      // Fetch events from the server API using the dynamic URL
      final url = Uri.parse('${_apiUrl}/get_events');
      final response = await http.get(url).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 'success' && data['events'] != null) {
          print('Events fetched from server successfully');
          // Update connection status to connected since we successfully fetched events
          if (mounted) {
            setState(() {
              _isConnected = true;
            });
          }
          return List<Map<String, dynamic>>.from(data['events']);
        } else {
          print('Failed to parse events from server response');
        }
      } else {
        print('Failed to fetch events. Status: ${response.statusCode}');
      }

      return [];
    } catch (e) {
      print('Error fetching events from server: $e');
      // Update connection status to disconnected since we encountered an error
      if (mounted) {
        setState(() {
          _isConnected = false;
        });
      }
      return [];
    }
  }

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

  /// Process the scanned QR code and create a new chat session
  Future<void> _processScannedQrCode() async {
    try {
      // Reload the saved QR URL to get the latest scanned data
      await _loadSavedQrUrl();

      // Check if we have a valid scanned QR URL
      if (_savedQrUrl.isNotEmpty && _isValidEmail(_savedQrUrl)) {
        // Create a new chat session for the scanned user
        await _createChatForScannedUser(_savedQrUrl);

        // Clear the saved QR URL after processing
        await _clearSavedQrUrl();
      }
    } catch (e) {
      print('Error processing scanned QR code: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing scanned QR code: $e'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Create a new chat session for a scanned user
  Future<void> _createChatForScannedUser(String userEmail) async {
    try {
      // First, verify that the user exists on the server
      final userExists = await _verifyUserExists(userEmail);

      if (!userExists) {
        // Show error message if user doesn't exist on server
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User $userEmail not found on server'),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Generate a unique chat ID based on the user email
      final chatId = 'chat_${userEmail.hashCode}';

      // Check if chat already exists
      if (_chatSessions.containsKey(chatId)) {
        // If chat already exists, just switch to it
        setState(() {
          _currentChatId = chatId;
          _messages.clear();
          _messages.addAll(_chatSessions[chatId]!.messages);
          _showNoteMessage = _messages.isEmpty;
        });
        return;
      }

      // Fetch user profile data including profile image
      String? profileImageBase64;
      String chatTitle = userEmail.split(
        '@',
      )[0]; // Default to username part of email

      final userProfile = await _fetchUserProfile(userEmail);
      if (userProfile != null) {
        if (userProfile['displayName'] != null) {
          chatTitle = userProfile['displayName'] as String;
        }
        profileImageBase64 = userProfile['profileImageBase64'] as String?;
      }

      // Create new chat session
      final newSession = ChatSession(
        id: chatId,
        title: chatTitle,
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
        recipientEmail: userEmail, // Store the recipient's email
        profileImageBase64: profileImageBase64, // Store the profile image
        messages: [],
      );

      setState(() {
        // Add new chat session
        _chatSessions[chatId] = newSession;

        // Add to chat list if not already present
        if (!_chatList.contains(chatId)) {
          _chatList.add(chatId);
        }

        // Switch to the new chat
        _currentChatId = chatId;
        _messages.clear();
        _messages.addAll(newSession.messages);
        _showNoteMessage = _messages.isEmpty;
      });

      // Save all chat sessions
      await _saveChatSessions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New chat created for $userEmail'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error creating chat for scanned user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating chat for scanned user: $e'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Verify if a user exists on the server
  Future<bool> _verifyUserExists(String userEmail) async {
    try {
      // Make a request to the server to check if user exists
      // We'll use the update-profile endpoint but with a GET-like approach
      // by sending minimal data to see if the user exists
      final response = await http
          .post(
            Uri.parse('${_apiUrl}/api/auth/update-profile'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'uid': '', // Empty UID to test
              'email': userEmail,
            }),
          )
          .timeout(Duration(seconds: 10));

      // If we get a 404, the user doesn't exist
      // If we get a 400 for missing UID, the user exists
      if (response.statusCode == 404) {
        return false; // User not found
      } else if (response.statusCode == 400 &&
          response.body.contains('UID and email are required')) {
        // This means the email exists but UID is missing, which is expected
        return true; // User exists
      } else if (response.statusCode == 200) {
        // User exists and we got a successful response
        return true;
      }

      // For any other response, assume user doesn't exist
      return false;
    } catch (e) {
      print('Error verifying user existence: $e');
      // In case of network error, we'll assume user exists to be safe
      // This prevents blocking legitimate users due to network issues
      return true;
    }
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  /// Fetch user profile data including profile image
  Future<Map<String, dynamic>?> _fetchUserProfile(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) return null;

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('${_apiUrl}/api/user-by-email/${Uri.encodeComponent(email)}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        return {
          'displayName': userData['displayName'] as String?,
          'profileImageBase64': userData['profileImage'] as String?,
        };
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }
    return null;
  }

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
}

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final List<Message> messages;
  final String? recipientEmail; // For chats with specific users
  final String? profileImageBase64; // For storing user profile image

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastUpdated,
    this.recipientEmail,
    this.profileImageBase64,
    List<Message>? messages,
  }) : messages = messages ?? [];

  ChatSession copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? lastUpdated,
    String? recipientEmail,
    String? profileImageBase64,
    List<Message>? messages,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      recipientEmail: recipientEmail ?? this.recipientEmail,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
      messages: messages ?? this.messages,
    );
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final messagesList = json['messages'] as List<dynamic>? ?? [];
    return ChatSession(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      recipientEmail: json['recipientEmail'] as String?,
      profileImageBase64: json['profileImageBase64'] as String?,
      messages: messagesList
          .map((msg) => Message.fromJson(msg as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'recipientEmail': recipientEmail,
      'profileImageBase64': profileImageBase64,
      'messages': messages.map((msg) => msg.toJson()).toList(),
    };
  }
}
