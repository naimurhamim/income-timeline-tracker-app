import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final AuthService _authService = AuthService();
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _errorMessage = '';

  void _onDigit(String digit) {
    HapticFeedback.lightImpact();
    final current = _isConfirming ? _confirmPin : _pin;
    if (current.length >= 4) return;

    setState(() {
      _errorMessage = '';
      if (_isConfirming) {
        _confirmPin += digit;
      } else {
        _pin += digit;
      }
    });

    final updated = _isConfirming ? _confirmPin : _pin;
    if (updated.length == 4) {
      if (!_isConfirming) {
        setState(() => _isConfirming = true);
      } else {
        _finalizePin();
      }
    }
  }

  void _onDelete() {
    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = '';
      if (_isConfirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          // Go back to first step
          _isConfirming = false;
          _pin = '';
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  Future<void> _finalizePin() async {
    if (_pin == _confirmPin) {
      await _authService.setPin(_pin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PIN has been set!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = "PIN doesn't match! Try again";
        _confirmPin = '';
        _pin = '';
        _isConfirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = _isConfirming ? _confirmPin : _pin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set PIN'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          const Spacer(),

          // Icon
          Icon(
            _isConfirming ? Icons.lock_reset_rounded : Icons.lock_rounded,
            size: 56,
            color: AppColors.primaryTeal,
          ),
          const SizedBox(height: 16),

          Text(
            _isConfirming ? 'Confirm PIN' : 'Enter a 4-digit PIN',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isConfirming
                ? 'Type the same PIN again'
                : 'This PIN will lock the app',
            style: theme.textTheme.bodySmall,
          ),

          const SizedBox(height: 40),

          // PIN dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final filled = i < current.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? AppColors.primaryTeal : Colors.transparent,
                  border: Border.all(
                    color: filled
                        ? AppColors.primaryTeal
                        : theme.dividerColor,
                    width: 2,
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 12),

          // Error
          AnimatedOpacity(
            opacity: _errorMessage.isEmpty ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: Text(
              _errorMessage,
              style: const TextStyle(
                color: AppColors.error,
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
                _buildRow(theme, ['1', '2', '3']),
                const SizedBox(height: 12),
                _buildRow(theme, ['4', '5', '6']),
                const SizedBox(height: 12),
                _buildRow(theme, ['7', '8', '9']),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const SizedBox(width: 72),
                    _buildDigitButton(theme, '0'),
                    _buildSpecialButton(
                      theme: theme,
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
    );
  }

  Widget _buildRow(ThemeData theme, List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildDigitButton(theme, d)).toList(),
    );
  }

  Widget _buildDigitButton(ThemeData theme, String digit) {
    return GestureDetector(
      onTap: () => _onDigit(digit),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: Center(
          child: Text(
            digit,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialButton({
    required ThemeData theme,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Center(
          child: Icon(icon, color: theme.iconTheme.color, size: 26),
        ),
      ),
    );
  }
}
