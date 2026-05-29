import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/v2/space_header.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class SurprisePlan {
  SurprisePlan({
    required this.id,
    required this.title,
    required this.notes,
    required this.isComplete,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String notes;
  bool isComplete;
  final DateTime createdAt;

  factory SurprisePlan.fromJson(Map<String, dynamic> json) {
    return SurprisePlan(
      id: json['id'] as String,
      title: json['title'] as String,
      notes: json['notes'] as String,
      isComplete: json['isComplete'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'isComplete': isComplete,
        'createdAt': createdAt.toIso8601String(),
      };
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SurprisePlannerScreen extends ConsumerStatefulWidget {
  const SurprisePlannerScreen({super.key});

  @override
  ConsumerState<SurprisePlannerScreen> createState() =>
      _SurprisePlannerScreenState();
}

class _SurprisePlannerScreenState
    extends ConsumerState<SurprisePlannerScreen> {
  static const List<Color> _heGradient = [
    Color(0xFFE8607A),
    Color(0xFF9B2647),
  ];

  static const String _prefsKey = 'surprise_plans';
  static final _uuid = Uuid();

  List<SurprisePlan> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final List<dynamic> jsonList = jsonDecode(raw);
        if (mounted) {
          setState(() {
            _plans = jsonList
                .map((e) => SurprisePlan.fromJson(e as Map<String, dynamic>))
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _savePlans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_plans.map((p) => p.toJson()).toList()),
      );
    } catch (_) {}
  }

  void _addPlan(String title, String notes) {
    final plan = SurprisePlan(
      id: _uuid.v4(),
      title: title,
      notes: notes,
      isComplete: false,
      createdAt: DateTime.now(),
    );
    setState(() {
      _plans.insert(0, plan);
    });
    _savePlans();
  }

  void _toggleComplete(String id) {
    setState(() {
      final plan = _plans.firstWhere((p) => p.id == id);
      plan.isComplete = !plan.isComplete;
    });
    _savePlans();
  }

  void _deletePlan(String id) {
    setState(() {
      _plans.removeWhere((p) => p.id == id);
    });
    _savePlans();
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _AddPlanDialog(
        heGradient: _heGradient,
        onAdd: (title, notes) {
          _addPlan(title, notes);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  int get _activePlanCount => _plans.where((p) => !p.isComplete).length;

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final colors = themeState.colors;

    return Scaffold(
      backgroundColor: colors.backgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFFE8607A),
        foregroundColor: Colors.white,
        elevation: 6,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SpaceSubHeader(
              title: 'Surprise Planner',
              gradientColors: _heGradient,
              onBack: () => Navigator.of(context).pop(),
              action: _PlanCountBadge(count: _activePlanCount),
            ).animate().fadeIn(duration: 350.ms),

            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE8607A),
                      ),
                    )
                  : _plans.isEmpty
                      ? _EmptyState(
                          onAdd: _showAddDialog,
                          colors: colors,
                        )
                      : ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _plans.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final plan = _plans[index];
                            return _PlanCard(
                              key: ValueKey(plan.id),
                              plan: plan,
                              colors: colors,
                              delay:
                                  Duration(milliseconds: 70 * index),
                              onToggle: () => _toggleComplete(plan.id),
                              onDismiss: () => _deletePlan(plan.id),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _PlanCountBadge extends StatelessWidget {
  const _PlanCountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Text(
        '$count plans for her',
        style: GoogleFonts.dmMono(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          fontStyle: FontStyle.normal,
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    super.key,
    required this.plan,
    required this.colors,
    required this.delay,
    required this.onToggle,
    required this.onDismiss,
  });

  final SurprisePlan plan;
  final ThemeColors colors;
  final Duration delay;
  final VoidCallback onToggle;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMM yyyy').format(plan.createdAt);

    return Dismissible(
      key: ValueKey(plan.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 26),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: plan.isComplete
              ? colors.cardColor.withOpacity(0.6)
              : colors.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: plan.isComplete
                ? const Color(0xFFE8607A).withOpacity(0.1)
                : const Color(0xFFE8607A).withOpacity(0.2),
            width: 1.2,
          ),
          boxShadow: plan.isComplete
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFFE8607A).withOpacity(0.07),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  gradient: plan.isComplete
                      ? const LinearGradient(
                          colors: [Color(0xFFE8607A), Color(0xFF9B2647)],
                        )
                      : null,
                  border: Border.all(
                    color: plan.isComplete
                        ? Colors.transparent
                        : const Color(0xFFE8607A).withOpacity(0.4),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: plan.isComplete
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: plan.isComplete
                          ? colors.textPrimary.withOpacity(0.45)
                          : colors.textPrimary,
                      decoration: plan.isComplete
                          ? TextDecoration.lineThrough
                          : null,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                  if (plan.notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      plan.notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: plan.isComplete
                            ? colors.textPrimary.withOpacity(0.3)
                            : colors.textPrimary.withOpacity(0.6),
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('🎁', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: GoogleFonts.dmMono(
                          fontSize: 11,
                          color: colors.textPrimary.withOpacity(0.38),
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                      if (plan.isComplete) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFE8607A).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Done ✓',
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE8607A),
                              fontStyle: FontStyle.normal,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: delay).slideY(begin: 0.1, end: 0);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd, required this.colors});

  final VoidCallback onAdd;
  final ThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎁', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 16),
          Text(
            'Plan a surprise for her',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
              fontStyle: FontStyle.normal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your plans are private and stored here.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: colors.textPrimary.withOpacity(0.5),
              fontStyle: FontStyle.normal,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(
              'New Plan',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.normal,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE8607A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 450.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }
}

// ---------------------------------------------------------------------------
// Add Plan Dialog
// ---------------------------------------------------------------------------

class _AddPlanDialog extends StatefulWidget {
  const _AddPlanDialog({
    required this.heGradient,
    required this.onAdd,
  });

  final List<Color> heGradient;
  final void Function(String title, String notes) onAdd;

  @override
  State<_AddPlanDialog> createState() => _AddPlanDialogState();
}

class _AddPlanDialogState extends State<_AddPlanDialog> {
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: widget.heGradient,
              ).createShader(bounds),
              child: Text(
                'New Surprise Plan 🎁',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              style: GoogleFonts.dmSans(fontStyle: FontStyle.normal),
              decoration: InputDecoration(
                hintText: 'Plan title (e.g. Candlelight dinner)',
                hintStyle: GoogleFonts.dmSans(
                  color: Colors.grey.shade400,
                  fontStyle: FontStyle.normal,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              style: GoogleFonts.dmSans(fontStyle: FontStyle.normal),
              decoration: InputDecoration(
                hintText: 'Notes (optional)',
                hintStyle: GoogleFonts.dmSans(
                  color: Colors.grey.shade400,
                  fontStyle: FontStyle.normal,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.dmSans(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final title = _titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      widget.onAdd(title, _notesCtrl.text.trim());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8607A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Add Plan',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.normal,
                      ),
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
