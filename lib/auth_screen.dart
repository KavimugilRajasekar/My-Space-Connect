import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthSuccess;

  const AuthScreen({super.key, required this.onAuthSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';
  bool _showOtpField = false;
  String _otpMessage = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  // Add these new variables for OTP cooldown
  bool _isCooldownActive = false;
  int _cooldownSeconds = 120; // 2 minutes
  Timer? _cooldownTimer; // Make it nullable to avoid initialization issues

  // Add new variable to track if fields should be disabled
  bool _disableEmailPasswordFields = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
          ),
        );

    // Start animation after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  // Modify dispose method to handle nullable timer
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _animationController.dispose();
    _cooldownTimer?.cancel(); // Safely cancel cooldown timer if it exists
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Input validation with visual feedback
    if (email.isEmpty) {
      _shakeError('Please enter your email address');
      return;
    }

    if (password.isEmpty) {
      _shakeError('Please enter your password');
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _shakeError('Please enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      print('Attempting login for email: $email');

      // First, verify credentials with the server
      // For new users, the server will automatically create an account
      final loginWithOtpResponse = await http.post(
        Uri.parse('${AppConfig.SERVER_URL}/api/auth/login-with-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          // Send a default display name for new users
          'displayName': email.split('@')[0],
        }),
      );

      print('Login response status: ${loginWithOtpResponse.statusCode}');
      print('Login response body: ${loginWithOtpResponse.body}');

      if (loginWithOtpResponse.statusCode == 200) {
        final responseData = jsonDecode(loginWithOtpResponse.body);
        print('Login response data: $responseData');

        if (responseData['requiresOtp'] == true) {
          // Credentials verified, now show OTP field
          setState(() {
            _isLoading = false;
            _showOtpField = true;
            _otpMessage = responseData['message'];
            _disableEmailPasswordFields =
                true; // Grey out email and password fields
          });

          // No more demo OTP display since the server now simulates real email sending
        } else {
          // Direct login (fallback)
          await _completeLogin(responseData);
        }
      } else {
        print('Login failed with status: ${loginWithOtpResponse.statusCode}');
        print('Response body: ${loginWithOtpResponse.body}');

        if (loginWithOtpResponse.body.startsWith('<!doctype') ||
            loginWithOtpResponse.body.startsWith('<html') ||
            loginWithOtpResponse.body.contains('Vercel Authentication') ||
            loginWithOtpResponse.body.contains('Authentication')) {
          throw Exception(
            'Vercel Authentication Protection Detected!\n\n'
            'Your server requires authentication to access API endpoints.\n\n'
            'Please fix this by:\n'
            '1. Log in to your Vercel account\n'
            '2. Go to your project settings\n'
            '3. Navigate to the "Security" tab\n'
            '4. Disable "Authentication Protection" for API routes\n'
            '5. Redeploy your application\n\n'
            'Alternatively, use a local development server for testing.',
          );
        }

        try {
          final errorData = jsonDecode(loginWithOtpResponse.body);
          print('Error data: $errorData');
          throw Exception(errorData['error'] ?? 'Authentication failed');
        } catch (e) {
          if (e is FormatException) {
            throw Exception(
              'Unexpected server response. Please check server status.',
            );
          }
          rethrow;
        }
      }
    } on SocketException {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Network error. Please check your internet connection and try again.';
      });
    } on TimeoutException {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Server timeout. Please check your internet connection and try again.';
      });
    } catch (e) {
      print('Login error: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _handleOtpVerification() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      _shakeError('Please enter the OTP sent to your email');
      return;
    }

    if (otp.length != 6) {
      _shakeError('OTP must be 6 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Verify OTP with the server
      final verifyOtpResponse = await http.post(
        Uri.parse('${AppConfig.SERVER_URL}/api/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp}),
      );

      if (verifyOtpResponse.statusCode == 200) {
        final responseData = jsonDecode(verifyOtpResponse.body);
        await _completeLogin(responseData);
      } else {
        try {
          final errorData = jsonDecode(verifyOtpResponse.body);
          throw Exception(errorData['error'] ?? 'OTP verification failed');
        } catch (e) {
          if (e is FormatException) {
            throw Exception(
              'Unexpected server response during OTP verification. Please check server status.',
            );
          }
          rethrow;
        }
      }
    } on SocketException {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Network error. Please check your internet connection and try again.';
      });
    } on TimeoutException {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Server timeout. Please check your internet connection and try again.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _completeLogin(dynamic responseData) async {
    final email = _emailController.text.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.USER_EMAIL_KEY, email);
    await prefs.setString('user_uid', responseData['user']['uid']);
    await prefs.setString('user_name', responseData['user']['displayName']);
    await prefs.setBool('user_name_saved', true); // Mark name as saved

    // Store JWT token
    if (responseData['token'] != null) {
      await prefs.setString('auth_token', responseData['token']);
    }

    // Success animation before callback
    await _playSuccessAnimation();
    if (mounted) {
      widget.onAuthSuccess();
    }
  }

  void _shakeError(String message) {
    _animationController.animateBack(
      0.1,
      duration: Duration(milliseconds: 100),
    );
    Future.delayed(Duration(milliseconds: 100), () {
      _animationController.forward(from: 0.2);
    });
    setState(() {
      _errorMessage = message;
    });
  }

  Future<void> _playSuccessAnimation() async {
    await _animationController.animateTo(
      1.2,
      duration: Duration(milliseconds: 300),
    );
    await _animationController.animateTo(
      1.0,
      duration: Duration(milliseconds: 200),
    );
  }

  // Add this new method to handle sending OTP separately
  Future<void> _requestOtp() async {
    // Check if cooldown is active
    if (_isCooldownActive) {
      return;
    }

    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _shakeError('Please enter your email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final sendOtpResponse = await http.post(
        Uri.parse('${AppConfig.SERVER_URL}/api/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (sendOtpResponse.statusCode == 200) {
        final responseData = jsonDecode(sendOtpResponse.body);

        setState(() {
          _isLoading = false;
          _showOtpField = true;
          _otpMessage = responseData['message'];
          _disableEmailPasswordFields =
              true; // Grey out email and password fields

          // Start cooldown timer
          _startCooldown();
        });
      } else {
        try {
          final errorData = jsonDecode(sendOtpResponse.body);
          throw Exception(errorData['error'] ?? 'Failed to send OTP');
        } catch (e) {
          if (e is FormatException) {
            throw Exception(
              'Unexpected server response. Please check server status.',
            );
          }
          rethrow;
        }
      }
    } on SocketException {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Network error. Please check your internet connection and try again.';
      });
    } on TimeoutException {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Server timeout. Please check your internet connection and try again.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // Modify the _startCooldown method to properly initialize the timer
  void _startCooldown() {
    setState(() {
      _isCooldownActive = true;
      _cooldownSeconds = 120; // Reset to 2 minutes
    });

    _cooldownTimer?.cancel(); // Cancel any existing timer
    _cooldownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _cooldownSeconds--;
      });

      if (_cooldownSeconds <= 0) {
        _cooldownTimer?.cancel();
        setState(() {
          _isCooldownActive = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo with animation
                  Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: Center(
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                blurRadius: 15,
                                spreadRadius: 2,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/icons/mychatconnect.png',
                              width: 116,
                              height: 116,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title with animation
                  Opacity(
                    opacity: _fadeAnimation.value,
                    child: const Text(
                      'Welcome to MySpaceChat',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Opacity(
                    opacity: _fadeAnimation.value * 0.7,
                    child: const Text(
                      'Sign in to continue your conversations',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Error message with slide animation
                  if (_errorMessage.isNotEmpty)
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _errorMessage.contains('Vercel') ||
                                            _errorMessage.contains(
                                              'Authentication',
                                            )
                                        ? Icons.warning_amber_rounded
                                        : Icons.error_outline_rounded,
                                    color: Colors.black87,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage.contains('Vercel') ||
                                              _errorMessage.contains(
                                                'Authentication',
                                              )
                                          ? 'Server Configuration Required'
                                          : 'Authentication Error',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Form fields with staggered animation
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          // Email field - simplified without icon
                          TextField(
                            controller: _emailController,
                            enabled: !_disableEmailPasswordFields,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              hintText: 'Enter your email address',
                              labelStyle: TextStyle(
                                color: _disableEmailPasswordFields
                                    ? Colors.grey.shade400
                                    : Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                              hintStyle: TextStyle(
                                color: _disableEmailPasswordFields
                                    ? Colors.grey.shade400
                                    : Colors.grey,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _disableEmailPasswordFields
                                      ? Colors.grey.shade300
                                      : Colors.grey,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _disableEmailPasswordFields
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade400,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _disableEmailPasswordFields
                                      ? Colors.grey.shade300
                                      : Colors.black,
                                  width: _disableEmailPasswordFields
                                      ? 1.0
                                      : 2.0,
                                ),
                              ),
                              filled: true,
                              fillColor: _disableEmailPasswordFields
                                  ? Colors.grey.shade100
                                  : Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                              // No prefix icon
                            ),
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(
                              color: _disableEmailPasswordFields
                                  ? Colors.grey.shade500
                                  : Colors.black,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Password field - simplified without icon
                          TextField(
                            controller: _passwordController,
                            enabled: !_disableEmailPasswordFields,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              labelStyle: TextStyle(
                                color: _disableEmailPasswordFields
                                    ? Colors.grey.shade400
                                    : Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                              hintStyle: TextStyle(
                                color: _disableEmailPasswordFields
                                    ? Colors.grey.shade400
                                    : Colors.grey,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _disableEmailPasswordFields
                                      ? Colors.grey.shade300
                                      : Colors.grey,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _disableEmailPasswordFields
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade400,
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _disableEmailPasswordFields
                                      ? Colors.grey.shade300
                                      : Colors.black,
                                  width: _disableEmailPasswordFields
                                      ? 1.0
                                      : 2.0,
                                ),
                              ),
                              filled: true,
                              fillColor: _disableEmailPasswordFields
                                  ? Colors.grey.shade100
                                  : Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                              // No prefix icon
                              suffixIcon: IconButton(
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: _disableEmailPasswordFields
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                    key: ValueKey(_obscurePassword),
                                  ),
                                ),
                                onPressed: _disableEmailPasswordFields
                                    ? null
                                    : () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                              ),
                            ),
                            obscureText: _obscurePassword,
                            style: TextStyle(
                              color: _disableEmailPasswordFields
                                  ? Colors.grey.shade500
                                  : Colors.black,
                              fontSize: 15,
                            ),
                          ),

                          // OTP field (shown after credentials verification)
                          if (_showOtpField) ...[
                            const SizedBox(height: 20),
                            TextField(
                              controller: _otpController,
                              decoration: InputDecoration(
                                labelText: 'OTP',
                                hintText: 'Enter 6-digit code from your email',
                                labelStyle: const TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                                hintStyle: const TextStyle(color: Colors.grey),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.grey,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade400,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.black,
                                    width: 2.0,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 18,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 15,
                              ),
                            ),

                            if (_otpMessage.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  _otpMessage,
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Login button with animation - simplified without arrow
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.black,
                            width: _isLoading ? 0.5 : 1.5,
                          ),
                          boxShadow: _isLoading
                              ? []
                              : [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Material(
                          color: _isLoading
                              ? Colors.grey.shade100
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: _isLoading
                                ? null
                                : (_showOtpField
                                      ? _handleOtpVerification
                                      : _handleLogin),
                            borderRadius: BorderRadius.circular(12),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: _isLoading
                                    ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.black,
                                        ),
                                      )
                                    : Text(
                                        _showOtpField
                                            ? 'Verify OTP'
                                            : 'Login / Register',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Back button when OTP field is shown
                  if (_showOtpField)
                    Column(
                      children: [
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _showOtpField = false;
                                  _otpMessage = '';
                                  _otpController.clear();
                                  _disableEmailPasswordFields = false;
                                });
                              },
                              child: const Text(
                                'Back to Login',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Resend OTP button with cooldown
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              children: [
                                TextButton(
                                  onPressed: _isLoading || _isCooldownActive
                                      ? null
                                      : _requestOtp,
                                  child: Text(
                                    _isCooldownActive
                                        ? 'Resend OTP in $_cooldownSeconds s'
                                        : 'Resend OTP',
                                    style: TextStyle(
                                      color: _isLoading || _isCooldownActive
                                          ? Colors.grey
                                          : Colors.blue,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (_isCooldownActive)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      'Please wait before requesting another OTP',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),

                  // Info text with fade animation
                  Opacity(
                    opacity: _fadeAnimation.value * 0.6,
                    child: const Column(
                      children: [
                        Text(
                          'New to MySpaceChat?',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Enter your email and password to automatically create an account',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Decorative divider
                  Opacity(
                    opacity: _fadeAnimation.value * 0.3,
                    child: Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.grey.shade300,
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'secure connection',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.grey.shade300,
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
