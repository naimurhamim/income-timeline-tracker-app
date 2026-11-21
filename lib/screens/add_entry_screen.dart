import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entry.dart';
import '../providers/category_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/entry_provider.dart';
import '../theme/app_colors.dart';
import '../theme/glass_tokens.dart';
import '../widgets/glass_surface.dart';

class AddEntryScreen extends StatefulWidget {
  final EntryModel? editEntry;

  const AddEntryScreen({super.key, this.editEntry});

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));
  String _selectedType = 'FD';
  String? _selectedCategoryId;
  int _priority = 2;
  bool _isRecurring = false;
  String? _recurringType;
  bool _hasRecurringEndDate = false;
  DateTime? _recurringEndDate;

  bool get isEditing => widget.editEntry != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final e = widget.editEntry!;
      _titleController.text = e.title;
      _amountController.text = e.amount.toStringAsFixed(0);
      _notesController.text = e.notes ?? '';
      _selectedDate = e.expectedDate;
      _selectedType = e.type;
      _selectedCategoryId = e.categoryId;
      _priority = e.priority;
      _isRecurring = e.isRecurring;
      _recurringType = e.recurringType;
      if (e.recurringEndDate != null) {
        _hasRecurringEndDate = true;
        _recurringEndDate = e.recurringEndDate;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = context.glass;
    final isDark = theme.brightness == Brightness.dark;
    final categoryProvider = context.watch<CategoryProvider>();
    final currency = context.watch<CurrencyProvider>();

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
                        Text(
                          isEditing ? 'Edit Entry' : 'Add Entry',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                            _buildAmountHeroCard(theme, g, isDark, currency),
                            const SizedBox(height: 22),
                            _buildLabel(theme, g, 'Title', Icons.title_rounded),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                hintText: 'e.g. DBBL FD Interest',
                              ),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Title is required'
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            _buildLabel(theme, g, 'Expected Date',
                                Icons.calendar_today_rounded),
                            const SizedBox(height: 8),
                            _buildDatePicker(theme, g),
                            const SizedBox(height: 20),
                            _buildLabel(
                                theme, g, 'Category', Icons.category_rounded),
                            const SizedBox(height: 8),
                            _buildCategorySelector(
                                theme, g, isDark, categoryProvider),
                            const SizedBox(height: 20),
                            _buildLabel(
                                theme, g, 'Priority', Icons.flag_rounded),
                            const SizedBox(height: 8),
                            _buildPrioritySelector(theme, g),
                            const SizedBox(height: 20),
                            _buildRecurringToggle(theme, g),
                            if (_isRecurring) ...[
                              const SizedBox(height: 12),
                              _buildRecurringTypeSelector(theme, g),
                              const SizedBox(height: 12),
                              _buildRecurringExpiryToggle(theme, g),
                            ],
                            const SizedBox(height: 20),
                            _buildLabel(theme, g, 'Notes (Optional)',
                                Icons.notes_rounded),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _notesController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Add any notes...',
                              ),
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: FilledButton.icon(
                                onPressed: _saveEntry,
                                icon: Icon(isEditing
                                    ? Icons.save_rounded
                                    : Icons.add_rounded),
                                label: Text(
                                  isEditing ? 'Update Entry' : 'Add Entry',
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

  Widget _buildAmountHeroCard(
    ThemeData theme,
    GlassTokens g,
    bool isDark,
    CurrencyProvider currency,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: 22,
      ),
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
          color: isDark
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
      child: Column(
        children: [
          Text(
            'EXPECTED AMOUNT (${currency.symbol})',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              color: g.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
              color: g.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: '${currency.symbol}0',
              hintStyle: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: g.textSecondary.withValues(alpha: 0.45),
              ),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
            ),
            validator: (v) {
              final raw = v?.trim() ?? '';
              if (raw.isEmpty) {
                return 'Amount is required';
              }
              if (double.tryParse(raw) == null) {
                return 'Invalid amount';
              }
              return null;
            },
          ),
        ],
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

  Widget _buildCategorySelector(
    ThemeData theme,
    GlassTokens g,
    bool isDark,
    CategoryProvider categoryProvider,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categoryProvider.categories.map((cat) {
        final isSelected = _selectedType == cat.name;
        final rawColor = Color(
          int.parse(cat.color.replaceFirst('#', '0xFF')),
        );
        final color = AppColors.adaptiveColor(rawColor, isDark);

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
              _selectedType = cat.name;
              _selectedCategoryId = cat.id;
            });
          },
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getCategoryIcon(cat.icon),
                size: 17,
                color: isSelected ? color : g.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                cat.name,
                style: TextStyle(
                  color: isSelected ? color : g.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPrioritySelector(ThemeData theme, GlassTokens g) {
    final priorities = [
      {'value': 1, 'label': 'Low', 'color': AppColors.priorityLow},
      {'value': 2, 'label': 'Medium', 'color': AppColors.priorityMedium},
      {'value': 3, 'label': 'High', 'color': AppColors.priorityHigh},
    ];

    return Row(
      children: priorities.map((p) {
        final value = p['value'] as int;
        final label = p['label'] as String;
        final color = p['color'] as Color;
        final isSelected = _priority == value;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GlassContainer(
              borderRadius: AppRadius.md,
              blur: 0,
              elevated: isSelected,
              fillColor: isSelected
                  ? color.withValues(alpha: 0.16)
                  : g.glassFill,
              borderColor: isSelected ? color : g.glassBorder,
              onTap: () => setState(() => _priority = value),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flag_rounded, size: 16, color: color),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? color : g.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecurringToggle(ThemeData theme, GlassTokens g) {
    return GlassContainer(
      borderRadius: AppRadius.md,
      blur: 0,
      elevated: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.repeat_rounded,
            color: _isRecurring ? g.primary : g.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recurring',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Auto-create next entry when received',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Switch(
            value: _isRecurring,
            onChanged: (v) => setState(() => _isRecurring = v),
            activeThumbColor: g.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringTypeSelector(ThemeData theme, GlassTokens g) {
    final types = [
      {'value': 'monthly', 'label': 'Monthly'},
      {'value': 'quarterly', 'label': 'Quarterly'},
      {'value': 'half_yearly', 'label': 'Half Yearly'},
      {'value': 'yearly', 'label': 'Yearly'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((t) {
        final value = t['value'] as String;
        final label = t['label'] as String;
        final isSelected = _recurringType == value;

        return GlassContainer(
          borderRadius: AppRadius.pill,
          blur: 0,
          elevated: isSelected,
          fillColor: isSelected ? g.primarySoft : g.glassFill,
          borderColor: isSelected ? g.primary : g.glassBorder,
          onTap: () => setState(() => _recurringType = value),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? g.primary : g.textPrimary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecurringExpiryToggle(ThemeData theme, GlassTokens g) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassContainer(
          borderRadius: AppRadius.md,
          blur: 0,
          elevated: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.event_busy_rounded,
                color: _hasRecurringEndDate ? g.primary : g.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set Expiry Date',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Stop recurring after a certain date',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Switch(
                value: _hasRecurringEndDate,
                onChanged: (v) {
                  setState(() {
                    _hasRecurringEndDate = v;
                    if (v && _recurringEndDate == null) {
                      _recurringEndDate =
                          DateTime.now().add(const Duration(days: 180));
                    }
                  });
                },
                activeThumbColor: g.primary,
              ),
            ],
          ),
        ),
        if (_hasRecurringEndDate) ...[
          const SizedBox(height: 10),
          GlassContainer(
            borderRadius: AppRadius.md,
            blur: 0,
            elevated: true,
            borderColor: g.primary.withValues(alpha: 0.45),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _recurringEndDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(2100),
              );
              if (picked != null && mounted) {
                setState(() => _recurringEndDate = picked);
              }
            },
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.date_range_rounded, color: g.primary),
                const SizedBox(width: 12),
                Text('Ends on: ', style: theme.textTheme.titleSmall),
                Text(
                  _recurringEndDate != null
                      ? DateFormat('MMM d, yyyy').format(_recurringEndDate!)
                      : 'Select Date',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: g.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'description':
        return Icons.description_rounded;
      case 'security':
        return Icons.security_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  void _saveEntry() {
    if (!_formKey.currentState!.validate()) return;

    if (_isRecurring && _recurringType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a recurring frequency'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final entry = EntryModel(
      id: widget.editEntry?.id,
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text.trim()),
      expectedDate: _selectedDate,
      type: _selectedType,
      categoryId: _selectedCategoryId,
      priority: _priority,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      isRecurring: _isRecurring,
      recurringType: _isRecurring ? _recurringType : null,
      recurringEndDate:
          (_isRecurring && _hasRecurringEndDate) ? _recurringEndDate : null,
      isReceived: widget.editEntry?.isReceived ?? false,
      receivedDate: widget.editEntry?.receivedDate,
      parentId: widget.editEntry?.parentId,
      createdAt: widget.editEntry?.createdAt,
    );

    final provider = context.read<EntryProvider>();
    if (isEditing) {
      provider.updateEntry(entry);
    } else {
      provider.addEntry(entry);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEditing ? 'Entry updated!' : 'Entry added!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
