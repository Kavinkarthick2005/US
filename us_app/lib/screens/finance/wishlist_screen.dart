import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../config/app_colors.dart';
import '../../models/wishlist_model.dart';
import '../../providers/couple_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/rose_button.dart';

String _rupees(double v) => '₹${NumberFormat('#,##0').format(v.toInt())}';

Future<void> _launchLink(String link) async {
  final url = link.startsWith('http') ? link : 'https://$link';
  final uri = Uri.tryParse(url);
  if (uri != null && await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Color _getTagColor(String? tag) {
  switch (tag?.toLowerCase()) {
    case 'surprise': return const Color(0xFFE8607A); // rose
    case 'dream': return const Color(0xFFC97B93); // mauve
    case 'practical': return const Color(0xFF9E9E9E); // grey
    case 'romantic': return const Color(0xFFFFC0CB); // pink
    case 'adventure': return const Color(0xFFFFC107); // amber
    case 'comfort': return const Color(0xFF81C784); // sage green
    default: return AppColors.blush;
  }
}

// ── Confetti ──────────────────────────────────────────────────────────────────

class _ConfettiOverlay extends StatefulWidget {
  const _ConfettiOverlay();
  @override
  State<_ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<_ConfettiOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_ConfettiParticle> _particles = [];
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    final colors = [const Color(0xFFE8607A), const Color(0xFFC97B93), const Color(0xFFD4AF37), Colors.white];
    for (int i = 0; i < 20; i++) {
      _particles.add(_ConfettiParticle(
        x: _random.nextDouble(),
        y: -0.2 - _random.nextDouble() * 0.2,
        size: 6.0 + _random.nextDouble() * 6.0,
        color: colors[_random.nextInt(colors.length)],
        speed: 0.5 + _random.nextDouble(),
        wobbleSpeed: 2 + _random.nextDouble() * 4,
        wobbleAmount: 0.05 + _random.nextDouble() * 0.05,
      ));
    }
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return CustomPaint(
            painter: _ConfettiPainter(_particles, CurvedAnimation(parent: _ctrl, curve: Curves.easeIn).value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _ConfettiParticle {
  final double x, y, size, speed, wobbleSpeed, wobbleAmount;
  final Color color;
  _ConfettiParticle({required this.x, required this.y, required this.size, required this.color, required this.speed, required this.wobbleSpeed, required this.wobbleAmount});
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;
  _ConfettiPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      final currentY = p.y * size.height + progress * size.height * p.speed * 2;
      final currentX = p.x * size.width + math.sin(progress * math.pi * p.wobbleSpeed) * size.width * p.wobbleAmount;
      paint.color = p.color;
      canvas.drawCircle(Offset(currentX, currentY), p.size, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

void _showConfetti(BuildContext context) {
  final overlay = Overlay.of(context);
  final entry = OverlayEntry(builder: (ctx) => const _ConfettiOverlay());
  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 1800), () => entry.remove());
}

// ── Screen ────────────────────────────────────────────────────────────────────

class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});
  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _showHidden = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _openAddSheet({WishlistModel? itemToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddWishlistSheet(
        initialVisibility: itemToEdit?.visibility ?? (_tab.index == 0 ? 'mine' : (_tab.index == 1 ? 'theirs' : 'shared')),
        itemToEdit: itemToEdit,
      ),
    );
  }

  Future<void> _promptPin(ThemeColors tc) async {
    if (_showHidden) {
      setState(() => _showHidden = false);
      return;
    }
    
    final notifier = ref.read(wishlistProvider.notifier);
    final isSet = await notifier.isPINSet;
    
    if (!mounted) return;
    
    if (!isSet) {
      _showSetPinDialog(tc);
      return;
    }
    
    _showEnterPinDialog(tc);
  }

  void _showSetPinDialog(ThemeColors tc) {
    String enteredPin = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.cardColor,
        title: Text('Set PIN for Hidden Items', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold, color: tc.textPrimary, fontStyle: FontStyle.normal)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Create a 4-digit PIN to lock surprise gifts.', style: GoogleFonts.dmSans(color: tc.textMuted)),
            const SizedBox(height: 16),
            PinCodeTextField(
              appContext: ctx,
              length: 4,
              obscureText: true,
              keyboardType: TextInputType.number,
              textStyle: GoogleFonts.dmMono(color: tc.textPrimary, fontStyle: FontStyle.normal),
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(8),
                fieldHeight: 50,
                fieldWidth: 40,
                activeFillColor: tc.backgroundColor,
                inactiveFillColor: tc.backgroundColor,
                selectedFillColor: AppColors.blush,
                activeColor: AppColors.rose,
                inactiveColor: tc.borderColor,
                selectedColor: AppColors.rose,
              ),
              onChanged: (val) => enteredPin = val,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.dmSans(color: tc.textMuted))),
          RoseButton(
            label: 'Save PIN',
            onTap: () async {
              if (enteredPin.length == 4) {
                await ref.read(wishlistProvider.notifier).savePIN(enteredPin);
                if (mounted) {
                  Navigator.pop(ctx);
                  _showEnterPinDialog(tc); // immediately ask to enter it to unlock
                }
              }
            },
          )
        ],
      ),
    );
  }

  void _showEnterPinDialog(ThemeColors tc) {
    String enteredPin = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.cardColor,
        title: Text('Enter PIN', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold, color: tc.textPrimary, fontStyle: FontStyle.normal)),
        content: PinCodeTextField(
          appContext: ctx,
          length: 4,
          obscureText: true,
          keyboardType: TextInputType.number,
          textStyle: GoogleFonts.dmMono(color: tc.textPrimary, fontStyle: FontStyle.normal),
          pinTheme: PinTheme(
            shape: PinCodeFieldShape.box,
            borderRadius: BorderRadius.circular(8),
            fieldHeight: 50,
            fieldWidth: 40,
            activeFillColor: tc.backgroundColor,
            inactiveFillColor: tc.backgroundColor,
            selectedFillColor: AppColors.blush,
            activeColor: AppColors.rose,
            inactiveColor: tc.borderColor,
            selectedColor: AppColors.rose,
          ),
          onChanged: (val) => enteredPin = val,
          onCompleted: (val) async {
            final valid = await ref.read(wishlistProvider.notifier).verifyPIN(val);
            if (valid) {
              if (mounted) {
                setState(() => _showHidden = true);
                Navigator.pop(ctx);
              }
            } else {
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect PIN 💕')));
              }
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wishlistAsync = ref.watch(wishlistProvider);
    final tc = ref.watch(themeProvider).colors;

    return Scaffold(
      backgroundColor: tc.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: tc.textPrimary,
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: wishlistAsync.maybeWhen(
          data: (_) {
            final budget = ref.read(wishlistProvider.notifier).totalBuyBudget;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Our Wishlist ✨', style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w700, color: tc.textPrimary, fontStyle: FontStyle.normal)),
                if (budget > 0)
                  Text('${_rupees(budget)} saved up for', style: GoogleFonts.dmSans(fontSize: 12, color: tc.textMuted)),
              ],
            );
          },
          orElse: () => Text('Our Wishlist ✨', style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w700, color: tc.textPrimary, fontStyle: FontStyle.normal)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: tc.iconColor,
            onPressed: () => _openAddSheet(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tab,
            labelColor: tc.iconColor,
            unselectedLabelColor: tc.textMuted,
            indicatorColor: tc.iconColor,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 14),
            tabs: const [
              Tab(text: '🛍️ MINE'),
              Tab(text: '💝 THEIRS'),
              Tab(text: '🌟 OURS'),
            ],
          ),
        ),
      ),
      body: wishlistAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Failed to load wishlist', style: TextStyle(color: tc.textPrimary))),
        data: (_) {
          final notifier = ref.read(wishlistProvider.notifier);
          final coupleState = ref.watch(coupleProvider).valueOrNull;

          final myItems = notifier.myItems;
          final theirItems = notifier.theirItems;
          final oursItems = notifier.oursItems;
          
          final hiddenMy = _showHidden ? notifier.hiddenItems.where((i) => i.visibility == 'mine').toList() : <WishlistModel>[];
          final hiddenTheirs = _showHidden ? notifier.hiddenItems.where((i) => i.visibility == 'theirs').toList() : <WishlistModel>[];

          return Column(
            children: [
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _TabContent(
                      items: myItems,
                      hiddenItems: hiddenMy,
                      tc: tc,
                      emptyMessage: 'Add things you want 🛍️',
                      onAdd: () => _openAddSheet(),
                      coupleState: coupleState,
                    ),
                    _TabContent(
                      items: theirItems,
                      hiddenItems: hiddenTheirs,
                      tc: tc,
                      emptyMessage: 'Start planning something special 🎁',
                      onAdd: () => _openAddSheet(),
                      coupleState: coupleState,
                    ),
                    _TabContent(
                      items: oursItems,
                      hiddenItems: const [],
                      tc: tc,
                      emptyMessage: 'Add adventures you want together 🌟',
                      onAdd: () => _openAddSheet(),
                      coupleState: coupleState,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextButton.icon(
                  onPressed: () => _promptPin(tc),
                  icon: Icon(_showHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: tc.textMuted),
                  label: Text(_showHidden ? 'Hide Secrets' : 'Show Hidden Items 🔒', style: GoogleFonts.dmSans(color: tc.textMuted)),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddSheet(),
        backgroundColor: tc.iconColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ── Tab Content ───────────────────────────────────────────────────────────────

class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.items,
    required this.hiddenItems,
    required this.tc,
    required this.emptyMessage,
    required this.onAdd,
    required this.coupleState,
  });

  final List<WishlistModel> items;
  final List<WishlistModel> hiddenItems;
  final ThemeColors tc;
  final String emptyMessage;
  final VoidCallback onAdd;
  final CoupleState? coupleState;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && hiddenItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emptyMessage, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: tc.textPrimary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blush,
                foregroundColor: AppColors.rose,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Add Item', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        ...hiddenItems.map((i) => _WishlistItemCard(item: i, tc: tc, coupleState: coupleState)),
        ...items.map((i) => _WishlistItemCard(item: i, tc: tc, coupleState: coupleState)),
      ],
    );
  }
}

