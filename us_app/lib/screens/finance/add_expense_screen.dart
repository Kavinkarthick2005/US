import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../config/app_colors.dart';
import '../../models/expense_model.dart';
import '../../providers/couple_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/rose_button.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _amountCtrl = TextEditingController();
  final _descCtrl   = TextEditingController();

  String?  _selectedCategory;
  DateTime _spentAt       = DateTime.now();
  bool     _isLoan        = false;
  int      _loanDirection = 0; // 0 = I owe her, 1 = She owes me
  bool     _isSaving      = false;

  static const _categories = [
    (key: ExpenseModel.catFood,         label: 'Food',         emoji: '🍕'),
    (key: ExpenseModel.catDate,         label: 'Date',         emoji: '💕'),
    (key: ExpenseModel.catTravel,       label: 'Travel',       emoji: '✈️'),
    (key: ExpenseModel.catGift,         label: 'Gift',         emoji: '🎁'),
    (key: ExpenseModel.catSubscription, label: 'Subscription', emoji: '📱'),
    (key: ExpenseModel.catOther,        label: 'Other',        emoji: '📝'),
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(ThemeColors tc) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _spentAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: tc.iconColor,
            surface: tc.cardColor,
            onSurface: tc.textPrimary,
          ),
          dialogBackgroundColor: tc.backgroundColor,
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _spentAt = picked);
  }

  Future<void> _submit() async {
    final amountText = _amountCtrl.text.trim();
    final amount     = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      _showError('Enter a valid amount');
      return;
    }
    if (_selectedCategory == null) {
      _showError('Pick a category');
      return;
    }

    final coupleState = ref.read(coupleProvider).valueOrNull;
    final myId        = coupleState?.currentUser?.id;
    final partnerId   = coupleState?.partner?.id;
    
    if (myId == null) {
      _showError('Session not found');
      return;
    }
    final coupleId    = coupleState?.coupleId ?? myId;

    if (_isLoan && partnerId == null) {
      _showError('Partner not linked yet. Cannot create a loan.');
      return;
    }

    String? loanTo;
    if (_isLoan) {
      loanTo = _loanDirection == 0 ? partnerId : myId;
    }

    setState(() => _isSaving = true);

    try {
      final expense = ExpenseModel(
        id:          const Uuid().v4(),
        coupleId:    coupleId,
        addedBy:     myId,
        amount:      amount,
        category:    _selectedCategory!,
        description: _descCtrl.text.trim(),
        isLoan:      _isLoan,
        loanTo:      loanTo,
        isPaid:      false,
        spentAt:     _spentAt,
        createdAt:   DateTime.now(),
      );

      await ref.read(expenseProvider.notifier).addExpense(expense);

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added 💸',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w500),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
      _showError('Failed to save. Try again.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.dmSans()),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = ref.watch(themeProvider).colors;

    return Scaffold(
      backgroundColor: tc.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
          color: tc.textPrimary,
        ),
        title: Text(
          'Add Expense',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: tc.textPrimary,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // ── Amount ──────────────────────────────────────────────────
            _AmountField(controller: _amountCtrl, tc: tc),
            const SizedBox(height: 20),

            // ── Description ─────────────────────────────────────────────
            _card(
              tc: tc,
              child: TextField(
                controller: _descCtrl,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  color: tc.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'What was this for?',
                  hintStyle: GoogleFonts.dmSans(
                    color: tc.textMuted,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            const SizedBox(height: 20),

            // ── Category ────────────────────────────────────────────────
            _SectionLabel(label: 'Category', tc: tc),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _categories.map((c) {
                final selected = _selectedCategory == c.key;
                return _CategoryChip(
                  emoji:    c.emoji,
                  label:    c.label,
                  selected: selected,
                  tc:       tc,
                  onTap:    () => setState(() => _selectedCategory = c.key),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Date ────────────────────────────────────────────────────
            _SectionLabel(label: 'Date', tc: tc),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _pickDate(tc),
              child: _card(
                tc: tc,
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 18, color: tc.iconColor),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('EEE, d MMM yyyy').format(_spentAt),
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        color: tc.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded,
                        size: 20, color: tc.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Loan toggle ─────────────────────────────────────────────
            _card(
              tc: tc,
              child: Row(
                children: [
                  Icon(Icons.swap_horiz_rounded,
                      size: 20,
                      color: _isLoan ? AppColors.warning : tc.textMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This is a loan',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: tc.textPrimary,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: _isLoan,
                    activeThumbColor: AppColors.warning,
                    activeTrackColor: AppColors.warning.withValues(alpha: 0.4),
                    onChanged: (v) => setState(() => _isLoan = v),
                  ),
                ],
              ),
            ),

            // ── Loan direction (visible only when isLoan) ───────────────
            AnimatedCrossFade(
              firstChild: const SizedBox(height: 0),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _LoanDirectionPicker(
                  selected: _loanDirection,
                  tc: tc,
                  onChanged: (v) => setState(() => _loanDirection = v),
                ),
              ),
              crossFadeState: _isLoan
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),

            const SizedBox(height: 32),

            // ── Add button ──────────────────────────────────────────────
            RoseButton(
              label:     'Add',
              isLoading: _isSaving,
              onTap:     _isSaving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required ThemeColors tc, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Amount field ─────────────────────────────────────────────────────────────

class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, required this.tc});

  final TextEditingController controller;
  final ThemeColors tc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: tc.iconColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: tc.iconColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '₹',
            style: GoogleFonts.dmMono(
              fontSize: 36,
              fontWeight: FontWeight.w600,
              color: tc.iconColor,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: GoogleFonts.dmMono(
                fontSize: 40,
                fontWeight: FontWeight.w600,
                color: tc.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: GoogleFonts.dmMono(
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                  color: tc.textMuted.withValues(alpha: 0.4),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              textAlign: TextAlign.center,
              autofocus: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category chip ─────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.tc,
    required this.onTap,
  });

  final String   emoji;
  final String   label;
  final bool     selected;
  final ThemeColors tc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? tc.iconColor.withValues(alpha: 0.15)
              : tc.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? tc.iconColor : tc.borderColor,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: tc.iconColor.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? tc.iconColor
                    : tc.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loan direction picker ─────────────────────────────────────────────────────

class _LoanDirectionPicker extends StatelessWidget {
  const _LoanDirectionPicker({
    required this.selected,
    required this.tc,
    required this.onChanged,
  });

  final int      selected;
  final ThemeColors tc;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Who owes?',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tc.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DirectionOption(
                  label:    'I owe her',
                  icon:     Icons.arrow_upward_rounded,
                  selected: selected == 0,
                  color:    AppColors.warning,
                  tc:       tc,
                  onTap:    () => onChanged(0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DirectionOption(
                  label:    'She owes me',
                  icon:     Icons.arrow_downward_rounded,
                  selected: selected == 1,
                  color:    const Color(0xFF66BB6A),
                  tc:       tc,
                  onTap:    () => onChanged(1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DirectionOption extends StatelessWidget {
  const _DirectionOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.tc,
    required this.onTap,
  });

  final String     label;
  final IconData   icon;
  final bool       selected;
  final Color      color;
  final ThemeColors tc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : tc.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : tc.borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: selected ? color : tc.textMuted),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? color : tc.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.tc});

  final String label;
  final ThemeColors tc;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: tc.textMuted,
        letterSpacing: 0.5,
      ),
    );
  }
}
