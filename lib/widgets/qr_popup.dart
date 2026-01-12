import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/rendering.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class QrPopup extends StatefulWidget {
  const QrPopup({super.key});

  @override
  State<QrPopup> createState() => _QrPopupState();
}

class _QrPopupState extends State<QrPopup> {
  String _userEmail = '';
  String _profileImagePath = '';
  bool _isLoading = true;
  final GlobalKey _shareKey =
      GlobalKey(); // This key is for the entire shareable portion

  // Hardcoded key for storing user email
  static const String USER_EMAIL_KEY =
      'fbba7f175ebcb54045564072f6a79bcb61fd9b05ab10f8101f8cbfcbc8ae0780';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(USER_EMAIL_KEY) ?? '';
      final profileImagePath = prefs.getString('profile_image_path') ?? '';

      if (mounted) {
        setState(() {
          _userEmail = email;
          _profileImagePath = profileImagePath;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Encrypt email using XOR with the provided key
  String _encryptEmail(String email) {
    final key =
        'fbba7f175ebcb54045564072f6a79bcb61fd9b05ab10f8101f8cbfcbc8ae0780';
    final emailBytes = utf8.encode(email);
    final keyBytes = utf8.encode(key);

    final result = <int>[];
    for (int i = 0; i < emailBytes.length; i++) {
      result.add(emailBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    // Print the encoded email for debugging
    print(
      'Encoded email: ' +
          result.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(''),
    );

    // Convert to hex string for QR code representation
    return result
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join('');
  }

  // Capture the entire shareable portion as image
  Future<Uint8List> _captureShareableImage() async {
    try {
      final boundary =
          _shareKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } catch (e) {
      throw Exception('Failed to capture shareable image: $e');
    }
  }

  // Save to Gallery
  Future<void> _saveToGallery() async {
    try {
      final imageBytes = await _captureShareableImage();

      // Get the PUBLIC Pictures directory (visible in Photos/Gallery)
      Directory picturesDirectory;

      if (Platform.isAndroid) {
        // For Android: Save to DCIM or Pictures directory
        picturesDirectory = Directory(
          '/storage/emulated/0/DCIM/MySpaceConnect',
        );
        if (!await picturesDirectory.exists()) {
          await picturesDirectory.create(recursive: true);
        }
      } else if (Platform.isIOS) {
        // For iOS: Save to Pictures directory
        picturesDirectory = await getApplicationDocumentsDirectory();
        // iOS automatically syncs images from Documents to Photos if proper permissions are set
      } else {
        picturesDirectory = await getApplicationDocumentsDirectory();
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'MySpaceConnect_QR_$timestamp.png';
      final imagePath = '${picturesDirectory.path}/$fileName';
      final file = File(imagePath);

      // Save the image
      await file.writeAsBytes(imageBytes);

      // For iOS: You need to trigger gallery refresh (simplified approach)
      if (Platform.isIOS) {
        // On iOS, we need to save to a specific album or use platform channels
        // This is a simplified approach that saves to documents
        // For full iOS Photos integration, you'd need platform channels or a package
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✅ QR code saved successfully!'),
              const SizedBox(height: 4),
              Text('Saved as: $fileName', style: const TextStyle(fontSize: 12)),
              if (Platform.isAndroid)
                Text(
                  'Location: DCIM/MySpaceConnect',
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Open Photos',
            textColor: Colors.white,
            onPressed: () {
              // Could launch gallery app using url_launcher package
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to save: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Share QR code with profile image
  Future<void> _shareQrCode() async {
    try {
      final imageBytes = await _captureShareableImage();

      // Create a temporary file
      final directory = await getTemporaryDirectory();
      final imagePath =
          '${directory.path}/qr_code_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(imagePath);
      await file.writeAsBytes(imageBytes);

      // Share the file with app promotion
      await Share.shareXFiles(
        [XFile(imagePath)],
        text:
            '🌟 Let\'s connect on MySpaceConnect! 🌟 Scan this QR code to connect with me. #MySpaceConnect',
        subject: 'Join MySpaceConnect & Connect with Me',
      );

      // Clean up - delete the temporary file after sharing
      await Future.delayed(const Duration(seconds: 5), () => file.delete());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show options dialog for share/save
  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share QR Code'),
                subtitle: const Text(
                  'Share via apps like WhatsApp, Email, etc.',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _shareQrCode();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Save to Photos'),
                subtitle: const Text('Save to your Photos/Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _saveToGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final encryptedEmail = _encryptEmail(_userEmail);

    return AlertDialog(
      title: const Text(
        'Your QR Code',
        style: TextStyle(fontFamily: 'Comfortaa', fontWeight: FontWeight.bold),
      ),
      content: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Wrap the entire shareable portion with RepaintBoundary
                RepaintBoundary(
                  key:
                      _shareKey, // This key is for the entire shareable portion
                  child: Container(
                    padding: const EdgeInsets.all(12), // Reduced from 16
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        12,
                      ), // Reduced from 16
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // "My Space" and "Connect" text
                        const Text(
                          'My Space',
                          style: TextStyle(
                            fontFamily: 'Comfortaa',
                            fontSize: 18, // Reduced from 20
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const Text(
                          'Connect',
                          style: TextStyle(
                            fontFamily: 'Comfortaa',
                            fontSize: 12, // Reduced from 14
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6), // Further reduced from 8
                        // Profile image below "Connect" text (slightly reduced size)
                        if (_profileImagePath.isNotEmpty)
                          Container(
                            width: 50,
                            height: 50,
                            margin: const EdgeInsets.only(
                              bottom: 1,
                            ), // Further reduced from 3 to 1
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: ClipOval(
                              child: Image.file(
                                File(_profileImagePath),
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 50,
                            height: 50,
                            margin: const EdgeInsets.only(
                              bottom: 1,
                            ), // Further reduced from 3 to 1
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[300],
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                _userEmail.isNotEmpty
                                    ? _userEmail[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),

                        // QR code (increased size)
                        Container(
                          width: 180, // Increased from 150
                          height: 180, // Increased from 150
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: PrettyQrView.data(
                            data: encryptedEmail,
                            decoration: PrettyQrDecoration(
                              shape: PrettyQrSmoothSymbol(),
                              quietZone: PrettyQrQuietZone.modules(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Moved the instructional text outside the white container
                const SizedBox(height: 8), // Reduced from 12
                const Text(
                  'Scan this QR code to connect with others',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10, // Reduced from 12
                    fontFamily: 'Comfortaa',
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8), // Reduced from 12

                ElevatedButton.icon(
                  onPressed: _showShareOptions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[800]!, width: 1.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  icon: Icon(Icons.share, size: 20, color: Colors.grey[800]),
                  label: const Text(
                    'Share as Image',
                    style: TextStyle(
                      fontFamily: 'Comfortaa',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