// ── Item Card ─────────────────────────────────────────────────────────────────

class _WishlistItemCard extends ConsumerStatefulWidget {
  const _WishlistItemCard({required this.item, required this.tc, required this.coupleState});
  final WishlistModel item;
  final ThemeColors tc;
  final CoupleState? coupleState;
  @override
  ConsumerState<_WishlistItemCard> createState() => _WishlistItemCardState();
}

class _WishlistItemCardState extends ConsumerState<_WishlistItemCard> {
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.tc.cardColor,
        title: Text('Delete Item?', style: GoogleFonts.dmSans(color: widget.tc.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.dmSans(color: widget.tc.textMuted))),
          TextButton(
            onPressed: () {
              ref.read(wishlistProvider.notifier).deleteItem(widget.item.id);
              Navigator.pop(ctx);
            },
            child: Text('Delete', style: GoogleFonts.dmSans(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final tc = widget.tc;
    
    final myId = widget.coupleState?.currentUser?.id;
    final addedByMe = item.addedBy == myId;

    Widget card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: CachedNetworkImage(
                imageUrl: item.imageUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold, color: tc.textPrimary, fontStyle: FontStyle.normal),
                      ),
                    ),
                    if (item.priority >= 1) const Text('⭐', style: TextStyle(fontSize: 16)),
                    if (item.isHidden) ...[const SizedBox(width: 4), Icon(Icons.lock_rounded, size: 16, color: tc.iconColor)],
                  ],
                ),
                if (item.emotionalTag != null && item.emotionalTag!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getTagColor(item.emotionalTag),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.emotionalTag!,
                      style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, fontStyle: FontStyle.normal),
                    ),
                  ),
                ],
                if (item.price != null && item.price! > 0) ...[
                  const SizedBox(height: 8),
                  Text(_rupees(item.price!), style: GoogleFonts.dmMono(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.rose, fontStyle: FontStyle.normal)),
                ],
                if (item.description != null && item.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.visibility == 'theirs' ? "She'd love this because...\n${item.description}" : item.description!,
                    style: GoogleFonts.dmSans(fontSize: 13, color: tc.textMuted, fontStyle: FontStyle.normal),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (item.link != null && item.link!.isNotEmpty)
                      GestureDetector(
                        onTap: () => _launchLink(item.link!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: tc.iconColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('View Link 🔗', style: GoogleFonts.dmSans(fontSize: 12, color: tc.iconColor, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    const Spacer(),
                    if (!item.isDone)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blush,
                          foregroundColor: AppColors.rose,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(item.visibility == 'theirs' ? 'Mark as gifted 🎁' : (item.visibility == 'shared' ? 'Done it! 🎉' : 'Done ✓'), style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          ref.read(wishlistProvider.notifier).markDone(item.id);
                          _showConfetti(context);
                        },
                      ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz_rounded, color: tc.textMuted, size: 20),
                      color: tc.cardColor,
                      onSelected: (val) {
                        if (val == 'hide') ref.read(wishlistProvider.notifier).hideItem(item.id);
                        if (val == 'unhide') ref.read(wishlistProvider.notifier).unhideItem(item.id);
                        if (val == 'delete') _confirmDelete();
                      },
                      itemBuilder: (ctx) => [
                        if (addedByMe && !item.isHidden) PopupMenuItem(value: 'hide', child: Text('Hide', style: GoogleFonts.dmSans(color: tc.textPrimary))),
                        if (addedByMe && item.isHidden) PopupMenuItem(value: 'unhide', child: Text('Unhide', style: GoogleFonts.dmSans(color: tc.textPrimary))),
                        if (addedByMe || item.visibility == 'shared') PopupMenuItem(value: 'delete', child: Text('Delete', style: GoogleFonts.dmSans(color: Colors.redAccent))),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (item.isDone) {
      return Stack(
        children: [
          Opacity(opacity: 0.5, child: card),
          Positioned.fill(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle, color: Colors.green, size: 48),
              ),
            ),
          ),
        ],
      );
    }

    return card;
  }
}

