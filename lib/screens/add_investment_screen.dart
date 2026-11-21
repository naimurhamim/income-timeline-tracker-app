import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/investment.dart';
import '../providers/currency_provider.dart';
import '../providers/investment_provider.dart';
import '../theme/app_colors.dart';
import '../theme/glass_tokens.dart';
import '../widgets/calculator_keyboard.dart';
import '../widgets/glass_surface.dart';

/// Formats an investment amount cleanly (omits `.00` for whole numbers).
String formatInvestmentAmount(CurrencyProvider currency, double amount) {
  final isWhole = (amount - amount.roundToDouble()).abs() < 0.005;
  return currency.format(amount, decimalDigits: isWhole ? 0 : 2);
}

/// Shows a verification dialog confirming how much principal capital was added or removed.
Future<bool> showAmountVerificationDialog(
  BuildContext context, {
  required String title,
  required double oldAmount,
  required double newAmount,
  required CurrencyProvider currency,
}) async {
  final diff = newAmount - oldAmount;
  final isAdded = diff > 0;
  final absDiff = diff.abs();
  final diffFormatted = formatInvestmentAmount(currency, absDiff);
  final oldFormatted = formatInvestmentAmount(currency, oldAmount);
  final newFormatted = formatInvestmentAmount(currency, newAmount);
  final accentColor = isAdded ? AppColors.success : AppColors.error;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final g = ctx.glass;
      return AlertDialog(
        backgroundColor: g.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: g.glassBorder),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isAdded
                    ? Icons.add_circle_rounded
                    : Icons.remove_circle_rounded,
                color: accentColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Confirm Amount Update',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isAdded ? '+$diffFormatted Added' : '-$diffFormatted Removed',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isAdded
                  ? '$diffFormatted has been added to $title. New amount will be $newFormatted.'
                  : '$diffFormatted has been removed from $title. New amount will be $newFormatted.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: g.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: g.surfaceSubtle,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _summaryRow(theme, g, 'Previous', oldFormatted),
                  const SizedBox(height: 8),
                  _summaryRow(
                    theme,
                    g,
                    'Change',
                    isAdded ? '+$diffFormatted' : '-$diffFormatted',
                    valueColor: accentColor,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1),
                  ),
                  _summaryRow(
                    theme,
                    g,
                    'New Amount',
                    newFormatted,
                    isBold: true,
                    valueColor: g.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

Widget _summaryRow(
  ThemeData theme,
  GlassTokens g,
  String label,
  String value, {
  Color? valueColor,
  bool isBold = false,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: theme.textTheme.bodySmall),
      Text(
        value,
        style: TextStyle(
          fontSize: isBold ? 15 : 13.5,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          color: valueColor ?? g.textPrimary,
        ),
      ),
    ],
  );
}

/// Shows a SnackBar summarizing the verified addition or removal of capital.
void showAmountUpdatedSnackBar(
  BuildContext context, {
  required String title,
  required double oldAmount,
  required double newAmount,
  required CurrencyProvider currency,
  ScaffoldMessengerState? messenger,
}) {
  final diff = newAmount - oldAmount;
  final isAdded = diff > 0;
  final diffFormatted = formatInvestmentAmount(currency, diff.abs());
  final newFormatted = formatInvestmentAmount(currency, newAmount);
  final target = messenger ?? ScaffoldMessenger.of(context);

  target
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          isAdded
              ? 'Added $diffFormatted to $title · Now $newFormatted'
              : 'Removed $diffFormatted from $title · Now $newFormatted',
        ),
      ),
    );
}

/// Screen for adding or editing a principal investment record.
class AddInvestmentScreen extends StatefulWidget {
  final InvestmentModel? editInvestment;

  const AddInvestmentScreen({super.key, this.editInvestment});

  @override
  State<AddInvestmentScreen> createState() => _AddInvestmentScreenState();
}

