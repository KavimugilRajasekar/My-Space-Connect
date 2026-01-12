import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io' show Platform, File;
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart'; // Add this import
import 'package:http/http.dart' as http;
import 'config.dart';

// Import the QR popup widget
import 'widgets/qr_popup.dart';

class ProfilePage extends StatefulWidget {
  final Function(String)? onNameUpdated; // Add callback for name updates
  final VoidCallback? onLogout; // Add callback for logout

  const ProfilePage({super.key, this.onNameUpdated, this.onLogout});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  String _userName = 'User';
  bool _isNameChanged = false;
  bool _isNameSaved = false; // Track if name has been saved

  // New state variables for additional profile information
  String _deviceInfo = '';
  int _totalChats = 0;
  int _totalMessages = 0;
  String _appVersion = '1.0.0';

  // Biometric security variables
  bool _biometricEnabled = false;
  final LocalAuthentication _auth = LocalAuthentication();

  // Voice-to-speech variables
  bool _voiceToSpeechEnabled = true; // Default to voice-to-speech enabled

  // Profile image variables
  String _profileImagePath = '';
  final ImagePicker _picker = ImagePicker();

  // Server URL - this will be updated after deployment
  static const String SERVER_URL = AppConfig.SERVER_URL;

  // Add method to open QR scanner
  void _openQrScanner() {
    // Show the new QR popup widget
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const QrPopup();
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadUserDataFromServer(); // Load additional data from server
    _loadDeviceInfo();
    _loadChatStatistics();
    _loadBiometricSettings();
    _loadVoiceToSpeechSettings();
    _loadProfileImageSettings();

    // Add listener to the text controller to track changes
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    // Remove listener when disposing
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool userNameSaved = prefs.getBool('user_name_saved') ?? false;
      setState(() {
        _userName = prefs.getString('user_name') ?? 'User';
        _nameController.text = _userName;
        _isNameChanged = false; // Reset change flag
        _isNameSaved =
            userNameSaved; // Use the saved flag from SharedPreferences
        // Load profile image path
        _profileImagePath = prefs.getString('profile_image_path') ?? '';
      });
    } catch (e) {
      print('Error loading username: $e');
      // Use default values if there's an error
      setState(() {
        _userName = 'User';
        _nameController.text = _userName;
        _isNameChanged = false;
        _isNameSaved = false;
        _profileImagePath = '';
      });
    }
  }

  Future<void> _loadUserDataFromServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail =
          prefs.getString(
            'fbba7f175ebcb54045564072f6a79bcb61fd9b05ab10f8101f8cbfcbc8ae0780',
          ) ??
          '';
      final token = prefs.getString('auth_token');

      if (userEmail.isEmpty || token == null) return;

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse(
          '$SERVER_URL/api/user-by-email/${Uri.encodeComponent(userEmail)}',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);

        // Update local storage with server data
        if (userData['displayName'] != null) {
          await prefs.setString('user_name', userData['displayName']);
        }

        // Update profile image if available
        if (userData['profileImage'] != null) {
          await prefs.setString(
            'profile_image_from_server',
            userData['profileImage'],
          );
        }

        setState(() {
          if (userData['displayName'] != null) {
            _userName = userData['displayName'];
            _nameController.text = _userName;
          }

          // We'll keep using the local file path for display, but store server data
        });
      }
    } catch (e) {
      print('Error loading user data from server: $e');
    }
  }

  // Load device information
  Future<void> _loadDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceInfoString = '';

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceInfoString =
            '${androidInfo.model} (Android ${androidInfo.version.release})';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceInfoString = '${iosInfo.model} (iOS ${iosInfo.systemVersion})';
      } else {
        deviceInfoString = 'Unknown Device';
      }

      setState(() {
        _deviceInfo = deviceInfoString;
      });
    } catch (e) {
      print('Error loading device info: $e');
      setState(() {
        _deviceInfo = 'Device information unavailable';
      });
    }
  }

  // Load chat statistics
  Future<void> _loadChatStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load chat list
      final String? chatListJson = prefs.getString('chat_list');
      int chatCount = 0;
      int messageCount = 0;

      if (chatListJson != null) {
        final List<dynamic> chatListData = json.decode(chatListJson);
        chatCount = chatListData.length;

        // Count messages in all chats
        for (String chatId in chatListData) {
          final String? chatJson = prefs.getString('chat_$chatId');
          if (chatJson != null) {
            final Map<String, dynamic> chatData = json.decode(chatJson);
            final List<dynamic> messages =
                chatData['messages'] as List<dynamic>? ?? [];
            messageCount += messages.length;
          }
        }
      }

      setState(() {
        _totalChats = chatCount;
        _totalMessages = messageCount;
      });
    } catch (e) {
      print('Error loading chat statistics: $e');
      setState(() {
        _totalChats = 0;
        _totalMessages = 0;
      });
    }
  }

  void _onNameChanged() {
    setState(() {
      // Check if the name has actually changed from the original
      _isNameChanged =
          _nameController.text.trim() != _userName &&
          _nameController.text.trim().isNotEmpty;
    });
  }

  Future<void> _saveUserName() async {
    // Check if name has already been saved once
    if (_isNameSaved) {
      if (mounted) {}
      return;
    }

    final trimmedName = _nameController.text.trim();

    // Validate that name is not empty
    if (trimmedName.isEmpty) {
      if (mounted) {}
      return;
    }

    try {
      // Get user email and UID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userEmail =
          prefs.getString(
            'fbba7f175ebcb54045564072f6a79bcb61fd9b05ab10f8101f8cbfcbc8ae0780',
          ) ??
          '';
      final userUid = prefs.getString('user_uid') ?? '';

      // Convert profile image to base64 if it exists
      String? profileImageBase64;
      if (_profileImagePath.isNotEmpty) {
        profileImageBase64 = await _convertImageToBase64(_profileImagePath);
      }

      // Update user profile on server (which will update Firebase)
      if (userEmail.isNotEmpty && userUid.isNotEmpty) {
        try {
          // Get JWT token
          final token = prefs.getString('auth_token');
          final headers = <String, String>{'Content-Type': 'application/json'};

          if (token != null && token.isNotEmpty) {
            headers['Authorization'] = 'Bearer $token';
          }

          // Prepare request body with all profile data
          final requestBody = {
            'uid': userUid,
            'email': userEmail,
            'displayName': trimmedName,
          };

          // Add profile image if available
          if (profileImageBase64 != null) {
            requestBody['profileImage'] = profileImageBase64;
          }

          final response = await http.post(
            Uri.parse('$SERVER_URL/api/auth/update-profile'),
            headers: headers,
            body: jsonEncode(requestBody),
          );

          if (response.statusCode != 200) {
            print('Failed to update profile on server: ${response.body}');
          }
        } catch (serverError) {
          print('Error updating profile on server: $serverError');
        }
      }

      // Save locally
      await prefs.setString('user_name', trimmedName);
      await prefs.setBool(
        'user_name_saved',
        true,
      ); // Ensure this is set to true

      // Save profile image path locally as well
      if (_profileImagePath.isNotEmpty) {
        await prefs.setString('profile_image_path', _profileImagePath);
      }

      setState(() {
        _userName = trimmedName;
        _isNameChanged = false; // Reset change flag after saving
        _isNameSaved = true; // Mark name as saved
      });

      // Notify the parent widget (main app) about the name update
      widget.onNameUpdated?.call(trimmedName);

      if (mounted) {}
    } catch (e) {
      print('Error saving username: $e');
      if (mounted) {}
    }
  }

  // Add method to clear all chat history
  Future<void> _clearAllChatHistory() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear All Chat History'),
          content: const Text(
            'Are you sure you want to delete all chat history? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        final prefs = await SharedPreferences.getInstance();

        // Get chat list
        final String? chatListJson = prefs.getString('chat_list');
        if (chatListJson != null) {
          final List<dynamic> chatListData = json.decode(chatListJson);

          // Remove all chat data
          for (String chatId in chatListData) {
            await prefs.remove('chat_$chatId');
          }
        }

        // Clear chat list
        await prefs.remove('chat_list');

        // Reload statistics
        _loadChatStatistics();

        if (mounted) {}
      } catch (e) {
        print('Error clearing chat history: $e');
        if (mounted) {}
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (_isNameSaved) {
      // Name has been saved, allow popping
      return true;
    } else {
      // Name not saved, show confirmation dialog
      return (await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Name Not Saved'),
              content: const Text(
                'Please enter and save your name before leaving this page.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('OK'),
                ),
              ],
            ),
          )) ??
          false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 4,
          shadowColor: Colors.grey.withOpacity(0.5),
          shape: Border(bottom: BorderSide(color: Colors.black, width: 1.5)),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile header with user avatar
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          GestureDetector(
                            onTap: _pickProfileImage,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black,
                                  width: 2,
                                ),
                              ),
                              child: _profileImagePath.isNotEmpty
                                  ? ClipOval(
                                      child: Image.file(
                                        File(_profileImagePath),
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          _userName.isNotEmpty
                                              ? _userName[0].toUpperCase()
                                              : 'U',
                                          style: TextStyle(
                                            fontSize: 40,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onTap: _openQrScanner,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.qr_code,
                                  size: 20,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        _userName,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 4),
                      TextButton(
                        onPressed: _pickProfileImage,
                        child: Text(
                          _profileImagePath.isNotEmpty
                              ? 'Change Profile Image'
                              : 'Set Profile Image',
                          style: TextStyle(
                            color: const Color.fromARGB(255, 182, 221, 253),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (_profileImagePath.isNotEmpty)
                        TextButton(
                          onPressed: _removeProfileImage,
                          child: Text(
                            'Remove Profile Image',
                            style: TextStyle(
                              color: const Color.fromARGB(255, 227, 181, 177),
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 30),

                // User name section
                Text(
                  'Display Name:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _nameController,
                  // Disable the text field when name is saved
                  enabled: !_isNameSaved,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: Colors.black, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: Colors.black, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: Colors.black, width: 2.0),
                    ),
                    hintText: 'Enter your name',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _isNameSaved
                      ? null
                      : (_isNameChanged ? _saveUserName : null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isNameSaved
                        ? Colors.grey[300]!
                        : Colors.white,
                    foregroundColor: _isNameSaved
                        ? Colors.grey[600]!
                        : Colors.black,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _isNameSaved ? Colors.grey : Colors.black,
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Text(_isNameSaved ? 'Name Saved' : 'Save Name'),
                ),
                SizedBox(height: 30),

                // Statistics section
                Text(
                  'Statistics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 15),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          'Total Chats',
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        ),
                        trailing: Text(
                          '$_totalChats',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Divider(height: 1, color: Colors.black),
                      ListTile(
                        title: Text(
                          'Total Messages',
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        ),
                        trailing: Text(
                          '$_totalMessages',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Device information section
                Text(
                  'Device Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 15),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: ListTile(
                    title: Text(
                      _deviceInfo,
                      style: TextStyle(fontSize: 16, color: Colors.black),
                    ),
                    trailing: Icon(
                      Platform.isAndroid
                          ? Icons.android
                          : Platform.isIOS
                          ? Icons.phone_iphone
                          : Icons.devices,
                      color: Colors.black,
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Actions section
                Text(
                  'Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 15),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          'Clear All Chat History',
                          style: TextStyle(fontSize: 16, color: Colors.red),
                        ),
                        trailing: Icon(Icons.delete_forever, color: Colors.red),
                        onTap: _clearAllChatHistory,
                      ),
                      Divider(height: 1, color: Colors.black),
                      ListTile(
                        title: Text(
                          'Logout',
                          style: TextStyle(fontSize: 16, color: Colors.red),
                        ),
                        trailing: Icon(Icons.logout, color: Colors.red),
                        onTap: () {
                          // Show confirmation dialog before logout
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Confirm Logout'),
                                content: Text(
                                  'Are you sure you want to logout?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      widget.onLogout?.call();
                                    },
                                    child: Text('Logout'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Biometric Security section
                Text(
                  'Biometric Security',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 15),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          'Enable Biometric Security',
                          style: TextStyle(
                            fontSize: 16,
                            color: _biometricEnabled
                                ? Colors.black
                                : Colors.grey,
                          ),
                        ),
                        subtitle: Text(
                          'Require fingerprint authentication to access the app',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            _biometricEnabled
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: _biometricEnabled
                                ? Colors.black
                                : Colors.grey,
                          ),
                          onPressed: () {
                            _toggleBiometricSecurity(!_biometricEnabled);
                          },
                        ),
                        onTap: () {
                          _toggleBiometricSecurity(!_biometricEnabled);
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 30),

                // Voice-to-Speech section
                Text(
                  'Voice-to-Speech',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 15),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          'Enable Voice-to-Speech',
                          style: TextStyle(
                            fontSize: 16,
                            color: _voiceToSpeechEnabled
                                ? Colors.black
                                : Colors.grey,
                          ),
                        ),
                        subtitle: Text(
                          _voiceToSpeechEnabled
                              ? 'Convert voice to text when pressing mic icon'
                              : 'Record voice as audio file and send to contacts',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            _voiceToSpeechEnabled
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: _voiceToSpeechEnabled
                                ? Colors.black
                                : Colors.grey,
                          ),
                          onPressed: () {
                            _toggleVoiceToSpeech(!_voiceToSpeechEnabled);
                          },
                        ),
                        onTap: () {
                          _toggleVoiceToSpeech(!_voiceToSpeechEnabled);
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 30),

                // About section
                Text(
                  'About My Space',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'My Space is a smart home automation system that allows you to control your appliances through API commands. '
                  'When any user sends a command to control an appliance, all users will receive a notification about the action.',
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadBiometricSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      });
    } catch (e) {
      print('Error loading biometric settings: $e');
      setState(() {
        _biometricEnabled = false;
      });
    }
  }

  Future<void> _loadVoiceToSpeechSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _voiceToSpeechEnabled =
            prefs.getBool('voice_to_speech_enabled') ?? true;
      });
    } catch (e) {
      print('Error loading voice-to-speech settings: $e');
      setState(() {
        _voiceToSpeechEnabled = true; // Default to enabled
      });
    }
  }

  Future<void> _toggleBiometricSecurity(bool enable) async {
    try {
      // Check if we're on a supported platform
      if (!Platform.isAndroid && !Platform.isIOS) {
        if (mounted) {}
        // Update UI to reflect that biometric is disabled on unsupported platforms
        setState(() {
          _biometricEnabled = false;
        });
        // Save the setting
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('biometric_enabled', false);
        return;
      }

      // If disabling biometric security, ask for confirmation
      if (!enable) {
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Disable Biometric Security'),
              content: const Text(
                'Are you sure you want to disable biometric security? This will reduce the security of your app.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Disable'),
                ),
              ],
            );
          },
        );

        if (confirm != true) {
          // User cancelled or said no, keep biometric enabled
          return;
        }
      }

      // Check if biometric authentication is available
      if (enable) {
        final bool canCheckBiometrics = await _auth.canCheckBiometrics;
        final List<BiometricType> availableBiometrics = await _auth
            .getAvailableBiometrics();

        if (!canCheckBiometrics || availableBiometrics.isEmpty) {
          return;
        }

        // Test biometric authentication
        final bool didAuthenticate = await _auth.authenticate(
          localizedReason: 'Please authenticate to enable biometric security',
        );

        if (!didAuthenticate) {
          return;
        }
      }

      // Save the setting
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', enable);

      setState(() {
        _biometricEnabled = enable;
      });

      if (mounted) {}
    } on PlatformException catch (e) {
      print('Platform exception during biometric security toggle: $e');
      if (mounted) {}
    } catch (e) {
      print('Error toggling biometric security: $e');
      if (mounted) {}
    }
  }

  Future<void> _toggleVoiceToSpeech(bool enable) async {
    try {
      // Save the setting
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('voice_to_speech_enabled', enable);

      setState(() {
        _voiceToSpeechEnabled = enable;
      });

      if (mounted) {}
    } catch (e) {
      print('Error toggling voice-to-speech: $e');
      if (mounted) {}
    }
  }

  Future<void> _loadProfileImageSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _profileImagePath = prefs.getString('profile_image_path') ?? '';
      });
    } catch (e) {
      print('Error loading profile image settings: $e');
      setState(() {
        _profileImagePath = '';
      });
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      // Check if we're on a supported platform
      if (!Platform.isAndroid && !Platform.isIOS) {
        if (mounted) {}
        return;
      }

      // Request storage permission for Android
      if (Platform.isAndroid) {
        // For Android 11+, we need to handle scoped storage differently
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          // Try requesting manage external storage for Android 11+
          if (Platform.isAndroid) {
            final manageStatus = await Permission.manageExternalStorage
                .request();
            if (!manageStatus.isGranted) {
              if (mounted) {}
              return;
            }
          } else {
            if (mounted) {}
            return;
          }
        }
      }

      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        // Save the image path
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_path', image.path);

        setState(() {
          _profileImagePath = image.path;
        });

        if (mounted) {}
      }
    } on PlatformException catch (e) {
      print('Platform exception during profile image selection: $e');
      if (mounted) {}
    } catch (e) {
      print('Error picking profile image: $e');
      if (mounted) {}
    }
  }

  Future<void> _removeProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('profile_image_path');

      setState(() {
        _profileImagePath = '';
      });

      if (mounted) {}
    } catch (e) {
      print('Error removing profile image: $e');
      if (mounted) {}
    }
  }

  // Helper method to convert image file to base64
  Future<String?> _convertImageToBase64(String imagePath) async {
    try {
      if (imagePath.isEmpty) return null;

      final file = File(imagePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return base64Encode(bytes);
      }
      return null;
    } catch (e) {
      print('Error converting image to base64: $e');
      return null;
    }
  }
}