// ── Add Sheet ─────────────────────────────────────────────────────────────────

class _AddWishlistSheet extends ConsumerStatefulWidget {
  const _AddWishlistSheet({required this.initialVisibility, this.itemToEdit});
  final String initialVisibility;
  final WishlistModel? itemToEdit;
  @override
  ConsumerState<_AddWishlistSheet> createState() => _AddWishlistSheetState();
}

class _AddWishlistSheetState extends ConsumerState<_AddWishlistSheet> {
  late String _visibility;
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _emotionalTag;
  bool _isPriority = false;

  final _tags = ['surprise', 'dream', 'practical', 'romantic', 'adventure', 'comfort'];

  @override
  void initState() {
    super.initState();
    _visibility = widget.itemToEdit?.visibility ?? widget.initialVisibility;
    if (widget.itemToEdit != null) {
      _titleCtrl.text = widget.itemToEdit!.title;
      _priceCtrl.text = widget.itemToEdit!.price?.toString() ?? '';
      _linkCtrl.text = widget.itemToEdit!.link ?? '';
      _notesCtrl.text = widget.itemToEdit!.description ?? '';
      _emotionalTag = widget.itemToEdit!.emotionalTag;
      _isPriority = widget.itemToEdit!.priority >= 1;
    }
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty) return;
    
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return;
    final coupleState = ref.read(coupleProvider).valueOrNull;

