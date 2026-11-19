import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Pure arithmetic evaluator used by the custom calculator keyboard.
class CalculatorEvaluator {
  static const _operators = {'+', '-', '*', '/'};

  static bool _isTrailingTrimChar(String ch) {
    return _operators.contains(ch) || ch == '.';
  }

  /// Evaluates an arithmetic expression string containing `+`, `-`, `×`/`*`, `÷`/`/`.
  ///
  /// Trailing operators or decimal points are stripped so live previews work cleanly
  /// while typing. Returns `null` on empty/invalid input or division by zero.
  static double? evaluate(String expression) {
    var cleaned = expression
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll(',', '')
        .replaceAll(RegExp(r'\s+'), '');

    while (cleaned.isNotEmpty &&
        _isTrailingTrimChar(cleaned[cleaned.length - 1])) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }

    if (cleaned.isEmpty) return null;

    final numbers = <double>[];
    final ops = <String>[];
    var i = 0;

    while (i < cleaned.length) {
      final start = i;
      if (cleaned[i] == '-' && (i == 0 || _operators.contains(cleaned[i - 1]))) {
        i++;
      }

      var hasDigit = false;
      var dotCount = 0;
      while (i < cleaned.length &&
          !_operators.contains(cleaned[i])) {
        final ch = cleaned[i];
        if (ch == '.') {
          dotCount++;
          if (dotCount > 1) return null;
        } else if (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57) {
          hasDigit = true;
        } else {
          return null;
        }
        i++;
      }

      if (!hasDigit) return null;
      final numStr = cleaned.substring(start, i);
      final parsed = double.tryParse(numStr);
      if (parsed == null) return null;
      numbers.add(parsed);

      if (i < cleaned.length) {
        final op = cleaned[i];
        if (!_operators.contains(op)) return null;
        ops.add(op);
        i++;
      }
    }

    if (numbers.isEmpty || numbers.length != ops.length + 1) return null;

    // First pass: evaluate * and / left-to-right.
    final addSubNumbers = <double>[];
    final addSubOps = <String>[];
    var current = numbers[0];

    for (var k = 0; k < ops.length; k++) {
      final op = ops[k];
      final next = numbers[k + 1];
      if (op == '*') {
        current = current * next;
      } else if (op == '/') {
        if (next == 0) return null;
        current = current / next;
      } else {
        addSubNumbers.add(current);
        addSubOps.add(op);
        current = next;
      }
    }
    addSubNumbers.add(current);

    // Second pass: evaluate + and - left-to-right.
    var total = addSubNumbers[0];
    for (var k = 0; k < addSubOps.length; k++) {
      total += addSubOps[k] == '+' ? addSubNumbers[k + 1] : -addSubNumbers[k + 1];
    }

    if (total.isNaN || total.isInfinite) return null;

    final rounded = (total * 100).roundToDouble() / 100;
    return rounded == 0 ? 0.0 : rounded;
  }

  /// Formats a numeric value cleanly (no `.0` for whole numbers, up to 2 decimals otherwise).
  static String formatNumber(double value) {
    final normalized = (value * 100).roundToDouble() / 100;
    final clean = normalized == 0 ? 0.0 : normalized;
    if ((clean - clean.roundToDouble()).abs() < 0.0001) {
      return clean.round().toString();
    }
    var str = clean.toStringAsFixed(2);
    if (str.contains('.')) {
      str = str.replaceAll(RegExp(r'0+$'), '');
      if (str.endsWith('.')) {
        str = str.substring(0, str.length - 1);
      }
    }
    return str;
  }
}

/// Opens a custom in-app calculator bottom sheet for entering or adjusting an amount.
Future<double?> showCalculatorKeyboard(
  BuildContext context, {
  double? initialValue,
  String? title,
  required String currencySymbol,
  required String Function(double) formatAmount,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CalculatorBottomSheet(
      initialValue: initialValue,
      title: title,
      currencySymbol: currencySymbol,
      formatAmount: formatAmount,
    ),
  );
}

class _CalculatorBottomSheet extends StatefulWidget {
  final double? initialValue;
  final String? title;
  final String currencySymbol;
  final String Function(double) formatAmount;

