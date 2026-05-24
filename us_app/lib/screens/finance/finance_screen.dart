import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/app_colors.dart';
import '../../models/expense_model.dart';
import '../../providers/couple_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/shimmer_card.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

String _rupees(double v) =>
    '₹${NumberFormat('#,##0').format(v.toInt())}';

Color _catColor(String cat) {
  switch (cat) {
    case ExpenseModel.catFood:         return const Color(0xFFEF5350);
    case ExpenseModel.catDate:         return AppColors.rose;
    case ExpenseModel.catTravel:       return const Color(0xFF42A5F5);
    case ExpenseModel.catGift:         return const Color(0xFFFF7043);
    case ExpenseModel.catSubscription: return const Color(0xFF66BB6A);
    default:                           return const Color(0xFF9E9E9E);
  }
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _categoryFilter; // null = All

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onBottomNavTapped(int index) {
    switch (index) {
      case 0: context.go('/home'); break;
      case 1: context.go('/memory'); break;
      case 2: context.go('/finance'); break;
      case 3: context.go('/planner'); break;
      case 4: context.go('/ai-chat'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseState = ref.watch(expenseProvider);
    final notifier     = ref.read(expenseProvider.notifier);
    final tc           = ref.watch(themeProvider).colors;

    return Scaffold(
      backgroundColor: tc.backgroundColor,
      bottomNavigationBar: BottomNav(currentIndex: 2, onTap: _onBottomNavTapped),
      appBar: AppBar(
        backgroundColor: tc.backgroundColor,
        elevation: 0,
        title: Text(
          'Finances 💸',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: tc.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Summary row ──────────────────────────────────────────────────
          _buildSummaryRow(notifier, tc),

          // ── Tab bar ──────────────────────────────────────────────────────
          Container(
            color: tc.backgroundColor,
            child: TabBar(
              controller: _tabController,
              labelColor: tc.iconColor,
              unselectedLabelColor: tc.textMuted,
              indicatorColor: tc.iconColor,
              labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
              tabs: const [Tab(text: 'Expenses'), Tab(text: 'Loans')],
            ),
          ),

          // ── Tab views ────────────────────────────────────────────────────
          Expanded(
            child: expenseState.when(
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: ShimmerList(count: 4, baseColor: tc.cardColor, highlightColor: tc.borderColor),
              ),
              error: (e, _) =>
                  Center(child: Text('Error: $e', style: GoogleFonts.dmSans(color: tc.textPrimary))),
              data: (expenses) => TabBarView(
                controller: _tabController,
                children: [
                  _ExpensesTab(
                    expenses:       expenses,
                    categoryFilter: _categoryFilter,
                    onFilterChanged: (f) => setState(() => _categoryFilter = f),
                    notifier:       notifier,
                    tc:             tc,
                  ),
                  _LoansTab(notifier: notifier, tc: tc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary Row ────────────────────────────────────────────────────────────

  Widget _buildSummaryRow(ExpenseNotifier notifier, ThemeColors tc) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          _SummaryCard(
            value: _rupees(notifier.totalThisMonth),
            label: 'this month',
            valueColor: tc.iconColor,
            tc: tc,
          ),
          const SizedBox(width: 12),
          _SummaryCard(
            value: _rupees(notifier.totalUnpaidLoans),
            label: 'in loans',
            valueColor: AppColors.warning,
            tc: tc,
          ),
          const SizedBox(width: 12),
          _AddCard(onTap: () => context.go('/finance/add'), tc: tc),
        ],
      ),
    );
  }
}

// ── Summary card ───────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.value,
    required this.label,
    required this.valueColor,
    required this.tc,
  });
  final String value;
  final String label;
  final Color valueColor;
  final ThemeColors tc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.dmSans(fontSize: 12, color: tc.textMuted),
          ),
        ],
      ),
    );
  }
}

