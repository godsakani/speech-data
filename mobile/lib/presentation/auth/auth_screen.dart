import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';

import '../dashboard/dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isChecking = true;
  bool _isAuthenticating = false;
  bool _canCheckBiometrics = false;
  List<BiometricType> _availableBiometrics = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      List<BiometricType> available = [];
      if (canCheck && isDeviceSupported) {
        available = await _localAuth.getAvailableBiometrics();
      }
      if (!mounted) return;
      setState(() {
        _canCheckBiometrics = canCheck && isDeviceSupported;
        _availableBiometrics = available;
        _isChecking = false;
        if (!_canCheckBiometrics && available.isEmpty) {
          _errorMessage = 'Biometrics not available on this device.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _canCheckBiometrics = false;
        _availableBiometrics = [];
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _authenticate() async {
    if (!_canCheckBiometrics && _availableBiometrics.isEmpty) {
      Get.snackbar(
        'Not available',
        'Biometric authentication is not available on this device.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final success = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access Speech Parallel Data',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (!mounted) return;
      if (success) {
        Get.offAll(() => const DashboardScreen());
      } else {
        setState(() {
          _isAuthenticating = false;
          _errorMessage = 'Authentication failed or was cancelled.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String get _biometricHint {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Use Face ID to unlock';
    }
    if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Use your fingerprint to unlock';
    }
    if (_availableBiometrics.contains(BiometricType.strong) ||
        _availableBiometrics.contains(BiometricType.weak)) {
      return 'Use device authentication to unlock';
    }
    return 'Authenticate to continue';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surface,
              colorScheme.primaryContainer.withValues(alpha: 0.2),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.fingerprint_rounded,
                    size: 88,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Secure access',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _biometricHint,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                if (_isChecking)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator.adaptive(),
                  )
                else ...[
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: colorScheme.error,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  FilledButton(
                    onPressed: _isAuthenticating ? null : _authenticate,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: _isAuthenticating
                        ? SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Authenticate'),
                  ),
                  if (!_canCheckBiometrics) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Get.offAll(() => const DashboardScreen()),
                      child: Text(
                        'Continue without biometrics',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
