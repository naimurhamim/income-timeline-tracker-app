import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const LockScreen({super.key, required this.onAuthenticated});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  String _enteredPin = '';
  String _errorMessage = '';
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );

    // Try biometric automatically on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_authService.biometricEnabled && _authService.hasBiometrics) {
        _tryBiometric();
      }
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    final success = await _authService.authenticateWithBiometrics();
    if (mounted && success) widget.onAuthenticated();
  }

  void _onDigitPressed(String digit) {
    if (_enteredPin.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin += digit;
      _errorMessage = '';
    });

    if (_enteredPin.length == 4) {
      _verifyPin();
    }
  }

  void _onDelete() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = '';
    });
  }

  Future<void> _verifyPin() async {
    final correct = await _authService.verifyPin(_enteredPin);
    if (mounted) {
      if (correct) {
        widget.onAuthenticated();
      } else {
        HapticFeedback.heavyImpact();
        _shakeController.forward(from: 0);
        setState(() {
          _enteredPin = '';
          _errorMessage = 'Wrong PIN! Try again';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B3A4B), Color(0xFF2D5F4F)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),

              // Icon + Title
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset('assets/images/app_icon.png',
                      fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'MoneyTracker',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your PIN',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 40),

              // PIN dots with shake animation
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  final offset =
                      _shakeController.isAnimating ? (_shakeAnimation.value * 8 * ((_shakeAnimation.value * 4).round() % 2 == 0 ? 1 : -1)) : 0.0;
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _enteredPin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? AppColors.accentLime
                            : Colors.white.withValues(alpha: 0.3),
                        border: Border.all(
                          color: filled
                              ? AppColors.accentLime
                              : Colors.white.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 12),

              // Error message
              AnimatedOpacity(
                opacity: _errorMessage.isEmpty ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontSize: 13,
                  ),
                ),
              ),

              const Spacer(),

              // Numpad
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  children: [
                    _buildRow(['1', '2', '3']),
                    const SizedBox(height: 16),
                    _buildRow(['4', '5', '6']),
                    const SizedBox(height: 16),
                    _buildRow(['7', '8', '9']),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Biometric button
                        if (_authService.biometricEnabled &&
                            _authService.hasBiometrics)
                          _buildSpecialButton(
                            icon: Icons.fingerprint_rounded,
                            onTap: _tryBiometric,
                          )
                        else
                          const SizedBox(width: 72),

                        _buildDigitButton('0'),

                        _buildSpecialButton(
                          icon: Icons.backspace_rounded,
                          onTap: _onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map(_buildDigitButton).toList(),
    );
  }

  Widget _buildDigitButton(String digit) {
    return GestureDetector(
      onTap: () => _onDigitPressed(digit),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.1),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
        child: Center(
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.8),
            size: 28,
          ),
        ),
      ),
    );
  }
}