class _AddCard extends StatelessWidget {
  const _AddCard({required this.onTap, required this.tc});
  final VoidCallback onTap;
  final ThemeColors tc;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: tc.iconColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: tc.iconColor.withValues(alpha: 0.30),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            const SizedBox(height: 2),
            Text(
              'Add',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Expenses Tab ───────────────────────────────────────────────────────────────

class _ExpensesTab extends ConsumerWidget {
  const _ExpensesTab({
    required this.expenses,
    required this.categoryFilter,
    required this.onFilterChanged,
    required this.notifier,
    required this.tc,
  });

  final List<ExpenseModel> expenses;
  final String? categoryFilter;
  final ValueChanged<String?> onFilterChanged;
  final ExpenseNotifier notifier;
  final ThemeColors tc;

  static const _filters = <({String? key, String label})>[
    (key: null,                        label: 'All'),
    (key: ExpenseModel.catFood,        label: 'Food'),
    (key: ExpenseModel.catDate,        label: 'Dates'),
    (key: ExpenseModel.catTravel,      label: 'Travel'),
    (key: ExpenseModel.catGift,        label: 'Gifts'),
    (key: ExpenseModel.catSubscription,label: 'Subs'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(coupleProvider).valueOrNull?.currentUser?.id ?? '';

    // Filter + exclude loans
    final filtered = expenses
        .where((e) =>
            !e.isLoan &&
            (categoryFilter == null || e.category == categoryFilter))
        .toList();

    // Group by date
    final groups = _groupByDate(filtered);

    // Category chart data (this month, all categories, no filter)
    final chartData = notifier.expensesByCategory;

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        // ── Category chart ────────────────────────────────────────────────
        if (chartData.isNotEmpty) _buildChart(chartData, tc),

        // ── Filter chips ──────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: _filters.map((f) {
              final key      = f.key;
              final isActive = categoryFilter == key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f.label),
                  selected: isActive,
                  selectedColor: tc.iconColor,
                  backgroundColor: tc.cardColor,
                  side: BorderSide(color: isActive ? tc.iconColor : tc.borderColor),
                  labelStyle: TextStyle(
                    color: isActive ? Colors.white : tc.textPrimary,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                  onSelected: (_) => onFilterChanged(isActive ? null : key),
                ),
              );
            }).toList(),
          ),
        ),

        // ── Empty state ───────────────────────────────────────────────────
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(48),
            child: Center(
              child: Text(
                'No expenses yet 💸',
                style: GoogleFonts.dmSans(fontSize: 15, color: tc.textMuted),
              ),
            ),
          ),

        // ── Grouped list ──────────────────────────────────────────────────
        ...groups.entries.expand((entry) => [
              _SectionHeader(title: entry.key, tc: tc),
              ...entry.value.map(
                (e) => _ExpenseCard(
                  expense: e,
                  myId: myId,
                  tc: tc,
                  onDelete: () => _confirmDelete(context, ref, e.id, tc),
                ),
              ),
            ]),
      ],
    );
  }

  Map<String, List<ExpenseModel>> _groupByDate(List<ExpenseModel> list) {
    final groups  = <String, List<ExpenseModel>>{};
    final today   = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    for (final e in list) {
      String key;
      if (e.spentAt.year == today.year &&
          e.spentAt.month == today.month &&
          e.spentAt.day == today.day) {
        key = 'Today';
      } else if (e.spentAt.year == yesterday.year &&
          e.spentAt.month == yesterday.month &&
          e.spentAt.day == yesterday.day) {
        key = 'Yesterday';
      } else {
        key = DateFormat.MMMd().format(e.spentAt);
      }
      groups.putIfAbsent(key, () => []).add(e);
    }
    return groups;
  }

  Widget _buildChart(Map<String, double> data, ThemeColors tc) {
    final total = data.values.fold(0.0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This Month',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tc.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: data.entries.map((e) {
                  return Flexible(
                    flex: (e.value / total * 100).round().clamp(1, 100),
                    child: Container(color: _catColor(e.key)),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: data.entries.map((e) {
              final model = ExpenseModel(
                id: '', coupleId: '', addedBy: '', amount: e.value,
                category: e.key, description: '', isLoan: false,
                isPaid: false, spentAt: DateTime.now(),
                createdAt: DateTime.now(),
              );
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _catColor(e.key),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${model.emoji} ${_rupees(e.value)}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: tc.textMuted,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id, ThemeColors tc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete expense?',
            style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.bold, color: tc.textPrimary)),
        content: Text('This cannot be undone.',
            style: GoogleFonts.dmSans(color: tc.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('Cancel', style: GoogleFonts.dmSans(color: tc.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text('Delete', style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(expenseProvider.notifier).deleteExpense(id);
    }
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.tc});
  final String title;
  final ThemeColors tc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: tc.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Expense card ───────────────────────────────────────────────────────────────

class _ExpenseCard extends ConsumerWidget {
  const _ExpenseCard({
    required this.expense,
    required this.myId,
    required this.tc,
    required this.onDelete,
  });
  final ExpenseModel expense;
  final String myId;
  final ThemeColors tc;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMe = expense.addedBy == myId;

    return Dismissible(
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // Deletion handled by dialog
      },
      background: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        decoration: BoxDecoration(
          color: AppColors.rose,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tc.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tc.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Category emoji circle
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _catColor(expense.category).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(expense.emoji,
                  style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),

            // Description + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.description.isNotEmpty
                        ? expense.description
                        : expense.label,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tc.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DateFormat.MMMd().format(expense.spentAt),
                    style: GoogleFonts.dmSans(
                        fontSize: 12, color: tc.textMuted),
                  ),
                ],
              ),
            ),

            // Amount + who added
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _rupees(expense.amount),
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: tc.iconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isMe
                        ? tc.iconColor.withValues(alpha: 0.15)
                        : AppColors.mauve.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    isMe ? 'You' : 'Her',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isMe ? tc.iconColor : AppColors.mauve,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loans Tab ──────────────────────────────────────────────────────────────────

class _LoansTab extends ConsumerWidget {
  const _LoansTab({required this.notifier, required this.tc});
  final ExpenseNotifier notifier;
  final ThemeColors tc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(expenseProvider); // rebuild on data change
    final myLoans    = notifier.myLoans;
    final theirLoans = notifier.theirLoans;
    final total      = notifier.totalUnpaidLoans;

    if (myLoans.isEmpty && theirLoans.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💕', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              "You're all square 💕",
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: tc.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No outstanding loans',
              style: GoogleFonts.dmSans(fontSize: 14, color: tc.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      children: [
        // Total outstanding
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Text('💳', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _rupees(total),
                    style: GoogleFonts.dmSans(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                  Text(
                    'total outstanding',
                    style: GoogleFonts.dmSans(
                        fontSize: 12, color: tc.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),

        // You Owe Her
        if (myLoans.isNotEmpty) ...[
          _loanSectionHeader('You Owe Her 💸', tc),
          ...myLoans.map((e) => _LoanCard(
                expense:  e,
                amountColor: AppColors.warning,
                tc: tc,
                onMarkPaid: () =>
                    ref.read(expenseProvider.notifier).markLoanPaid(e.id),
              )),
          const SizedBox(height: 16),
        ],

        // She Owes You
        if (theirLoans.isNotEmpty) ...[
          _loanSectionHeader('She Owes You 💰', tc),
          ...theirLoans.map((e) => _LoanCard(
                expense:  e,
                amountColor: AppColors.success,
                tc: tc,
                onMarkPaid: () =>
                    ref.read(expenseProvider.notifier).markLoanPaid(e.id),
              )),
        ],
      ],
    );
  }

  Widget _loanSectionHeader(String title, ThemeColors tc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: tc.textMuted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ── Loan card ──────────────────────────────────────────────────────────────────

class _LoanCard extends StatelessWidget {
  const _LoanCard({
    required this.expense,
    required this.amountColor,
    required this.tc,
    required this.onMarkPaid,
  });
  final ExpenseModel expense;
  final Color amountColor;
  final ThemeColors tc;
  final VoidCallback onMarkPaid;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description.isNotEmpty
                      ? expense.description
                      : expense.label,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tc.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _rupees(expense.amount),
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat.yMMMd().format(expense.spentAt),
                  style: GoogleFonts.dmSans(
                      fontSize: 11, color: tc.textMuted),
                ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: tc.iconColor,
              side: BorderSide(color: tc.iconColor),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onMarkPaid,
            child: Text('Mark Paid',
                style: GoogleFonts.dmSans(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
