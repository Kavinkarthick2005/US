import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../config/app_colors.dart';
import '../../models/wishlist_model.dart';
import '../../providers/couple_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/rose_button.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _rupees(double v) => '₹${NumberFormat('#,##0').format(v.toInt())}';

Future<void> _launchLink(String link) async {
  final url = link.startsWith('http') ? link : 'https://$link';
  final uri = Uri.tryParse(url);
  if (uri != null && await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ── Confetti ──────────────────────────────────────────────────────────────────

void _showConfetti(BuildContext context) {
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: _ConfettiOverlay(onDone: () => entry.remove()),
    ),
  );
  Overlay.of(context).insert(entry);
}

class _Particle {
  final double x0;
  final double dx;
  final double speed;
  final double radius;
  final Color  color;
  final double delay;

  _Particle()
      : x0     = _rng.nextDouble(),
        dx     = (_rng.nextDouble() - 0.5) * 0.22,
        speed  = 0.65 + _rng.nextDouble() * 0.7,
        radius = 3 + _rng.nextDouble() * 2,
        color  = _kColors[_rng.nextInt(_kColors.length)],
        delay  = _rng.nextDouble() * 0.28;

  static final _rng = Random();
  static const _kColors = [
    AppColors.rose,
    AppColors.mauve,
    AppColors.warning,
    Colors.white,
    Color(0xFFFFD700),
    Color(0xFF80DEEA),
  ];

  Offset position(Size s, double t) {
    final pt = ((t - delay) * speed).clamp(0.0, 1.0);
    return Offset(
      (x0 + dx * pt) * s.width,
      -radius * 2 + (s.height + radius * 4) * pt * pt,
    );
  }

