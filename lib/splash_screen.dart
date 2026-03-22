import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'dart:async'; // Added for Timer

class SplashScreen extends StatefulWidget {
  final VoidCallback onSplashFinished;

  const SplashScreen({super.key, required this.onSplashFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  bool _animationError = false;
  bool _biometricEnabled = false;
  bool _isAuthenticating = false;
  int _cooldownSeconds = 0; // State variable for cooldown timer
  Timer? _cooldownTimer; // Timer for cooldown countdown
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();

    // Create animation controller for the Lottie animation
    _controller = AnimationController(vsync: this);

    // Check biometric settings and authenticate if needed
    _checkBiometricAndProceed();
  }

  @override
  void dispose() {
    _controller.dispose();
    _cooldownTimer?.cancel(); // Cancel timer when disposing
    _cooldownTimer = null;
    super.dispose();
  }

  Future<void> _checkBiometricAndProceed() async {
    try {
      // Check if we're on a supported platform
      if (!Platform.isAndroid && !Platform.isIOS) {
        // Not on a supported platform, proceed normally
        _proceedToMainApp();
        return;
      }

      // Check if biometric security is enabled
      final prefs = await SharedPreferences.getInstance();
      final bool biometricEnabled = prefs.getBool('biometric_enabled') ?? false;

      // Update the state variable
      if (mounted) {
        setState(() {
          _biometricEnabled = biometricEnabled;
          _isAuthenticating =
              biometricEnabled; // Set initial state for cooldown
          _cooldownSeconds = biometricEnabled
              ? 3
              : 0; // Set initial cooldown seconds
        });
      }

      if (biometricEnabled) {
        // Biometric security is enabled, require authentication
        await _authenticateWithBiometric();
      } else {
        // No biometric security, proceed normally
        _proceedToMainApp();
      }
    } catch (e) {
      print('Error checking biometric settings: $e');
      // If biometric is enabled, don't proceed to main app on error
      // Only proceed if biometric is not enabled
      if (!_biometricEnabled) {
        _proceedToMainApp();
      }
    }
  }

  Future<void> _authenticateWithBiometric() async {
    try {
      // Cancel any existing timer
      _cooldownTimer?.cancel();
      _cooldownTimer = null;

      // Check if we're on a supported platform
      if (!Platform.isAndroid && !Platform.isIOS) {
        // Not on a supported platform, proceed to main app
        _proceedToMainApp();
        return;
      }

      // Check if biometric authentication is available
      final bool canCheckBiometrics = await _auth.canCheckBiometrics;
      final List<BiometricType> availableBiometrics = await _auth
          .getAvailableBiometrics();

      if (!canCheckBiometrics || availableBiometrics.isEmpty) {
        // Biometric not available, proceed to main app
        _proceedToMainApp();
        return;
      }

      // Reset the cooldown state for the first authentication attempt
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _cooldownSeconds = 0;
        });
      }

      // Check if fingerprint is specifically available
      final bool hasFingerprint = availableBiometrics.contains(BiometricType.fingerprint) || 
                                 availableBiometrics.contains(BiometricType.strong);
      
      if (!hasFingerprint) {
        // Fingerprint not available, but other biometrics might be. 
        // Per user request, we only allow fingerprint.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fingerprint hardware not found or not set up.')),
          );
        }
        // If biometric was mandatory but no fingerprint, we might need a fallback or stay here.
        // For now, let's keep the user on splash if biometric is enabled but no fingerprint.
        return;
      }

      // Keep trying authentication until successful
      bool authenticated = false;
      while (!authenticated && mounted) {
        // Set cooldown state before authentication attempt
        if (mounted) {
          setState(() {
            _isAuthenticating = true;
          });
        }

        // Authenticate with biometrics (fingerprint only)
        final bool didAuthenticate = await _auth.authenticate(
          localizedReason: 'Please use fingerprint to access the app',
          biometricOnly: true, // No PIN/Pattern fallback
        );

        if (didAuthenticate) {
          // Authentication successful, proceed to main app
          authenticated = true;
          _proceedToMainApp();
        } else {
          // Authentication failed, show error and wait for user to tap fingerprint icon
          if (mounted) {
          }

          // Reset the cooldown state after a short delay to allow retry
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            setState(() {
              _isAuthenticating = false;
              _cooldownSeconds = 0;
            });
          }

          // Break out of the loop and wait for user to tap the fingerprint icon
          break;
        }
      }
    } on PlatformException catch (e) {
      print('Platform exception during biometric authentication: $e');
      // Show error and wait for user to tap fingerprint icon
      if (mounted) {
      }
      // Don't proceed to main app, keep user on splash screen
      // Update UI to ensure fingerprint icon is visible
      if (mounted) {
        setState(() {
          _biometricEnabled = true;
          _isAuthenticating = false;
          _cooldownSeconds = 0;
        });
      }
    } catch (e) {
      print('Error during biometric authentication: $e');
      // Show error and wait for user to tap fingerprint icon
      if (mounted) {
      }
      // Don't proceed to main app, keep user on splash screen
      // Update UI to ensure fingerprint icon is visible
      if (mounted) {
        setState(() {
          _biometricEnabled = true;
          _isAuthenticating = false;
          _cooldownSeconds = 0;
        });
      }
    }
  }

  void _authenticateWithCooldown() {
    // Call the authentication method immediately without cooldown
    _authenticateWithBiometric();
  }

  void _proceedToMainApp() {
    // Transition to main app quickly (shorter delay for animation to settle)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        widget.onSplashFinished();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lottie animation with error handling
            if (!_animationError)
              SizedBox(
                width: 200,
                height: 200,
                child: FutureBuilder(
                  future: _loadAnimation(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      // Show fallback image if animation fails
                      return Image.asset(
                        'assets/icons/mychatconnect.png',
                        width: 200,
                        height: 200,
                      );
                    }
                    if (snapshot.hasData) {
                      return snapshot.data!;
                    }
                    // Show loading indicator while loading animation
                    return const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    );
                  },
                ),
              )
            else
              // Fallback to static image if Lottie fails
              Image.asset(
                'assets/icons/mychatconnect.png',
                width: 200,
                height: 200,
              ),
            const SizedBox(height: 20),
            const Text(
              'My Space',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontFamily: 'Comfortaa',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'My Space Connect !',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontFamily: 'Comfortaa',
              ),
            ),
            const SizedBox(height: 30),
            // Fingerprint icon for retrying authentication - only shown when biometric is enabled
            if (_biometricEnabled)
              Column(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.fingerprint,
                      size: 48,
                      color: _isAuthenticating ? Colors.grey : Colors.black,
                    ),
                    onPressed: () {
                      // Call the authentication method immediately
                      _authenticateWithBiometric();
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<Widget> _loadAnimation() async {
    try {
      return Lottie.asset(
        'assets/json/Home.json',
        controller: _controller,
        onLoaded: (composition) {
          // Configure the AnimationController with the duration of the
          // Lottie file, then repeat the animation
          _controller
            ..duration = composition.duration
            ..repeat();
        },
      );
    } catch (e) {
      // Handle animation loading error
      print('Error loading Lottie animation: $e');
      setState(() {
        _animationError = true;
      });
      // Return fallback widget
      return Image.asset(
        'assets/icons/mychatconnect.png',
        width: 200,
        height: 200,
      );
    }
  }
}
