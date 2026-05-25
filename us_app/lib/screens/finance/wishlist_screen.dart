import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

Color _getPriorityColor(String? priority) {
  switch (priority?.toLowerCase()) {
    case 'high':
      return AppColors.rose;
    case 'medium':
      return Colors.amber;
    case 'low':
      return Colors.green;
    default:
      return Colors.grey;
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
  bool _showHidden = false;

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

  void _openAddSheet({WishlistModel? itemToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddWishlistSheet(
        initialType: itemToEdit?.type ??
            (_tab.index == 0 ? WishlistModel.typeBuy : WishlistModel.typeExperience),
        itemToEdit: itemToEdit,
      ),
    );
  }

  void _promptPin(ThemeColors tc) {
    if (_showHidden) {
      setState(() => _showHidden = false);
      return;
    }
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tc.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Enter PIN',
            style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.bold, color: tc.textPrimary)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: InputDecoration(
            hintText: '4-digit PIN',
            hintStyle: GoogleFonts.dmSans(color: tc.textMuted),
            counterText: '',
          ),
          style: GoogleFonts.dmSans(color: tc.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.dmSans(color: tc.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final saved = prefs.getString('wishlist_pin') ?? '0000';
              if (ctrl.text == saved) {
                if (mounted) {
                  setState(() => _showHidden = true);
                  Navigator.pop(ctx);
                }
              } else {
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Incorrect PIN')));
                }
              }
            },
            child: Text('Unlock', style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        ],
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
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
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
            onPressed: () => _openAddSheet(),
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(
            child: Text('Failed to load wishlist: $e',
                style: TextStyle(color: tc.textPrimary))),
        data: (allData) {
          final notifier = ref.read(wishlistProvider.notifier);
          final coupleState = ref.watch(coupleProvider).valueOrNull;

          final buyItems = notifier.buyItems;
          final expItems = notifier.experienceItems;
          final doneAll = notifier.doneItems;
          final doneBuy =
              doneAll.where((i) => i.type == WishlistModel.typeBuy).toList();
          final doneExp = doneAll
              .where((i) => i.type == WishlistModel.typeExperience)
              .toList();

          final hiddenCount = notifier.hiddenItems.length;
          final totalBudget = notifier.totalBuyBudget;

          final allActive = buyItems.length + expItems.length;
          final totalDone = doneAll.length;
          final totalItems = allActive + totalDone;
          final progress = totalItems == 0 ? 0.0 : totalDone / totalItems;

          return Column(
            children: [
              if (totalItems > 0)
                _ProgressTracker(
                  progress: progress,
                  completed: totalDone,
                  total: totalItems,
                  budget: totalBudget,
                  tc: tc,
                ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _TabContent(
                      items: buyItems,
                      doneItems: doneBuy,
                      hiddenItems: _showHidden
                          ? notifier.hiddenItems
                              .where((i) => i.type == WishlistModel.typeBuy)
                              .toList()
                          : [],
                      coupleState: coupleState,
                      tc: tc,
                      emptyMessage: 'Nothing on your list yet 🛍️',
                      emptySubMessage: 'Add something you both want',
                      onEdit: (item) => _openAddSheet(itemToEdit: item),
                      onAdd: () => _openAddSheet(),
                    ),
                    _TabContent(
                      items: expItems,
                      doneItems: doneExp,
                      hiddenItems: _showHidden
                          ? notifier.hiddenItems
                              .where(
                                  (i) => i.type == WishlistModel.typeExperience)
                              .toList()
                          : [],
                      coupleState: coupleState,
                      tc: tc,
                      emptyMessage: 'No adventures planned yet 🌟',
                      emptySubMessage: 'Add a place or dream',
                      onEdit: (item) => _openAddSheet(itemToEdit: item),
                      onAdd: () => _openAddSheet(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextButton.icon(
                  onPressed: () => _promptPin(tc),
                  icon: Icon(
                      _showHidden
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 18,
                      color: tc.textMuted),
                  label: Text(
                      _showHidden
                          ? 'Hide Secrets'
                          : 'Show Hidden ($hiddenCount)',
                      style: GoogleFonts.dmSans(color: tc.textMuted)),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddSheet(),
        backgroundColor: tc.iconColor,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ── Progress Tracker ──────────────────────────────────────────────────────────

class _ProgressTracker extends StatelessWidget {
  const _ProgressTracker({
    required this.progress,
    required this.completed,
    required this.total,
    required this.budget,
    required this.tc,
  });

  final double progress;
  final int completed;
  final int total;
  final double budget;
  final ThemeColors tc;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completed of $total completed',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tc.textPrimary,
                ),
              ),
              if (budget > 0)
                Text(
                  '${_rupees(budget)} total value',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: tc.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.blush,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.rose),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab Content ───────────────────────────────────────────────────────────────

class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.items,
    required this.doneItems,
    required this.hiddenItems,
    required this.coupleState,
    required this.tc,
    required this.emptyMessage,
    required this.emptySubMessage,
    required this.onEdit,
    required this.onAdd,
  });

  final List<WishlistModel> items;
  final List<WishlistModel> doneItems;
  final List<WishlistModel> hiddenItems;
  final CoupleState? coupleState;
  final ThemeColors tc;
  final String emptyMessage;
  final String emptySubMessage;
  final Function(WishlistModel) onEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && doneItems.isEmpty && hiddenItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emptyMessage,
                style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: tc.textPrimary)),
            const SizedBox(height: 4),
            Text(emptySubMessage,
                style: GoogleFonts.dmSans(fontSize: 13, color: tc.textMuted)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blush,
                foregroundColor: AppColors.rose,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Add Item',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        if (hiddenItems.isNotEmpty)
          ...hiddenItems.map((item) => _WishlistItemCard(
                item: item,
                coupleState: coupleState,
                tc: tc,
                onEdit: () => onEdit(item),
              )),
        ...items.map((item) => _WishlistItemCard(
              item: item,
              coupleState: coupleState,
              tc: tc,
              onEdit: () => onEdit(item),
            )),
        if ((items.isNotEmpty || hiddenItems.isNotEmpty) && doneItems.isNotEmpty)
          const SizedBox(height: 16),
        if (doneItems.isNotEmpty)
          _DoneSection(
            items: doneItems,
            coupleState: coupleState,
            tc: tc,
            onEdit: onEdit,
          ),
      ],
    );
  }
}

// ── Item Card ─────────────────────────────────────────────────────────────────

class _WishlistItemCard extends ConsumerStatefulWidget {
  const _WishlistItemCard({
    required this.item,
    required this.coupleState,
    required this.tc,
    required this.onEdit,
  });

  final WishlistModel item;
  final CoupleState? coupleState;
  final ThemeColors tc;
  final VoidCallback onEdit;

  @override
  ConsumerState<_WishlistItemCard> createState() => _WishlistItemCardState();
}

class _WishlistItemCardState extends ConsumerState<_WishlistItemCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.tc.cardColor,
        title: Text('Delete Item?',
            style: GoogleFonts.dmSans(
                color: widget.tc.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('Remove this item from your wishlist?',
            style: GoogleFonts.dmSans(color: widget.tc.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.dmSans(color: widget.tc.textMuted)),
          ),
          TextButton(
            onPressed: () {
              ref.read(wishlistProvider.notifier).deleteItem(widget.item.id);
              Navigator.pop(ctx);
            },
            child: Text('Delete',
                style: GoogleFonts.dmSans(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
    final adder = addedByMe
        ? widget.coupleState?.currentUser
        : widget.coupleState?.partner;
    final adderName = adder?.name.split(' ').first ?? 'Someone';
    final avatarUrl = adder?.avatarUrl;

    Widget card = AnimatedScale(
      scale: _isPressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: tc.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tc.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
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
                    placeholder: (context, url) => Container(
                      height: 140,
                      color: AppColors.blush,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 80,
                      color: AppColors.blush,
                      child: const Icon(Icons.broken_image, color: AppColors.rose),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: category & priority
                    Row(
                      children: [
                        if (item.category != null && item.category!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.blush,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.category!,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.rose,
                              ),
                            ),
                          ),
                        if (item.isHidden) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.lock_rounded, size: 14, color: tc.iconColor),
                        ],
                        const Spacer(),
                        if (item.priority != null && item.priority!.isNotEmpty)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _getPriorityColor(item.priority),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Title
                    Text(
                      item.title,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: tc.textPrimary,
                      ),
                    ),

                    // Description
                    if (item.description != null && item.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: tc.textMuted,
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Price & Link
                    Row(
                      children: [
                        if (item.price != null)
                          Text(
                            _rupees(item.price!),
                            style: GoogleFonts.dmMono(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.rose,
                            ),
                          ),
                        if (item.price != null &&
                            item.link != null &&
                            item.link!.isNotEmpty)
                          const SizedBox(width: 12),
                        if (item.link != null && item.link!.isNotEmpty)
                          GestureDetector(
                            onTap: () => _launchLink(item.link!),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: tc.iconColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: tc.iconColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                'View Item 🔗',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: tc.iconColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1, thickness: 1),
                    const SizedBox(height: 12),

                    // Bottom Row: Avatar, Done, Edit, Delete
                    Row(
                      children: [
                        _MiniAvatar(url: avatarUrl, tc: tc),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            adderName,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: tc.textMuted,
                            ),
                          ),
                        ),
                        if (!item.isDone) ...[
                          TextButton.icon(
                            onPressed: () {
                              ref.read(wishlistProvider.notifier).markDone(item.id);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.rose,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: Text('Mark Done',
                                style: GoogleFonts.dmSans(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                        ],
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_horiz_rounded,
                              color: tc.textMuted, size: 20),
                          color: tc.cardColor,
                          padding: EdgeInsets.zero,
                          onSelected: (val) async {
                            if (val == 'edit') {
                              widget.onEdit();
                            } else if (val == 'hide') {
                              await ref
                                  .read(wishlistProvider.notifier)
                                  .hideItem(item.id);
                            } else if (val == 'delete') {
                              _confirmDelete();
                            }
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit',
                                    style: GoogleFonts.dmSans(
                                        color: tc.textPrimary))),
                            if (!item.isHidden)
                              PopupMenuItem(
                                  value: 'hide',
                                  child: Text('Hide',
                                      style: GoogleFonts.dmSans(
                                          color: tc.textPrimary))),
                            PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete',
                                    style: GoogleFonts.dmSans(
                                        color: Colors.redAccent))),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (item.isDone) {
      return Stack(
        children: [
          Opacity(opacity: 0.6, child: card),
          Positioned.fill(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: Colors.green, size: 48),
              ),
            ),
          ),
        ],
      );
    }

    return card;
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
          color: tc.iconColor.withOpacity(0.1),
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
    required this.onEdit,
  });

  final List<WishlistModel> items;
  final CoupleState? coupleState;
  final ThemeColors tc;
  final Function(WishlistModel) onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        title: Text(
          'Completed (${items.length})',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: tc.textMuted,
          ),
        ),
        iconColor: tc.textMuted,
        collapsedIconColor: tc.textMuted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        children: items
            .map((item) => Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: _WishlistItemCard(
                    item: item,
                    coupleState: coupleState,
                    tc: tc,
                    onEdit: () => onEdit(item),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ── Add bottom sheet ──────────────────────────────────────────────────────────

class _AddWishlistSheet extends ConsumerStatefulWidget {
  const _AddWishlistSheet({required this.initialType, this.itemToEdit});
  final String initialType;
  final WishlistModel? itemToEdit;

  @override
  ConsumerState<_AddWishlistSheet> createState() => _AddWishlistSheetState();
}

class _AddWishlistSheetState extends ConsumerState<_AddWishlistSheet> {
  late String _type;
  late String? _category;
  late String? _priority;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  final _imgCtrl = TextEditingController();
  bool _isSaving = false;

  final List<String> _categories = [
    'Gifts',
    'Food',
    'Fashion',
    'Tech',
    'Travel',
    'Experiences',
    'Dreams',
    'Custom'
  ];

  final List<String> _priorities = ['High', 'Medium', 'Low'];

  @override
  void initState() {
    super.initState();
    final item = widget.itemToEdit;
    _type = item?.type ?? widget.initialType;
    _category = item?.category;
    _priority = item?.priority;

    if (item != null) {
      _titleCtrl.text = item.title;
      _descCtrl.text = item.description ?? '';
      if (item.price != null) _priceCtrl.text = item.price.toString();
      _linkCtrl.text = item.link ?? '';
      _imgCtrl.text = item.imageUrl ?? '';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _linkCtrl.dispose();
    _imgCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _snack('Enter a title');
      return;
    }

    final coupleState = ref.read(coupleProvider).valueOrNull;
    final myId = coupleState?.currentUser?.id;
    if (myId == null) {
      _snack('Not authenticated');
      return;
    }
    final coupleId = coupleState?.coupleId ?? myId;

    setState(() => _isSaving = true);
    try {
      final item = WishlistModel(
        id: widget.itemToEdit?.id ?? const Uuid().v4(),
        coupleId: coupleId,
        addedBy: widget.itemToEdit?.addedBy ?? myId,
        title: title,
        description: _descCtrl.text.trim(),
        category: _category,
        priority: _priority,
        type: _type,
        price: double.tryParse(_priceCtrl.text.trim()),
        link: _linkCtrl.text.trim(),
        imageUrl: _imgCtrl.text.trim(),
        isDone: widget.itemToEdit?.isDone ?? false,
        isHidden: widget.itemToEdit?.isHidden ?? false,
        createdAt: widget.itemToEdit?.createdAt ?? DateTime.now(),
      );

      final notifier = ref.read(wishlistProvider.notifier);
      if (widget.itemToEdit != null) {
        await notifier.updateItem(item);
      } else {
        await notifier.addItem(item);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.itemToEdit != null ? 'Item updated ✨' : 'Added to wishlist ✨',
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
      _snack('Failed to save. Try again.');
    }
  }

  void _snack(String msg) {
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
    final isEdit = widget.itemToEdit != null;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: tc.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    color: tc.textMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // sheet title
              Text(
                isEdit ? 'Edit Item' : 'Add to Wishlist',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
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
                      label: Text('🛍️ Buy')),
                  ButtonSegment(
                      value: WishlistModel.typeExperience,
                      label: Text('🌟 Experience')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return tc.iconColor.withOpacity(0.15);
                    }
                    return Colors.transparent;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return tc.iconColor;
                    }
                    return tc.textMuted;
                  }),
                  side: WidgetStateProperty.all(
                      BorderSide(color: tc.iconColor.withOpacity(0.3))),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              _SheetField(
                controller: _titleCtrl,
                hint: 'Title (required)',
                tc: tc,
                autofocus: !isEdit,
              ),
              const SizedBox(height: 12),

              // Description
              _SheetField(
                controller: _descCtrl,
                hint: 'Description (optional)',
                tc: tc,
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Categories
              Text('Category',
                  style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tc.textPrimary)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final selected = _category == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: selected,
                        selectedColor: AppColors.blush,
                        backgroundColor: tc.inputFillColor,
                        labelStyle: GoogleFonts.dmSans(
                            color: selected ? AppColors.rose : tc.textMuted,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal),
                        side: BorderSide(
                            color: selected ? AppColors.rose : tc.borderColor),
                        onSelected: (_) => setState(() =>
                            _category = selected ? null : cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Priorities
              Text('Priority',
                  style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tc.textPrimary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _priorities.map((p) {
                  final selected = _priority == p;
                  final color = _getPriorityColor(p);
                  return ChoiceChip(
                    label: Text(p),
                    selected: selected,
                    selectedColor: color.withOpacity(0.15),
                    backgroundColor: tc.inputFillColor,
                    labelStyle: GoogleFonts.dmSans(
                        color: selected ? color : tc.textMuted,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal),
                    side: BorderSide(
                        color: selected ? color : tc.borderColor),
                    onSelected: (_) =>
                        setState(() => _priority = selected ? null : p),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Price
              _SheetField(
                controller: _priceCtrl,
                hint: '₹ Price (optional)',
                tc: tc,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 12),

              // Link
              _SheetField(
                controller: _linkCtrl,
                hint: 'Link URL (optional)',
                tc: tc,
                keyboard: TextInputType.url,
              ),
              const SizedBox(height: 12),

              // Image URL
              _SheetField(
                controller: _imgCtrl,
                hint: 'Image URL (optional)',
                tc: tc,
                keyboard: TextInputType.url,
              ),
              const SizedBox(height: 24),

              RoseButton(
                label: isEdit ? 'Update Item' : 'Save Item',
                isLoading: _isSaving,
                onTap: _isSaving ? null : _submit,
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

  final TextEditingController controller;
  final String hint;
  final ThemeColors tc;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: tc.inputFillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tc.borderColor),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        autofocus: autofocus,
        textCapitalization: TextCapitalization.sentences,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          color: tc.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(color: tc.textMuted, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          isDense: true,
        ),
      ),
    );
  }
}