  const _CalculatorBottomSheet({
    required this.initialValue,
    required this.title,
    required this.currencySymbol,
    required this.formatAmount,
  });

  @override
  State<_CalculatorBottomSheet> createState() => _CalculatorBottomSheetState();
}

class _CalculatorBottomSheetState extends State<_CalculatorBottomSheet> {
  static const _displayOps = {'+', '-', '×', '÷'};

  late String _expression;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    _expression = (initial != null && initial > 0)
        ? CalculatorEvaluator.formatNumber(initial)
        : '0';
  }

  String get _currentSegment {
    var lastOp = -1;
    for (var i = 0; i < _expression.length; i++) {
      if (_displayOps.contains(_expression[i])) {
        // Ignore leading unary minus when checking the first segment.
        if (i == 0 && _expression[i] == '-') continue;
        lastOp = i;
      }
    }
    return _expression.substring(lastOp + 1);
  }

  void _onDigit(String digit) {
    HapticFeedback.lightImpact();
    setState(() {
      final seg = _currentSegment;
      if (seg == '0') {
        if (digit == '0' || digit == '00') return;
        _expression = _expression.substring(0, _expression.length - 1) + digit;
        return;
      }
      if (seg.isEmpty && digit == '00') {
        _expression += '0';
        return;
      }
      _expression += digit;
    });
  }

  void _onDecimal() {
    HapticFeedback.lightImpact();
    setState(() {
      final seg = _currentSegment;
      if (seg.contains('.')) return;
      if (seg.isEmpty) {
        _expression += '0.';
      } else {
        _expression += '.';
      }
    });
  }

  void _onOperator(String op) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_expression.isEmpty) {
        _expression = '0$op';
        return;
      }
      final lastChar = _expression[_expression.length - 1];
      if (_displayOps.contains(lastChar)) {
        if (_expression.length == 1 && lastChar == '-') return;
        _expression = _expression.substring(0, _expression.length - 1) + op;
      } else if (lastChar == '.') {
        _expression = _expression.substring(0, _expression.length - 1) + op;
      } else {
        _expression += op;
      }
    });
  }

  void _onClear() {
    HapticFeedback.lightImpact();
    setState(() => _expression = '0');
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_expression.length <= 1) {
        _expression = '0';
      } else {
        _expression = _expression.substring(0, _expression.length - 1);
        if (_expression == '-') _expression = '0';
      }
    });
  }

  void _onEquals() {
    HapticFeedback.lightImpact();
    final result = CalculatorEvaluator.evaluate(_expression);
    if (result == null) return;
    setState(() {
      _expression = CalculatorEvaluator.formatNumber(result);
    });
  }

  void _onDone(double? evaluated) {
    if (evaluated == null || evaluated < 0) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, evaluated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final evaluated = CalculatorEvaluator.evaluate(_expression);
    final initial = widget.initialValue;
    final hasInitial = initial != null && initial > 0;
    final diff = (hasInitial && evaluated != null) ? evaluated - initial : 0.0;
    final hasValidResult = evaluated != null && evaluated >= 0;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),

          // Title bar
          Row(
            children: [
              const Icon(Icons.calculate_rounded, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title?.isNotEmpty == true
                      ? widget.title!
                      : 'Calculate Amount',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                visualDensity: VisualDensity.compact,
                tooltip: 'Close',
              ),
            ],
          ),

          // Display box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasInitial) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current: ${widget.formatAmount(initial)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (evaluated != null && diff.abs() >= 0.01)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: (diff > 0
                                    ? AppColors.success
                                    : AppColors.error)
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            diff > 0
                                ? '+${widget.formatAmount(diff)}'
                                : '-${widget.formatAmount(diff.abs())}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: diff > 0
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Text(
                    _expression,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (evaluated == null)
                  const Text(
                    'Cannot divide by zero',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else if (evaluated < 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${widget.currencySymbol}${CalculatorEvaluator.formatNumber(evaluated)}',
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        'Amount cannot be negative',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      widget.formatAmount(evaluated),
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.accentLime
                            : AppColors.primaryTeal,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Keypad rows
          _buildRow([
            _KeySpec(
              label: 'C',
              color: AppColors.error.withValues(alpha: 0.14),
              textColor: AppColors.error,
              onTap: _onClear,
            ),
            _KeySpec(
              icon: Icons.backspace_outlined,
              color: isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
              onTap: _onBackspace,
            ),
            _KeySpec(
              label: '÷',
              isOperator: true,
              onTap: () => _onOperator('÷'),
            ),
            _KeySpec(
              label: '×',
              isOperator: true,
              onTap: () => _onOperator('×'),
            ),
          ], theme, isDark),
          const SizedBox(height: 8),
          _buildRow([
            _KeySpec(label: '7', onTap: () => _onDigit('7')),
            _KeySpec(label: '8', onTap: () => _onDigit('8')),
            _KeySpec(label: '9', onTap: () => _onDigit('9')),
            _KeySpec(
              label: '-',
              isOperator: true,
              onTap: () => _onOperator('-'),
            ),
          ], theme, isDark),
          const SizedBox(height: 8),
          _buildRow([
            _KeySpec(label: '4', onTap: () => _onDigit('4')),
            _KeySpec(label: '5', onTap: () => _onDigit('5')),
            _KeySpec(label: '6', onTap: () => _onDigit('6')),
            _KeySpec(
              label: '+',
              isOperator: true,
              onTap: () => _onOperator('+'),
            ),
          ], theme, isDark),
          const SizedBox(height: 8),
          _buildRow([
            _KeySpec(label: '1', onTap: () => _onDigit('1')),
            _KeySpec(label: '2', onTap: () => _onDigit('2')),
            _KeySpec(label: '3', onTap: () => _onDigit('3')),
            _KeySpec(
              label: '=',
              isOperator: true,
              onTap: _onEquals,
            ),
          ], theme, isDark),
          const SizedBox(height: 8),
          _buildRow([
            _KeySpec(label: '00', onTap: () => _onDigit('00')),
            _KeySpec(label: '0', onTap: () => _onDigit('0')),
            _KeySpec(label: '.', onTap: _onDecimal),
            _KeySpec(
              label: 'Done',
              icon: Icons.check_rounded,
              color: hasValidResult
                  ? AppColors.accentLime
                  : Colors.grey.withValues(alpha: 0.25),
              textColor: hasValidResult
                  ? AppColors.primaryTeal
                  : theme.textTheme.bodySmall?.color,
              onTap: hasValidResult ? () => _onDone(evaluated) : null,
            ),
          ], theme, isDark),
        ],
      ),
    );
  }

  Widget _buildRow(List<_KeySpec> keys, ThemeData theme, bool isDark) {
    return Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _buildKey(keys[i], theme, isDark)),
        ],
      ],
    );
  }

  Widget _buildKey(_KeySpec spec, ThemeData theme, bool isDark) {
    final opBg = isDark
        ? AppColors.primaryTeal.withValues(alpha: 0.65)
        : AppColors.primaryTeal.withValues(alpha: 0.12);
    final numBg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    final bgColor = spec.color ?? (spec.isOperator ? opBg : numBg);
    final fgColor = spec.textColor ??
        (spec.isOperator
            ? (isDark ? AppColors.accentLime : AppColors.primaryTeal)
            : theme.textTheme.bodyLarge?.color);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: spec.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: spec.icon != null && spec.label != null
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(spec.icon, color: fgColor, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      spec.label!,
                      style: TextStyle(
                        color: fgColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                )
              : spec.icon != null
                  ? Icon(spec.icon, color: fgColor, size: 22)
                  : Text(
                      spec.label ?? '',
                      style: TextStyle(
                        color: fgColor,
                        fontSize: spec.isOperator ? 22 : 20,
                        fontWeight:
                            spec.isOperator ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
        ),
      ),
    );
  }
}

class _KeySpec {
  final String? label;
  final IconData? icon;
  final Color? color;
  final Color? textColor;
  final bool isOperator;
  final VoidCallback? onTap;

  const _KeySpec({
    this.label,
    this.icon,
    this.color,
    this.textColor,
    this.isOperator = false,
    this.onTap,
  });
}