    final newItem = WishlistModel(
      id: widget.itemToEdit?.id ?? Uuid().v4(),
      coupleId: coupleState?.coupleId ?? myId,
      addedBy: widget.itemToEdit?.addedBy ?? myId,
      title: _titleCtrl.text.trim(),
      description: _notesCtrl.text.trim(),
      price: double.tryParse(_priceCtrl.text.trim()),
      link: _linkCtrl.text.trim(),
      type: WishlistModel.typeBuy,
      visibility: _visibility,
      emotionalTag: _emotionalTag,
      priority: _isPriority ? 1 : 0,
      isDone: widget.itemToEdit?.isDone ?? false,
      isHidden: widget.itemToEdit?.isHidden ?? false,
      createdAt: widget.itemToEdit?.createdAt ?? DateTime.now(),
    );

    if (widget.itemToEdit != null) {
      ref.read(wishlistProvider.notifier).updateItem(newItem);
    } else {
      ref.read(wishlistProvider.notifier).addItem(newItem);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tc = ref.watch(themeProvider).colors;
    
    return Container(
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Tab Selector
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'mine', label: Text('Mine 🛍️')),
                ButtonSegment(value: 'theirs', label: Text('Theirs 💝')),
                ButtonSegment(value: 'shared', label: Text('Ours 🌟')),
              ],
              selected: {_visibility},
              onSelectionChanged: (set) => setState(() => _visibility = set.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.blush : tc.backgroundColor),
                foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.rose : tc.textMuted),
              ),
            ),
            const SizedBox(height: 20),
            
            // 2. Title
            TextField(
              controller: _titleCtrl,
              style: GoogleFonts.dmSans(color: tc.textPrimary, fontStyle: FontStyle.normal),
              decoration: InputDecoration(
                hintText: 'Item Name...',
                hintStyle: GoogleFonts.dmSans(color: tc.textMuted),
                filled: true,
                fillColor: tc.backgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            
            // Priority
            SwitchListTile(
              title: Text('Mark as priority ⭐', style: GoogleFonts.dmSans(color: tc.textPrimary, fontWeight: FontWeight.w600)),
              value: _isPriority,
              activeColor: AppColors.rose,
              onChanged: (v) => setState(() => _isPriority = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),

            // 3. Emotional Tags
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((t) {
                final selected = _emotionalTag == t;
                return GestureDetector(
                  onTap: () => setState(() => _emotionalTag = selected ? null : t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? _getTagColor(t) : tc.backgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: selected ? Colors.transparent : tc.borderColor),
                    ),
                    child: Text(t, style: GoogleFonts.dmSans(color: selected ? Colors.white : tc.textMuted, fontSize: 13, fontStyle: FontStyle.normal)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 4. Price (hidden for Ours)
            if (_visibility != 'shared') ...[
              TextField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.dmSans(color: tc.textPrimary, fontStyle: FontStyle.normal),
                decoration: InputDecoration(
                  hintText: 'Price ₹ (optional)',
                  hintStyle: GoogleFonts.dmSans(color: tc.textMuted),
                  filled: true,
                  fillColor: tc.backgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 5. Link
            TextField(
              controller: _linkCtrl,
              style: GoogleFonts.dmSans(color: tc.textPrimary, fontStyle: FontStyle.normal),
              decoration: InputDecoration(
                hintText: 'Link URL (optional)',
                hintStyle: GoogleFonts.dmSans(color: tc.textMuted),
                filled: true,
                fillColor: tc.backgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            // 6. Notes
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              style: GoogleFonts.dmSans(color: tc.textPrimary, fontStyle: FontStyle.normal),
              decoration: InputDecoration(
                hintText: _visibility == 'theirs' ? "She'd love this because..." : 'Notes...',
                hintStyle: GoogleFonts.dmSans(color: tc.textMuted),
                filled: true,
                fillColor: tc.backgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),

            // 7. Save Button
            RoseButton(
              label: 'Save',
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }
}
