import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart' as qr_scanner;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
// Removed AppConfig import

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  qr_scanner.Barcode? result;
  qr_scanner.QRViewController? controller;
  bool _flashOn = false;
  bool _frontCamera = false;
  bool _permissionGranted = false;
  bool _isScanning = false; // Track scanning state
  String? _lastScannedCode; // Track the last scanned code to avoid duplicates
  int _retryCount = 0; // Track retry attempts
  static const int MAX_RETRIES = 3; // Maximum retry attempts

  final String _decryptionKey =
      'fbba7f175ebcb54045564072f6a79bcb61fd9b05ab10f8101f8cbfcbc8ae0780';

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    }
    controller?.resumeCamera();
  }

  @override
  void initState() {
    super.initState();
    // Add a slight delay to ensure the widget is properly mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestCameraPermission();
    });
  }

  Future<void> _requestCameraPermission() async {
    try {
      var status = await Permission.camera.request();
      if (status.isGranted) {
        setState(() {
          _permissionGranted = true;
        });
      } else if (status.isPermanentlyDenied) {
        // Show a dialog explaining why we need the permission
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Camera Permission Required'),
                content: Text(
                  'This app needs camera permission to scan QR codes. Please grant the permission in settings.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await openAppSettings();
                      Navigator.of(context).pop();
                    },
                    child: Text('Open Settings'),
                  ),
                ],
              );
            },
          );
        }
      } else {
        // Permission denied temporarily
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Camera permission denied. QR scanning will not work.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Error requesting camera permission: $e');
      if (mounted) {}
    }
  }

  /// Initialize the camera with a timeout to prevent getting stuck
  Future<void> _initializeCameraWithTimeout() async {
    try {
      // Set a timeout for camera initialization
      await Future.any([
        Future.delayed(Duration(seconds: 10)), // 10 second timeout
        Future.microtask(() async {
          // The camera should already be initialized by the QRView widget
          // Just wait a bit to ensure it's ready
          await Future.delayed(Duration(milliseconds: 500));
        }),
      ]);
    } catch (e) {
      print('Camera initialization timeout or error: $e');
      if (mounted) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Scan QR Code',
          style: TextStyle(
            fontFamily: 'Comfortaa',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 3,
        shadowColor: Colors.grey.withOpacity(0.5),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: _permissionGranted
                ? qr_scanner.QRView(
                    key: qrKey,
                    onQRViewCreated: _onQRViewCreated,
                    overlay: qr_scanner.QrScannerOverlayShape(
                      borderColor: Colors.black,
                      borderRadius: 10,
                      borderLength: 30,
                      borderWidth: 10,
                      cutOutSize: 300,
                    ),
                    onPermissionSet: (ctrl, p) {
                      // Handle permission changes
                      if (!p) {
                        // Permission denied
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Camera permission denied. QR scanning will not work.',
                              ),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, size: 100, color: Colors.grey),
                        SizedBox(height: 20),
                        Text(
                          'Camera permission required',
                          style: TextStyle(
                            fontFamily: 'Comfortaa',
                            fontSize: 18,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _requestCameraPermission,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.black, width: 1.5),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          child: Text(
                            'Grant Permission',
                            style: TextStyle(
                              fontFamily: 'Comfortaa',
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                if (result != null)
                  Text(
                    'Barcode Type: ${result!.format.name}   Data: ${result!.code}',
                    style: TextStyle(
                      fontFamily: 'Comfortaa',
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  )
                else
                  Text(
                    'Scan a QR code',
                    style: TextStyle(
                      fontFamily: 'Comfortaa',
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        _flashOn ? Icons.flash_off : Icons.flash_on,
                        color: Colors.black,
                      ),
                      onPressed: () async {
                        await controller?.toggleFlash();
                        setState(() {
                          _flashOn = !_flashOn;
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.flip_camera_ios, color: Colors.black),
                      onPressed: () async {
                        await controller?.flipCamera();
                        setState(() {
                          _frontCamera = !_frontCamera;
                        });
                      },
                    ),

                    IconButton(
                      icon: Icon(Icons.refresh, color: Colors.black),
                      onPressed: _retryScan,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<int> _hexToBytes(String hexString) {
    // Convert hex string to byte array
    List<int> bytes = [];
    for (int i = 0; i < hexString.length; i += 2) {
      String hexPair = hexString.substring(i, i + 2);
      int byte = int.parse(hexPair, radix: 16);
      bytes.add(byte);
    }
    return bytes;
  }

  String _bytesToHex(List<int> bytes) {
    // Convert byte array to hex string
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
  }

  Future<void> _processScannedData(String scannedData) async {
    print('Processing scanned data: $scannedData');

    // Get current user's UID to prevent self-scanning
    final prefs = await SharedPreferences.getInstance();
    final currentUserUid = prefs.getString('user_uid') ?? '';

    // Decode the scanned data using the provided key
    String? decodedData = await _decodeScannedData(scannedData);
    print('Decoded data: $decodedData');

    if (decodedData != null && decodedData.isNotEmpty) {
      // Prevent user from scanning their own QR code
      if (decodedData.trim() == currentUserUid.trim()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You cannot scan your own QR code.'),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.orange,
            ),
          );

          // Reset scanning state
          setState(() {
            result = null;
            _lastScannedCode = null;
            _isScanning = false;
          });
        }
        return;
      }

      // Save the decoded user identity
      await _saveScannedUrl(decodedData);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } else {
      print(
        'Invalid data. Decoded data: $decodedData',
      );
      // Show invalid message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invalid: Scanned QR does not contain a valid identity.',
            ),

            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );

        // Reset scanning state
        setState(() {
          result = null;
          _lastScannedCode = null;
          _isScanning = false;
        });
      }
    }
  }

  Future<String?> _decodeScannedData(String scannedData) async {
    print('Raw scanned data: $scannedData');
    try {
      // Convert key to bytes using UTF-8 (matching QR generator)
      List<int> keyBytes = utf8.encode(_decryptionKey);
      print('Key bytes length: ${keyBytes.length}');

      // Try to parse scanned data as hex, if not, use as-is
      List<int> dataBytes;
      try {
        // Check if it looks like hex
        if (scannedData.length % 2 == 0 &&
            RegExp(r'^[0-9a-fA-F]+$').hasMatch(scannedData)) {
          print('Treating data as hex');
          dataBytes = _hexToBytes(scannedData);
        } else {
          print('Treating data as UTF-8 string');
          dataBytes = utf8.encode(scannedData);
        }
      } catch (e) {
        // If not hex, use UTF-8
        dataBytes = utf8.encode(scannedData);
      }

      // XOR decryption
      List<int> decodedBytes = [];
      for (int i = 0; i < dataBytes.length; i++) {
        decodedBytes.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
      }
      print('Data bytes length: ${dataBytes.length}');
      print('Decoded bytes: $decodedBytes');

      // Try to decode as UTF-8 string
      String decodedString = utf8.decode(decodedBytes, allowMalformed: true);
      print('Decoded string: $decodedString');

      // Clean up any non-printable characters
      decodedString = decodedString.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
      print('Cleaned decoded string: $decodedString');

      return decodedString;
    } catch (e) {
      print('Error decoding scanned data: $e');
      return scannedData; // Return original if decoding fails
    }
  }

  bool _isValidEmail(String email) {
    // Simple email validation regex
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email.trim());
  }

  void _retryScan() {
    if (_retryCount < MAX_RETRIES) {
      setState(() {
        _retryCount++;
        result = null;
        _lastScannedCode = null;
        _isScanning = false;
      });

      // Reinitialize the camera
      controller?.resumeCamera();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('($_retryCount/$MAX_RETRIES)'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Maximum retry attempts reached. Please restart the scanner.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _onQRViewCreated(qr_scanner.QRViewController controller) {
    // Prevent multiple initializations
    if (_isScanning) return;

    setState(() {
      this.controller = controller;
      _isScanning = true;
    });

    // Set a timeout to prevent the scanner from getting stuck
    Timer? scanTimeout;

    controller.scannedDataStream
        .listen((scanData) async {
          // Cancel the timeout if we get a scan
          scanTimeout?.cancel();

          setState(() {
            result = scanData;
          });

          // If we have a result and it's different from the last scanned code
          if (result != null && result!.code != _lastScannedCode) {
            // Store the scanned code to prevent duplicates
            _lastScannedCode = result!.code;

            // Process the scanned data with decryption and validation
            await _processScannedData(result!.code ?? '');
          }
        })
        .onError((error) {
          // Handle stream errors
          print('Error in QR scanning stream: $error');
          _isScanning = false;
          if (mounted) {}
        });

    // Set a timeout to show an error if no QR code is scanned within 30 seconds
    scanTimeout = Timer(Duration(seconds: 30), () {
      _isScanning = false;
      if (mounted) {}
    });
  }

  Future<void> _saveScannedUrl(String url) async {
    if (url.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('scanned_qr_url', url);

        // Show a snackbar to confirm the URL was saved
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully scanned and saved email: $url'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('Error saving scanned URL to SharedPreferences: $e');
        rethrow;
      }
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