  double opacity(double t) {
    final pt = ((t - delay) * speed).clamp(0.0, 1.0);
    return pt > 0.72 ? ((1 - (pt - 0.72) / 0.28)).clamp(0.0, 1.0) : 1.0;
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  _ConfettiPainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final pos = p.position(size, t);
      paint.color = p.color.withValues(alpha: p.opacity(t));
      canvas.drawCircle(pos, p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

class _ConfettiOverlay extends StatefulWidget {
  const _ConfettiOverlay({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _particles = List.generate(20, (_) => _Particle());

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _ConfettiPainter(_particles, _ctrl.value),
        size: Size.infinite,
      ),
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddWishlistSheet(
        initialType: _tab.index == 0
            ? WishlistModel.typeBuy
            : WishlistModel.typeExperience,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wishlistAsync = ref.watch(wishlistProvider);
    final tc            = ref.watch(themeProvider).colors;

    return Scaffold(
      backgroundColor: tc.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: tc.textPrimary,
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Our Wishlist ✨',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: tc.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: tc.iconColor,
            onPressed: _openAddSheet,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tab,
            labelColor: tc.iconColor,
            unselectedLabelColor: tc.textMuted,
            indicatorColor: tc.iconColor,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: GoogleFonts.dmSans(
                fontSize: 14, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 14),
            tabs: const [
              Tab(text: '🛍️  Buy'),
              Tab(text: '🌟  Experiences'),
            ],
          ),
        ),
      ),
      body: wishlistAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
             Center(child: Text('Failed to load wishlist', style: TextStyle(color: tc.textPrimary))),
        data: (_) {
          final notifier    = ref.read(wishlistProvider.notifier);
          final coupleState = ref.watch(coupleProvider).valueOrNull;
          final budget      = notifier.totalBuyBudget;
          final buyItems    = notifier.buyItems;
          final expItems    = notifier.experienceItems;
          final doneAll     = notifier.doneItems;
          final doneBuy     = doneAll
              .where((i) => i.type == WishlistModel.typeBuy)
              .toList();
          final doneExp     = doneAll
              .where((i) => i.type == WishlistModel.typeExperience)
              .toList();

          return Column(
            children: [
              if (budget > 0) _BudgetBanner(total: budget, tc: tc),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _BuyTab(
                      items:        buyItems,
                      doneItems:    doneBuy,
                      coupleState:  coupleState,
                      tc:           tc,
                    ),
                    _ExperienceTab(
                      items:        expItems,
                      doneItems:    doneExp,
                      coupleState:  coupleState,
                      tc:           tc,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSheet,
        backgroundColor: tc.iconColor,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ── Budget banner ─────────────────────────────────────────────────────────────

class _BudgetBanner extends StatelessWidget {
  const _BudgetBanner({required this.total, required this.tc});
  final double total;
  final ThemeColors tc;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Text('💰', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            '${_rupees(total)} total to buy',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.tc});
  final String message;
  final ThemeColors tc;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌸', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                color: tc.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Buy tab ───────────────────────────────────────────────────────────────────

class _BuyTab extends StatelessWidget {
  const _BuyTab({
    required this.items,
    required this.doneItems,
    required this.coupleState,
    required this.tc,
  });

  final List<WishlistModel> items;
  final List<WishlistModel> doneItems;
  final CoupleState?        coupleState;
  final ThemeColors         tc;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && doneItems.isEmpty) {
      return _EmptyState(
        message: 'Add something you both want 🛍️',
        tc: tc,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        ...items.map((item) => _WishlistItemCard(
              item:        item,
              coupleState: coupleState,
              tc:          tc,
              actionLabel: 'Buy it 🎉',
              blush:       false,
            )),
        if (items.isNotEmpty && doneItems.isNotEmpty)
          const SizedBox(height: 8),
        if (doneItems.isNotEmpty)
          _DoneSection(
            items:       doneItems,
            coupleState: coupleState,
            tc:          tc,
          ),
      ],
    );
  }
}

// ── Experience tab ────────────────────────────────────────────────────────────

class _ExperienceTab extends StatelessWidget {
  const _ExperienceTab({
    required this.items,
    required this.doneItems,
    required this.coupleState,
    required this.tc,
  });

  final List<WishlistModel> items;
  final List<WishlistModel> doneItems;
  final CoupleState?        coupleState;
  final ThemeColors         tc;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && doneItems.isEmpty) {
      return _EmptyState(
        message: 'Add an adventure you want together 🌟',
        tc: tc,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        ...items.map((item) => _WishlistItemCard(
              item:        item,
              coupleState: coupleState,
              tc:          tc,
              actionLabel: 'Done it! 🎉',
              blush:       true,
            )),
        if (items.isNotEmpty && doneItems.isNotEmpty)
          const SizedBox(height: 8),
        if (doneItems.isNotEmpty)
          _DoneSection(
            items:       doneItems,
            coupleState: coupleState,
            tc:          tc,
          ),
      ],
    );
  }
}

// ── Item card ─────────────────────────────────────────────────────────────────

class _WishlistItemCard extends ConsumerWidget {
  const _WishlistItemCard({
    required this.item,
    required this.coupleState,
    required this.tc,
    required this.actionLabel,
    required this.blush,
  });

  final WishlistModel item;
  final CoupleState?  coupleState;
  final ThemeColors   tc;
  final String        actionLabel;
  final bool          blush;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId      = coupleState?.currentUser?.id;
    final addedByMe = item.addedBy == myId;
    final adder     = addedByMe ? coupleState?.currentUser : coupleState?.partner;
    final adderName = adder?.name.split(' ').first ?? 'Someone';
    final avatarUrl = adder?.avatarUrl;

    final bgColor = blush
        ? tc.iconColor.withValues(alpha: 0.1)
        : tc.cardColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: tc.textPrimary,
                  ),
                ),
              ),
              if (item.price != null) ...[
                const SizedBox(width: 8),
                Text(
                  _rupees(item.price!),
                  style: GoogleFonts.dmMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tc.iconColor,
                  ),
                ),
              ],
            ],
          ),

          if (item.notes != null && item.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.notes!,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: tc.textMuted,
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Who added + link chip + action button
          Row(
            children: [
              _MiniAvatar(url: avatarUrl, tc: tc),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$adderName added',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: tc.textMuted,
                  ),
                ),
              ),

              if (item.link != null && item.link!.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => _launchLink(item.link!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: tc.iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: tc.iconColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'View Item',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: tc.iconColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],

              IconButton(
                icon: Icon(Icons.delete_outline_rounded, size: 20, color: tc.textMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: tc.cardColor,
                      title: Text('Delete Item?', style: GoogleFonts.dmSans(color: tc.textPrimary, fontWeight: FontWeight.bold)),
                      content: Text('Remove this item from your wishlist?', style: GoogleFonts.dmSans(color: tc.textSecondary)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Cancel', style: GoogleFonts.dmSans(color: tc.textMuted)),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(wishlistProvider.notifier).deleteItem(item.id);
                            Navigator.pop(ctx);
                          },
                          child: Text('Delete', style: GoogleFonts.dmSans(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),

              OutlinedButton(
                onPressed: () async {
                  await ref
                      .read(wishlistProvider.notifier)
                      .markDone(item.id);
                  if (context.mounted) _showConfetti(context);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: tc.iconColor,
                  side: BorderSide(color: tc.iconColor),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  actionLabel,
                  style: GoogleFonts.dmSans(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Mini avatar ───────────────────────────────────────────────────────────────

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({this.url, required this.tc});
  final String? url;
  final ThemeColors tc;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          width: 20,
          height: 20,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _fallback,
        ),
      );
    }
    return _fallback;
  }

  Widget get _fallback => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: tc.iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text('💕', style: TextStyle(fontSize: 10)),
        ),
      );
}

