import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/entry.dart';
import '../providers/entry_provider.dart';
import '../providers/category_provider.dart';
import '../providers/currency_provider.dart';
import '../theme/app_colors.dart';

class AddEntryScreen extends StatefulWidget {
  final EntryModel? editEntry; // null = add, non-null = edit

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
  int? _selectedCategoryId;
  int _priority = 2; // Medium
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
    final isDark = theme.brightness == Brightness.dark;
    final categoryProvider = context.watch<CategoryProvider>();
    final currency = context.watch<CurrencyProvider>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── App Bar ───
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor:
                isDark ? AppColors.primaryTealDark : AppColors.primaryTeal,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                isEditing ? 'Edit Entry' : 'Add Entry',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? AppColors.headerGradientDark
                      : AppColors.headerGradient,
                ),
              ),
            ),
          ),

          // ─── Form ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    _buildLabel(theme, 'Title', Icons.title_rounded),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. DBBL FD Interest',
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Title is required' : null,
                    ),

                    const SizedBox(height: 20),

                    // Amount
                    _buildLabel(theme, 'Amount (${currency.symbol})', Icons.attach_money_rounded),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'e.g. 50000',
                        prefixText: '${currency.symbol} ',
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Amount is required';
                        if (double.tryParse(v) == null) return 'Invalid amount';
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Expected Date
                    _buildLabel(
                        theme, 'Expected Date', Icons.calendar_today_rounded),
                    const SizedBox(height: 8),
                    _buildDatePicker(theme),

                    const SizedBox(height: 20),

                    // Category / Type
                    _buildLabel(theme, 'Category', Icons.category_rounded),
                    const SizedBox(height: 8),
                    _buildCategorySelector(theme, categoryProvider),

                    const SizedBox(height: 20),

                    // Priority
                    _buildLabel(theme, 'Priority', Icons.flag_rounded),
                    const SizedBox(height: 8),
                    _buildPrioritySelector(theme),

                    const SizedBox(height: 20),

                    // Recurring
                    _buildRecurringToggle(theme),

                    if (_isRecurring) ...[
                      const SizedBox(height: 12),
                      _buildRecurringTypeSelector(theme),
                      const SizedBox(height: 12),
                      _buildRecurringExpiryToggle(theme),
                    ],

                    const SizedBox(height: 20),

                    // Notes
                    _buildLabel(theme, 'Notes (Optional)', Icons.notes_rounded),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Add any notes...',
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saveEntry,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isEditing
                                  ? Icons.save_rounded
                                  : Icons.add_rounded,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isEditing ? 'Update Entry' : 'Add Entry',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(ThemeData theme, String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.textTheme.bodySmall?.color),
        const SizedBox(width: 6),
        Text(
          text,
          style: theme.textTheme.labelLarge,
        ),
      ],
    );
  }

  Widget _buildDatePicker(ThemeData theme) {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: theme.inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              color: AppColors.primaryTeal,
            ),
            const SizedBox(width: 12),
            Text(
              DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
              style: theme.textTheme.bodyLarge,
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: theme.textTheme.bodySmall?.color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector(
      ThemeData theme, CategoryProvider categoryProvider) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categoryProvider.categories.map((cat) {
        final isSelected = _selectedType == cat.name;
        final color = Color(
          int.parse(cat.color.replaceFirst('#', '0xFF')),
        );

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedType = cat.name;
              _selectedCategoryId = cat.id;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.15)
                  : theme.inputDecorationTheme.fillColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getCategoryIcon(cat.icon),
                  size: 18,
                  color: isSelected
                      ? color
                      : theme.textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 6),
                Text(
                  cat.name,
                  style: TextStyle(
                    color: isSelected
                        ? color
                        : theme.textTheme.bodyMedium?.color,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPrioritySelector(ThemeData theme) {
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
          child: GestureDetector(
            onTap: () => setState(() => _priority = value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.15)
                    : theme.inputDecorationTheme.fillColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flag_rounded, size: 16, color: color),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? color : theme.textTheme.bodyMedium?.color,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
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

  Widget _buildRecurringToggle(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.repeat_rounded,
            color: _isRecurring ? AppColors.accentLime : theme.textTheme.bodySmall?.color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recurring',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
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
            activeThumbColor: AppColors.accentLime,
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringTypeSelector(ThemeData theme) {
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

        return GestureDetector(
          onTap: () => setState(() => _recurringType = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accentLime.withValues(alpha: 0.15)
                  : theme.inputDecorationTheme.fillColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.accentLime : Colors.transparent,
                width: 2,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.accentLime
                    : theme.textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecurringExpiryToggle(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.inputDecorationTheme.fillColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                Icons.event_busy_rounded,
                color: _hasRecurringEndDate ? AppColors.accentLime : theme.textTheme.bodySmall?.color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set Expiry Date',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
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
                      _recurringEndDate = DateTime.now().add(const Duration(days: 180));
                    }
                  });
                },
                activeThumbColor: AppColors.accentLime,
              ),
            ],
          ),
        ),
        if (_hasRecurringEndDate) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _recurringEndDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(2100),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                            primary: AppColors.primaryTeal,
                          ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => _recurringEndDate = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.inputDecorationTheme.fillColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.accentLime.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.date_range_rounded, color: AppColors.accentLime),
                  const SizedBox(width: 12),
                  Text(
                    'Ends on: ',
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    _recurringEndDate != null ? DateFormat('MMM d, yyyy').format(_recurringEndDate!) : 'Select Date',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.accentLime,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primaryTeal,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
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
      recurringEndDate: (_isRecurring && _hasRecurringEndDate) ? _recurringEndDate : null,
      isReceived: widget.editEntry?.isReceived ?? false,
      receivedDate: widget.editEntry?.receivedDate,
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
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