class _AddInvestmentScreenState extends State<AddInvestmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  late String _selectedType;
  late String _selectedIcon;
  late String _selectedColor;
  late DateTime _selectedDate;
  late double _amount;
  final List<InvestmentTypePreset> _sessionCustomTypes = [];

  bool get isEditing => widget.editInvestment != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.editInvestment;
    if (existing != null) {
      _titleController.text = existing.title;
      _notesController.text = existing.notes ?? '';
      _selectedType = existing.type;
      _selectedIcon = existing.icon;
      _selectedColor = existing.color;
      _selectedDate = existing.investedDate;
      _amount = existing.amount;
    } else {
      final first = InvestmentModel.defaultTypes.first;
      _selectedType = first.name;
      _selectedIcon = first.icon;
      _selectedColor = first.color;
      _selectedDate = DateTime.now();
      _amount = 0;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<InvestmentTypePreset> _collectTypes(InvestmentProvider provider) {
    final presets = <InvestmentTypePreset>[...provider.allAvailableTypePresets];
    final seen = presets.map((p) => p.name.trim().toLowerCase()).toSet();

    for (final custom in _sessionCustomTypes) {
      final key = custom.name.trim().toLowerCase();
      if (key.isNotEmpty && !seen.contains(key)) {
        seen.add(key);
        presets.add(custom);
      }
    }
    return presets;
  }

  Future<void> _openCalculator(
    CurrencyProvider currency,
    FormFieldState<double> fieldState,
  ) async {
    final title = _titleController.text.trim();
    final result = await showCalculatorKeyboard(
      context,
      initialValue: _amount > 0 ? _amount : null,
      title: title.isNotEmpty ? title : '$_selectedType Principal',
      currencySymbol: currency.symbol,
      formatAmount: (v) => formatInvestmentAmount(currency, v),
    );
    if (result == null || !mounted) return;
    setState(() => _amount = result);
    fieldState.didChange(result);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _showCustomTypeDialog(BuildContext context) async {
    final nameController = TextEditingController();
    var chosenIcon = 'wallet';
    var chosenColor = '#1B3A4B';
    String? nameError;
    final g = context.glass;

    final created = await showDialog<InvestmentTypePreset>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: g.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: g.glassBorder),
          ),
          title: const Text('Custom Investment Type'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g. Business, Land, Crypto',
                    errorText: nameError,
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Icon'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: InvestmentModel.iconOptions.entries.map((e) {
                    final isSelected = chosenIcon == e.key;
                    return GestureDetector(
                      onTap: () => setDialogState(() => chosenIcon = e.key),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected ? g.primary : g.surfaceSubtle,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          e.value,
                          color: isSelected ? g.onPrimary : g.textSecondary,
                          size: 20,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Color'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppColors.categoryColors.map((color) {
                    final hex =
                        '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                    final isSelected = chosenColor == hex;
                    return GestureDetector(
                      onTap: () => setDialogState(() => chosenColor = hex),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => nameError = 'Type name is required');
                  return;
                }
                Navigator.pop(
                  ctx,
                  InvestmentTypePreset(
                    name: name,
                    icon: chosenIcon,
                    color: chosenColor,
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();

    if (created == null || !mounted) return;
    setState(() {
      _sessionCustomTypes.add(created);
      _selectedType = created.name;
      _selectedIcon = created.icon;
      _selectedColor = created.color;
    });
  }

  Future<void> _confirmDelete() async {
    final existing = widget.editInvestment;
    if (existing == null) return;
    final g = context.glass;
    final currency = context.read<CurrencyProvider>();
    final provider = context.read<InvestmentProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: g.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: g.glassBorder),
        ),
        title: const Text('Delete Investment?'),
        content: Text(
          'Remove "${existing.title}" (${formatInvestmentAmount(currency, existing.amount)}) from your principal investments?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await provider.deleteInvestment(existing.id);
    if (!mounted) return;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Deleted "${existing.title}"'),
        ),
      );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final notesText = _notesController.text.trim();
    final notes = notesText.isEmpty ? null : notesText;
    final provider = context.read<InvestmentProvider>();
    final currency = context.read<CurrencyProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (isEditing) {
      final old = widget.editInvestment!;
      final amountChanged = (_amount - old.amount).abs() >= 0.01;
      if (amountChanged) {
        final confirmed = await showAmountVerificationDialog(
          context,
          title: title,
          oldAmount: old.amount,
          newAmount: _amount,
          currency: currency,
        );
        if (!confirmed || !mounted) return;
      }

      final updated = old.copyWith(
        title: title,
        amount: _amount,
        type: _selectedType,
        icon: _selectedIcon,
        color: _selectedColor,
        investedDate: _selectedDate,
        notes: notes,
        updatedAt: DateTime.now(),
      );
      await provider.updateInvestment(updated);
      if (!mounted) return;
      navigator.pop();

      if (amountChanged) {
        showAmountUpdatedSnackBar(
          context,
          title: title,
          oldAmount: old.amount,
          newAmount: _amount,
          currency: currency,
          messenger: messenger,
        );
      } else {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Updated $title'),
            ),
          );
      }
      return;
    }

    final investment = InvestmentModel(
      title: title,
      amount: _amount,
      type: _selectedType,
      icon: _selectedIcon,
      color: _selectedColor,
      investedDate: _selectedDate,
      notes: notes,
    );
    await provider.addInvestment(investment);
    if (!mounted) return;
    final totalAfter = provider.totalInvested;
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Added ${formatInvestmentAmount(currency, _amount)} to $title · Total Invested: ${formatInvestmentAmount(currency, totalAfter)}',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = context.glass;
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<InvestmentProvider>();
    final currency = context.watch<CurrencyProvider>();
    final types = _collectTypes(provider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
              child: Column(
                children: [
                  // ─── Top Glass Bar ───
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        GlassCircleButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Back',
                          size: 42,
                          onTap: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            isEditing ? 'Edit Investment' : 'Add Investment',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (isEditing)
                          GlassCircleButton(
                            icon: Icons.delete_outline_rounded,
                            iconColor: g.danger,
                            tooltip: 'Delete Investment',
                            size: 42,
                            onTap: _confirmDelete,
                          ),
                      ],
                    ),
                  ),

                  // ─── Form Body ───
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.xxl,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAmountHeroCard(
                              theme,
                              g,
                              isDark,
                              currency,
                            ),
                            const SizedBox(height: 22),
                            _buildLabel(theme, g, 'Investment Type',
                                Icons.category_rounded),
                            const SizedBox(height: 10),
                            _buildTypeSelector(theme, g, isDark, types),
                            const SizedBox(height: 20),
                            _buildLabel(theme, g, 'Title', Icons.title_rounded),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _titleController,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                hintText: 'e.g. Sonali Bank FD, 2 Vori Gold',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Title is required'
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            _buildLabel(theme, g, 'Date',
                                Icons.calendar_today_rounded),
                            const SizedBox(height: 8),
                            _buildDatePicker(theme, g),
                            const SizedBox(height: 20),
                            _buildLabel(theme, g, 'Notes (Optional)',
                                Icons.notes_rounded),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _notesController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText:
                                    'e.g. Bank name, account no., gold weight...',
                              ),
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: FilledButton.icon(
                                onPressed: _save,
                                icon: Icon(
                                  isEditing
                                      ? Icons.save_rounded
                                      : Icons.add_rounded,
                                ),
                                label: Text(
                                  isEditing
                                      ? 'Update Investment'
                                      : 'Add Investment',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(
      ThemeData theme, GlassTokens g, String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: g.textSecondary),
        const SizedBox(width: 6),
        Text(text, style: theme.textTheme.labelLarge),
      ],
    );
  }

  Widget _buildTypeSelector(
    ThemeData theme,
    GlassTokens g,
    bool isDark,
    List<InvestmentTypePreset> types,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...types.map((preset) {
          final isSelected = _selectedType.trim().toLowerCase() ==
              preset.name.trim().toLowerCase();
          final color =
              AppColors.adaptiveColor(preset.displayColor, isDark);

          return GlassContainer(
            borderRadius: AppRadius.pill,
            blur: 0,
            elevated: isSelected,
            fillColor: isSelected
                ? color.withValues(alpha: isDark ? 0.24 : 0.16)
                : g.glassFill,
            borderColor: isSelected ? color : g.glassBorder,
            onTap: () {
              setState(() {
                _selectedType = preset.name;
                _selectedIcon = preset.icon;
                _selectedColor = preset.color;
              });
            },
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  InvestmentModel.iconDataFor(preset.icon),
                  size: 17,
                  color: isSelected ? color : g.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  preset.name,
                  style: TextStyle(
                    color: isSelected ? color : g.textPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }),
        GlassPillButton(
          icon: Icons.add_rounded,
          label: 'Custom',
          iconColor: g.primary,
          selected: true,
          onTap: () => _showCustomTypeDialog(context),
        ),
      ],
    );
  }

  Widget _buildAmountHeroCard(
    ThemeData theme,
    GlassTokens g,
    bool isDark,
    CurrencyProvider currency,
  ) {
    final editDiff = isEditing ? _amount - widget.editInvestment!.amount : 0.0;
    final hasEditDelta = isEditing && editDiff.abs() >= 0.01;
    final isAdded = editDiff > 0;
    final hasAmount = _amount > 0 || isEditing;

    return FormField<double>(
      initialValue: _amount,
      validator: (val) {
        final v = val ?? _amount;
        if (!isEditing && v <= 0) {
          return 'Please enter a principal amount greater than 0';
        }
        if (v < 0) return 'Amount cannot be negative';
        return null;
      },
      builder: (fieldState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: isDark
                    ? const RadialGradient(
                        center: Alignment(0, -0.9),
                        radius: 1.25,
                        colors: [
                          Color(0xFF173D28),
                          Color(0xFF09140E),
                        ],
                      )
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFFFFF),
                          Color(0xFFEAF2EC),
                        ],
                      ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                  color: fieldState.hasError
                      ? g.danger
                      : isDark
                          ? AppColors.accentMintLight.withValues(alpha: 0.34)
                          : g.primary.withValues(alpha: 0.24),
                  width: 1.3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? AppColors.accentMintLight.withValues(alpha: 0.14)
                        : g.glassShadow,
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  onTap: () => _openCalculator(currency, fieldState),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: 22,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'PRINCIPAL AMOUNT',
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                            color: g.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            hasAmount
                                ? formatInvestmentAmount(currency, _amount)
                                : '${currency.symbol}0',
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.1,
                              color: hasAmount
                                  ? g.textPrimary
                                  : g.textSecondary.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: g.primarySoft,
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: g.primary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calculate_rounded,
                                size: 16,
                                color: g.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                hasAmount
                                    ? 'Tap to recalculate'
                                    : 'Tap to calculate',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: g.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (fieldState.hasError) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  fieldState.errorText!,
                  style: TextStyle(color: g.danger, fontSize: 12),
                ),
              ),
            ],
            if (hasEditDelta) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: (isAdded ? AppColors.success : AppColors.error)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isAdded ? AppColors.success : AppColors.error)
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAdded
                          ? Icons.add_circle_outline_rounded
                          : Icons.remove_circle_outline_rounded,
                      size: 18,
                      color: isAdded ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isAdded
                            ? 'Added ${formatInvestmentAmount(currency, editDiff.abs())} · New amount: ${formatInvestmentAmount(currency, _amount)}'
                            : 'Removed ${formatInvestmentAmount(currency, editDiff.abs())} · New amount: ${formatInvestmentAmount(currency, _amount)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isAdded ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDatePicker(ThemeData theme, GlassTokens g) {
    return GlassContainer(
      borderRadius: AppRadius.md,
      blur: 0,
      elevated: true,
      onTap: _pickDate,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Icon(Icons.calendar_month_rounded, color: g.primary),
          const SizedBox(width: 12),
          Text(
            DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
            style: theme.textTheme.bodyLarge,
          ),
          const Spacer(),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 16, color: g.textSecondary),
        ],
      ),
    );
  }
}