// ── Done section ──────────────────────────────────────────────────────────────

class _DoneSection extends StatelessWidget {
  const _DoneSection({
    required this.items,
    required this.coupleState,
    required this.tc,
  });

  final List<WishlistModel> items;
  final CoupleState?        coupleState;
  final ThemeColors         tc;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        title: Text(
          'Done ✓  (${items.length})',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: tc.textMuted,
          ),
        ),
        iconColor: tc.textMuted,
        collapsedIconColor: tc.textMuted,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        children: items
            .map((item) => _DoneItemTile(
                  item: item,
                  coupleState: coupleState,
                  tc: tc,
                ))
            .toList(),
      ),
    );
  }
}

class _DoneItemTile extends ConsumerWidget {
  const _DoneItemTile({
    required this.item,
    required this.coupleState,
    required this.tc,
  });

  final WishlistModel item;
  final CoupleState?  coupleState;
  final ThemeColors   tc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId      = coupleState?.currentUser?.id;
    final addedByMe = item.addedBy == myId;
    final adder     = addedByMe
        ? coupleState?.currentUser
        : coupleState?.partner;
    final adderName = adder?.name.split(' ').first ?? 'Someone';

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(
        item.title,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          color: tc.textMuted,
          decoration: TextDecoration.lineThrough,
          decorationColor: tc.textMuted,
        ),
      ),
      subtitle: Text(
        '$adderName • ${item.price != null ? _rupees(item.price!) : item.type}',
        style: GoogleFonts.dmSans(
          fontSize: 12,
          color: tc.textMuted.withValues(alpha: 0.7),
        ),
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline_rounded,
            size: 18, color: tc.textMuted),
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: tc.cardColor,
              title: Text('Delete Item?', style: GoogleFonts.dmSans(color: tc.textPrimary, fontWeight: FontWeight.bold)),
              content: Text('Remove this item from your wishlist?', style: GoogleFonts.dmSans(color: tc.textSecondary)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.dmSans(color: tc.textMuted)),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(wishlistProvider.notifier).deleteItem(item.id);
                    Navigator.pop(ctx);
                  },
                  child: Text('Delete', style: GoogleFonts.dmSans(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Add bottom sheet ──────────────────────────────────────────────────────────

class _AddWishlistSheet extends ConsumerStatefulWidget {
  const _AddWishlistSheet({required this.initialType});
  final String initialType;

  @override
  ConsumerState<_AddWishlistSheet> createState() => _AddWishlistSheetState();
}

class _AddWishlistSheetState extends ConsumerState<_AddWishlistSheet> {
  late String _type;
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _linkCtrl  = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isSaving   = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _linkCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _snack('Enter a title');
      return;
    }

    final coupleState = ref.read(coupleProvider).valueOrNull;
    final myId        = coupleState?.currentUser?.id;
    if (myId == null) {
      _snack('Not authenticated');
      return;
    }
    final coupleId    = coupleState?.coupleId ?? myId;

    setState(() => _isSaving = true);
    try {
      final item = WishlistModel(
        id:        const Uuid().v4(),
        coupleId:  coupleId,
        addedBy:   myId,
        title:     title,
        type:      _type,
        price:     _type == WishlistModel.typeBuy
            ? double.tryParse(_priceCtrl.text.trim())
            : null,
        link:      _type == WishlistModel.typeBuy
            ? _linkCtrl.text.trim()
            : null,
        notes:     _notesCtrl.text.trim(),
        isDone:    false,
        createdAt: DateTime.now(),
      );
      await ref.read(wishlistProvider.notifier).addItem(item);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added to wishlist ✨',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w500),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
      _snack('Failed to add. Try again.');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.dmSans()),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc   = ref.watch(themeProvider).colors;
    final isBuy = _type == WishlistModel.typeBuy;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: tc.cardColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tc.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // sheet title
              Text(
                'Add to Wishlist',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: tc.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // type toggle
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: WishlistModel.typeBuy,
                      label: Text('🛍️  Buy Something')),
                  ButtonSegment(
                      value: WishlistModel.typeExperience,
                      label: Text('🌟  Experience')),
                ],
                selected: {_type},
                onSelectionChanged: (s) =>
                    setState(() => _type = s.first),
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return tc.iconColor.withValues(alpha: 0.15);
                    }
                    return Colors.transparent;
                  }),
                  foregroundColor:
                      WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return tc.iconColor;
                    }
                    return tc.textMuted;
                  }),
                  side: WidgetStateProperty.all(
                      BorderSide(
                          color: tc.iconColor
                              .withValues(alpha: 0.3))),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              _SheetField(
                controller: _titleCtrl,
                hint:       'Title (required)',
                tc:         tc,
                autofocus:  true,
              ),
              const SizedBox(height: 12),

              // Price + Link — only for Buy
              AnimatedCrossFade(
                firstChild:  const SizedBox(width: double.infinity),
                secondChild: Column(
                  children: [
                    _SheetField(
                      controller: _priceCtrl,
                      hint:       '₹ Price (optional)',
                      tc:         tc,
                      keyboard:   const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SheetField(
                      controller: _linkCtrl,
                      hint:       'Link (optional)',
                      tc:         tc,
                      keyboard:   TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
                crossFadeState: isBuy
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
              ),

              // Notes
              _SheetField(
                controller: _notesCtrl,
                hint:       'Notes (optional)',
                tc:         tc,
                maxLines:   2,
              ),
              const SizedBox(height: 20),

              RoseButton(
                label:     'Add to Wishlist',
                isLoading: _isSaving,
                onTap:     _isSaving ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.hint,
    required this.tc,
    this.keyboard,
    this.inputFormatters,
    this.maxLines = 1,
    this.autofocus = false,
  });

  final TextEditingController   controller;
  final String                  hint;
  final ThemeColors             tc;
  final TextInputType?          keyboard;
  final List<TextInputFormatter>? inputFormatters;
  final int                     maxLines;
  final bool                    autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: tc.inputFillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: tc.borderColor),
      ),
      child: TextField(
        controller:       controller,
        keyboardType:     keyboard,
        inputFormatters:  inputFormatters,
        maxLines:         maxLines,
        autofocus:        autofocus,
        textCapitalization: TextCapitalization.sentences,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          color: tc.textPrimary,
        ),
        decoration: InputDecoration(
          hintText:  hint,
          hintStyle: GoogleFonts.dmSans(
              color: tc.textMuted, fontSize: 14),
          border:        InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          isDense: true,
        ),
      ),
    );
  }
}
