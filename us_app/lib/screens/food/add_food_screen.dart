import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uuid/uuid.dart';

import '../../config/app_colors.dart';
import '../../models/food_log_model.dart';
import '../../providers/couple_provider.dart';
import '../../providers/food_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/rose_button.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class AddFoodScreen extends ConsumerStatefulWidget {
  const AddFoodScreen({super.key, this.initialMealType});
  final String? initialMealType;

  @override
  ConsumerState<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends ConsumerState<AddFoodScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // WHO
  bool _forPartner = false;

  // Shared fields
  String?  _mealType;
  final    _caloriesCtrl = TextEditingController();
  final    _notesCtrl    = TextEditingController();

  // Photo tab
  Uint8List?    _photoBytes;
  String?       _photoUrl;
  List<String>  _detectedFoods = [];
  bool          _isUploading   = false;
  bool          _isAnalyzing   = false;

  // Text tab
  final _descCtrl = TextEditingController();

  bool _isSaving = false;

  static const _suggestions = [
    'Rice and dal',
    'Maggi',
    'Coffee ☕',
    'Dosa',
    'Idli',
    'Roti sabzi',
    'Pizza 🍕',
  ];

  @override
  void initState() {
    super.initState();
    _tab      = TabController(length: 2, vsync: this);
    _mealType = widget.initialMealType;
  }

  @override
  void dispose() {
    _tab.dispose();
    _descCtrl.dispose();
    _caloriesCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Photo picking ────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final xfile = await ImagePicker()
        .pickImage(source: source, imageQuality: 80);
    if (xfile == null) return;

    final bytes = await xfile.readAsBytes();

    setState(() {
      _photoBytes   = bytes;
      _photoUrl     = null;
      _detectedFoods = [];
      _isUploading  = true;
    });

    try {
      final url = await ref
          .read(foodProvider.notifier)
          .uploadFoodPhotoBytes(bytes, xfile.name);
      setState(() {
        _photoUrl    = url;
        _isUploading = false;
        _isAnalyzing = true;
      });

      final foods = await ref
          .read(foodProvider.notifier)
          .analyzeFoodPhoto(url);
      setState(() {
        _detectedFoods = foods;
        _isAnalyzing   = false;
        if (foods.isNotEmpty && _descCtrl.text.isEmpty) {
          _descCtrl.text = foods.join(', ');
        }
      });
    } catch (_) {
      setState(() {
        _isUploading = false;
        _isAnalyzing = false;
        if (_descCtrl.text.isEmpty) {
          _descCtrl.text = xfile.name;
        }
      });
    }
  }

  // ── Submit ───────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_mealType == null) {
      _snack('Select a meal type');
      return;
    }
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty && _photoUrl == null) {
      _snack('Add a photo or description');
      return;
    }

    final couple    = ref.read(coupleProvider).valueOrNull;
    final myId      = couple?.currentUser?.id;
    final partnerId = couple?.partner?.id;
    final userId    = _forPartner ? partnerId : myId;
    if (userId == null) {
      _snack('User not found');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final notes = _notesCtrl.text.trim();
      final log = FoodLogModel(
        id:          const Uuid().v4(),
        userId:      userId,
        description: desc.isEmpty
            ? (_detectedFoods.isNotEmpty ? _detectedFoods.first : 'Food')
            : desc,
        photoUrl:    _photoUrl,
        calories:    int.tryParse(_caloriesCtrl.text.trim()),
        mealType:    _mealType!,
        mood:        notes.isEmpty ? null : notes,
        loggedAt:    DateTime.now(),
      );
      await ref.read(foodProvider.notifier).addLog(log);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Logged 💕',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w500),
          ),
          backgroundColor: AppColors.rose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
      _snack('Failed to save. Try again.');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.dmSans()),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tc          = ref.watch(themeProvider).colors;
    final coupleState = ref.watch(coupleProvider).valueOrNull;
    final myName      =
        coupleState?.currentUser?.name.split(' ').first ?? 'Me';
    final partnerName =
        coupleState?.partner?.name.split(' ').first ?? 'Her';

    return Scaffold(
      backgroundColor: tc.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: tc.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Log Food',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: tc.textPrimary,
          ),
        ),
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
              Tab(text: '📷  Photo'),
              Tab(text: '✏️  Text'),
            ],
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ── WHO toggle ───────────────────────────────────────────
            if (coupleState?.partner != null) ...[
              _WhoToggle(
                forPartner:   _forPartner,
                myLabel:      myName,
                partnerLabel: partnerName,
                tc:           tc,
                onChanged:    (v) => setState(() => _forPartner = v),
              ),
              const SizedBox(height: 16),
            ],

            // ── Tab content ──────────────────────────────────────────
            SizedBox(
              height: 280,
              child: TabBarView(
                controller: _tab,
                children: [
                  _PhotoTab(
                    photoBytes:    _photoBytes,
                    photoUrl:      _photoUrl,
                    detectedFoods: _detectedFoods,
                    isUploading:   _isUploading,
                    isAnalyzing:   _isAnalyzing,
                    tc:            tc,
                    onPickImage:   _pickImage,
                    onUseFood:     (name) => setState(() {
                      _descCtrl.text = name;
                      _tab.animateTo(1);
                    }),
                  ),
                  _TextTab(
                    controller:  _descCtrl,
                    suggestions: _suggestions,
                    tc:          tc,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Meal type ────────────────────────────────────────────
            _SectionLabel(label: 'Meal Type', tc: tc),
            const SizedBox(height: 10),
            _MealTypeChips(
              selected:  _mealType,
              tc:        tc,
              onChanged: (v) => setState(() => _mealType = v),
            ),
            const SizedBox(height: 20),

            // ── Notes (replaces mood) ─────────────────────────────────
            _SectionLabel(label: 'Notes (optional)', tc: tc),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: tc.inputFillColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: tc.borderColor,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TextField(
                controller: _notesCtrl,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: tc.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Describe how you felt or any notes about this meal…',
                  hintStyle: GoogleFonts.dmSans(
                    color: tc.textMuted,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Calories ─────────────────────────────────────────────
            _CaloriesField(controller: _caloriesCtrl, tc: tc),
            const SizedBox(height: 28),

            // ── Submit ───────────────────────────────────────────────
            RoseButton(
              label:     'Log it 🍱',
              isLoading: _isSaving,
              onTap:     _isSaving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ── WHO toggle ────────────────────────────────────────────────────────────────

class _WhoToggle extends StatelessWidget {
  const _WhoToggle({
    required this.forPartner,
    required this.myLabel,
    required this.partnerLabel,
    required this.tc,
    required this.onChanged,
  });

  final bool        forPartner;
  final String      myLabel;
  final String      partnerLabel;
  final ThemeColors tc;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Logging for:',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: tc.textMuted,
          ),
        ),
        const SizedBox(width: 12),
        _Opt(
          label:  myLabel,
          active: !forPartner,
          onTap:  () => onChanged(false),
          tc:     tc,
        ),
        const SizedBox(width: 8),
        _Opt(
          label:  partnerLabel,
          active: forPartner,
          onTap:  () => onChanged(true),
          tc:     tc,
        ),
      ],
    );
  }
}

class _Opt extends StatelessWidget {
  const _Opt({
    required this.label,
    required this.active,
    required this.onTap,
    required this.tc,
  });

  final String      label;
  final bool        active;
  final VoidCallback onTap;
  final ThemeColors tc;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? tc.iconColor
              : tc.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? tc.iconColor : tc.borderColor,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: tc.iconColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : tc.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Photo tab ─────────────────────────────────────────────────────────────────

class _PhotoTab extends StatelessWidget {
  const _PhotoTab({
    required this.photoBytes,
    required this.photoUrl,
    required this.detectedFoods,
    required this.isUploading,
    required this.isAnalyzing,
    required this.tc,
    required this.onPickImage,
    required this.onUseFood,
  });

  final Uint8List?     photoBytes;
  final String?        photoUrl;
  final List<String>   detectedFoods;
  final bool           isUploading;
  final bool           isAnalyzing;
  final ThemeColors    tc;
  final Future<void> Function(ImageSource) onPickImage;
  final void Function(String) onUseFood;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Photo box
        Expanded(
          child: _PhotoBox(
            photoBytes:  photoBytes,
            isUploading: isUploading,
            tc:          tc,
            onCamera:    () => onPickImage(ImageSource.camera),
            onGallery:   () => onPickImage(ImageSource.gallery),
          ),
        ),

        // Detected food chips
        if (isAnalyzing) ...[
          const SizedBox(height: 8),
          Shimmer.fromColors(
            baseColor:      tc.cardColor,
            highlightColor: tc.borderColor,
            child: Row(
              children: List.generate(
                3,
                (_) => Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 80,
                  height: 28,
                  decoration: BoxDecoration(
                    color: tc.cardColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ] else if (detectedFoods.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: detectedFoods
                .map((name) => ActionChip(
                      label: Text(
                        name,
                        style: GoogleFonts.dmSans(
                            fontSize: 12, color: tc.iconColor),
                      ),
                      backgroundColor:
                          tc.iconColor.withValues(alpha: 0.1),
                      side: BorderSide(
                          color: tc.iconColor.withValues(alpha: 0.3)),
                      onPressed: () => onUseFood(name),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _PhotoBox extends StatelessWidget {
  const _PhotoBox({
    required this.photoBytes,
    required this.isUploading,
    required this.tc,
    required this.onCamera,
    required this.onGallery,
  });

  final Uint8List?   photoBytes;
  final bool         isUploading;
  final ThemeColors  tc;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color:  tc.iconColor.withValues(alpha: 0.45),
        radius: 16,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          color: tc.iconColor.withValues(alpha: 0.04),
          child: isUploading
              ? Shimmer.fromColors(
                  baseColor:      tc.cardColor,
                  highlightColor: tc.borderColor,
                  child: Container(color: tc.cardColor),
                )
              : photoBytes != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(photoBytes!, fit: BoxFit.cover),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: onGallery,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🍽️',
                            style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            _PhotoBtn(
                              icon:    Icons.camera_alt_rounded,
                              label:   'Take Photo',
                              tc:      tc,
                              onTap:   onCamera,
                            ),
                            const SizedBox(width: 12),
                            _PhotoBtn(
                              icon:    Icons.photo_library_rounded,
                              label:   'Gallery',
                              tc:      tc,
                              onTap:   onGallery,
                            ),
                          ],
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _PhotoBtn extends StatelessWidget {
  const _PhotoBtn({
    required this.icon,
    required this.label,
    required this.tc,
    required this.onTap,
  });

  final IconData    icon;
  final String      label;
  final ThemeColors tc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: tc.iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: tc.iconColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: tc.iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: tc.iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dashed border painter ─────────────────────────────────────────────────────

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, this.radius = 16});
  final Color  color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = color
      ..strokeWidth = 1.5
      ..style       = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius)));

    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final end = (dist + 6).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, end), paint);
        dist += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

// ── Text tab ──────────────────────────────────────────────────────────────────

class _TextTab extends StatelessWidget {
  const _TextTab({
    required this.controller,
    required this.suggestions,
    required this.tc,
  });

  final TextEditingController controller;
  final List<String>          suggestions;
  final ThemeColors           tc;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: tc.inputFillColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: tc.borderColor,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: controller,
              maxLines:   null,
              expands:    true,
              textAlignVertical: TextAlignVertical.top,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: tc.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'What did she eat?',
                hintStyle: GoogleFonts.dmSans(
                    color: tc.textMuted, fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Quick suggestion chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: suggestions
                .map((s) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          final existing = controller.text;
                          controller.text = existing.isEmpty
                              ? s
                              : '$existing, $s';
                          controller.selection =
                              TextSelection.fromPosition(
                                  TextPosition(
                                      offset:
                                          controller.text.length));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: tc.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: tc.borderColor,
                            ),
                          ),
                          child: Text(
                            s,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: tc.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ── Meal type chips ───────────────────────────────────────────────────────────

class _MealTypeChips extends StatelessWidget {
  const _MealTypeChips({
    required this.selected,
    required this.tc,
    required this.onChanged,
  });

  final String?     selected;
  final ThemeColors tc;
  final void Function(String) onChanged;

  static const _meals = [
    (type: FoodLogModel.mealBreakfast, emoji: '🌅', label: 'Breakfast'),
    (type: FoodLogModel.mealLunch,     emoji: '☀️', label: 'Lunch'),
    (type: FoodLogModel.mealDinner,    emoji: '🌙', label: 'Dinner'),
    (type: FoodLogModel.mealSnack,     emoji: '🍪', label: 'Snack'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: _meals.map((m) {
        final active = selected == m.type;
        return GestureDetector(
          onTap: () => onChanged(m.type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: active
                  ? tc.iconColor.withValues(alpha: 0.15)
                  : tc.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active
                    ? tc.iconColor
                    : tc.borderColor,
                width: active ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(m.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  m.label,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: active
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: active
                        ? tc.iconColor
                        : tc.textPrimary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Calories field ────────────────────────────────────────────────────────────


class _CaloriesField extends StatelessWidget {
  const _CaloriesField(
      {required this.controller, required this.tc});
  final TextEditingController controller;
  final ThemeColors           tc;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '🔥 Calories (optional)',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: tc.textMuted,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: tc.inputFillColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: tc.borderColor,
              ),
            ),
            child: TextField(
              controller:     controller,
              keyboardType:   TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly
              ],
              style: GoogleFonts.dmMono(
                fontSize: 14,
                color: tc.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: GoogleFonts.dmMono(
                    color: tc.textMuted, fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                suffixText: 'kcal',
                suffixStyle: GoogleFonts.dmSans(
                    fontSize: 11, color: tc.textMuted),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.tc});
  final String      label;
  final ThemeColors tc;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: tc.textMuted,
        letterSpacing: 0.4,
      ),
    );
  }
}
