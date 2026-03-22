import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io' show Platform, File;
import 'dart:convert';
import 'package:local_auth/local_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models.dart';

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
    // Removed _loadUserDataFromServer call
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
      setState(() {
        _userName = prefs.getString('user_name') ?? 'User';
        _nameController.text = _userName;
        _isNameChanged = false;
        _profileImagePath = prefs.getString('profile_image_path') ?? '';
        _isNameSaved = _userName != 'User';
      });
    } catch (e) {
      print('Error loading username: $e');
    }
  }

  // Removed _loadUserDataFromServer as it's backend dependent

  // Load device information
  Future<void> _loadDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceInfoString = '';

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceInfoString = '${androidInfo.model} (Android ${androidInfo.version.release})';
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
    }
  }

  // Load chat statistics using Hive
  Future<void> _loadChatStatistics() async {
    try {
      final box = Hive.box<ChatSession>('chat_sessions');
      int chatCount = box.length;
      int messageCount = 0;
      
      for (var session in box.values) {
        messageCount += session.messages.length;
      }

      setState(() {
        _totalChats = chatCount;
        _totalMessages = messageCount;
      });
    } catch (e) {
      print('Error loading chat statistics: $e');
    }
  }

  void _onNameChanged() {
    setState(() {
      _isNameChanged = _nameController.text.trim() != _userName &&
          _nameController.text.trim().isNotEmpty;
    });
  }

  Future<void> _saveUserName() async {
    final trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', trimmedName);
      
      if (_profileImagePath.isNotEmpty) {
        await prefs.setString('profile_image_path', _profileImagePath);
      }

      setState(() {
        _userName = trimmedName;
        _isNameChanged = false;
        _isNameSaved = true;
      });

      widget.onNameUpdated?.call(trimmedName);
    } catch (e) {
      print('Error saving username: $e');
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
        await Hive.box<ChatSession>('chat_sessions').clear();
        _loadChatStatistics();
      } catch (e) {
        print('Error clearing chat history: $e');
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
                  'Fingerprint Security',
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
                          'Enable Fingerprint Security',
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
              title: const Text('Disable Fingerprint Security'),
              content: const Text(
                'Are you sure you want to disable fingerprint security? This will reduce the security of your app.',
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

        // Check if fingerprint is specifically available
        final bool hasFingerprint = availableBiometrics.contains(BiometricType.fingerprint) || 
                                   availableBiometrics.contains(BiometricType.strong);
        
        if (!hasFingerprint) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fingerprint hardware not found or not set up.')),
            );
          }
          return;
        }

        // Test biometric authentication (fingerprint only)
        final bool didAuthenticate = await _auth.authenticate(
          localizedReason: 'Please use fingerprint to enable this security feature',
          biometricOnly: true,
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
