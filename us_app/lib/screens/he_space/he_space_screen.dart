import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../config/app_colors.dart';
import '../../core/groq_client.dart';
import '../../providers/couple_provider.dart';
import '../../providers/food_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/reminders_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../providers/partner_care_provider.dart';
import '../../models/memory_model.dart';
import '../../models/reminder_model.dart';
import '../../models/wishlist_model.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/v2/glass_container.dart';
import '../../widgets/v2/space_header.dart';
import '../../widgets/v2/visibility_badge.dart';

// Helper models for He Space local states
class HeRoutine {
  final String id;
  final String emoji;
  final String label;
  final String time;
  bool isCompleted;

  HeRoutine({
    required this.id,
    required this.emoji,
    required this.label,
    required this.time,
    this.isCompleted = false,
  });

  factory HeRoutine.fromJson(Map<String, dynamic> j) => HeRoutine(
        id: j['id'] as String,
        emoji: j['emoji'] as String? ?? '☀️',
        label: j['label'] as String? ?? '',
        time: j['time'] as String? ?? '',
        isCompleted: j['isCompleted'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'emoji': emoji,
        'label': label,
        'time': time,
        'isCompleted': isCompleted,
      };
}

class HeGoal {
  final String id;
  final String title;
  double progress; // 0.0 to 1.0
  bool isPrivate;

  HeGoal({
    required this.id,
    required this.title,
    this.progress = 0.0,
    this.isPrivate = true,
  });

  factory HeGoal.fromJson(Map<String, dynamic> j) => HeGoal(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        progress: (j['progress'] as num? ?? 0.0).toDouble(),
        isPrivate: j['isPrivate'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'progress': progress,
        'isPrivate': isPrivate,
      };
}

class HeReflection {
  final String id;
  final String content;
  final String mood;
  final String visibility; // 'private' | 'partner_visible' | 'shared'
  final DateTime createdAt;

  HeReflection({
    required this.id,
    required this.content,
    required this.mood,
    required this.visibility,
    required this.createdAt,
  });

  factory HeReflection.fromJson(Map<String, dynamic> j) => HeReflection(
        id: j['id'] as String,
        content: j['content'] as String? ?? '',
        mood: j['mood'] as String? ?? '😊',
        visibility: j['visibility'] as String? ?? 'private',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'mood': mood,
        'visibility': visibility,
        'createdAt': createdAt.toIso8601String(),
      };
}

class HeAmbition {
  final String id;
  final String title;
  final DateTime createdAt;

  HeAmbition({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  factory HeAmbition.fromJson(Map<String, dynamic> j) => HeAmbition(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
      };
}

class ParsedMemory {
  final String cleanContent;
  final String importance; // 'casual' | 'important' | 'deeply_important'

  ParsedMemory({required this.cleanContent, required this.importance});

  factory ParsedMemory.parse(String content) {
    if (content.startsWith('[deeply_important]')) {
      return ParsedMemory(
        cleanContent: content.replaceFirst('[deeply_important]', '').trim(),
        importance: 'deeply_important',
      );
    } else if (content.startsWith('[important]')) {
      return ParsedMemory(
        cleanContent: content.replaceFirst('[important]', '').trim(),
        importance: 'important',
      );
    } else if (content.startsWith('[casual]')) {
      return ParsedMemory(
        cleanContent: content.replaceFirst('[casual]', '').trim(),
        importance: 'casual',
      );
    }
    return ParsedMemory(cleanContent: content, importance: 'casual');
  }
}

class HeSpaceScreen extends ConsumerStatefulWidget {
  const HeSpaceScreen({super.key});

  @override
  ConsumerState<HeSpaceScreen> createState() => _HeSpaceScreenState();
}

class _HeSpaceScreenState extends ConsumerState<HeSpaceScreen> {
  // Quick capture state
  final TextEditingController _captureController = TextEditingController();
  bool _isCapturing = false;
  String _selectedImportance = 'casual';
  String _selectedVisibility = 'shared';

  // Today Card state (Mood, Energy, Note)
  String _todayMood = '😊';
  double _todayEnergy = 0.8;
  final TextEditingController _todayNoteController = TextEditingController();

  // Reflections V2 States
  final TextEditingController _reflectionController = TextEditingController();
  final String _reflectionMood = '😊';
  String _reflectionVisibility = 'private';
  List<HeReflection> _reflections = [];

  // Ambitions V2 States
  List<HeAmbition> _ambitions = [];

  // Mention Frequency V2 States
  String? _detectedFrequentKeyword;
  int _frequentKeywordCount = 0;

  // Lists stored locally in SharedPreferences
  List<HeRoutine> _routines = [];
  List<HeGoal> _goals = [];
  List<dynamic> _privateNotesPreview = [];

  bool _loadingLocal = true;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
  }

  @override
  void dispose() {
    _captureController.dispose();
    _todayNoteController.dispose();
    _reflectionController.dispose();
    super.dispose();
  }

  // ── Load & Save Helpers ───────────────────────────────────────────────────
  Future<void> _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateStr = DateFormat('yyyy-MM-DD').format(DateTime.now());

      // Mood & Energy
      setState(() {
        _todayMood = prefs.getString('he_today_mood') ?? '😊';
        _todayEnergy = prefs.getDouble('he_today_energy') ?? 0.8;
        _todayNoteController.text = prefs.getString('he_today_note') ?? '';
      });

      // Routines: load with date check to reset daily completion
      final storedRoutinesRaw = prefs.getString('he_routines');
      if (storedRoutinesRaw != null) {
        final List<dynamic> list = jsonDecode(storedRoutinesRaw);
        _routines = list.map((e) => HeRoutine.fromJson(e)).toList();
      } else {
        // Defaults
        _routines = [
          HeRoutine(id: 'r1', emoji: '☀️', label: 'Morning routine', time: '08:00'),
          HeRoutine(id: '💪', emoji: '💪', label: 'Gym workout', time: '17:30'),
          HeRoutine(id: '📚', emoji: '📚', label: 'Study session', time: '20:00'),
          HeRoutine(id: '💼', emoji: '💼', label: 'Deep work focus', time: '10:00'),
        ];
        _saveRoutines();
      }

      // Check daily routine completions
      final completionsRaw = prefs.getString('he_routines_completed_$dateStr');
      if (completionsRaw != null) {
        final List<dynamic> completedIds = jsonDecode(completionsRaw);
        for (var r in _routines) {
          r.isCompleted = completedIds.contains(r.id);
        }
      }

      // Goals
      final storedGoalsRaw = prefs.getString('he_personal_goals');
      if (storedGoalsRaw != null) {
        final List<dynamic> list = jsonDecode(storedGoalsRaw);
        _goals = list.map((e) => HeGoal.fromJson(e)).toList();
      } else {
        _goals = [
          HeGoal(id: 'g1', title: 'Learn Flutter Animation V2', progress: 0.6),
          HeGoal(id: 'g2', title: 'Read 20 pages everyday', progress: 0.35),
        ];
        _saveGoals();
      }

      // Private Notes preview
      final storedNotesRaw = prefs.getString('he_private_notes');
      if (storedNotesRaw != null) {
        _privateNotesPreview = jsonDecode(storedNotesRaw);
      }

      // Reflections
      final storedReflectionsRaw = prefs.getString('he_reflections');
      if (storedReflectionsRaw != null) {
        final List<dynamic> list = jsonDecode(storedReflectionsRaw);
        _reflections = list.map((e) => HeReflection.fromJson(e)).toList();
      }

      // Ambitions
      final storedAmbitionsRaw = prefs.getString('he_ambitions');
      if (storedAmbitionsRaw != null) {
        final List<dynamic> list = jsonDecode(storedAmbitionsRaw);
        _ambitions = list.map((e) => HeAmbition.fromJson(e)).toList();
      } else {
        _ambitions = [
          HeAmbition(id: 'a1', title: 'Build my dream game', createdAt: DateTime.now()),
          HeAmbition(id: 'a2', title: 'Travel with her across Europe', createdAt: DateTime.now()),
          HeAmbition(id: 'a3', title: 'Become financially independent', createdAt: DateTime.now()),
        ];
        _saveAmbitions();
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingLocal = false);
  }

  Future<void> _saveRoutines() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('he_routines', jsonEncode(_routines.map((r) => r.toJson()).toList()));
  }

  Future<void> _saveRoutinesDailyCompletions() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = DateFormat('yyyy-MM-DD').format(DateTime.now());
    final completedIds = _routines.where((r) => r.isCompleted).map((r) => r.id).toList();
    await prefs.setString('he_routines_completed_$dateStr', jsonEncode(completedIds));
  }

  Future<void> _saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('he_personal_goals', jsonEncode(_goals.map((g) => g.toJson()).toList()));
  }

  Future<void> _saveTodayCard(String mood, double energy, String note) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('he_today_mood', mood);
    await prefs.setDouble('he_today_energy', energy);
    await prefs.setString('he_today_note', note);
  }

  Future<void> _saveReflections() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('he_reflections', jsonEncode(_reflections.map((r) => r.toJson()).toList()));
  }

  Future<void> _saveAmbitions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('he_ambitions', jsonEncode(_ambitions.map((a) => a.toJson()).toList()));
  }

  Future<void> _addReflection() async {
    final text = _reflectionController.text.trim();
    if (text.isEmpty) return;

    final reflection = HeReflection(
      id: const Uuid().v4(),
      content: text,
      mood: _reflectionMood,
      visibility: _reflectionVisibility,
      createdAt: DateTime.now(),
    );

    setState(() {
      _reflections.insert(0, reflection);
      _reflectionController.clear();
    });
    await _saveReflections();

    // Sync to Supabase memories if visibility is partner_visible or shared
    if (_reflectionVisibility != 'private') {
      final coupleState = ref.read(coupleProvider).valueOrNull;
      final myId = coupleState?.currentUser?.id;
      final coupleId = coupleState?.currentUser?.coupleId;
      if (myId != null) {
        try {
          await ref.read(memoryProvider.notifier).addMemory(
                content: '[Daily Reflection] $text (Vibe: $_reflectionMood)',
                category: 'mood',
                ownerId: myId,
                space: 'he',
                visibility: _reflectionVisibility,
                isPartnerCare: false,
                coupleId: coupleId,
              );
        } catch (_) {}
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reflection saved! 💭',
            style: GoogleFonts.dmSans(fontStyle: FontStyle.normal),
          ),
          backgroundColor: const Color(0xFFE8607A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _addAmbition(String title) {
    if (title.trim().isEmpty) return;
    final a = HeAmbition(
      id: const Uuid().v4(),
      title: title.trim(),
      createdAt: DateTime.now(),
    );
    setState(() {
      _ambitions.add(a);
    });
    _saveAmbitions();
  }

  void _deleteAmbition(int index) {
    setState(() {
      _ambitions.removeAt(index);
    });
    _saveAmbitions();
  }

  void _analyzeMentionFrequencies(List<MemoryModel> memories) {
    if (memories.isEmpty) return;
    final wordCounts = <String, int>{};
    final stopWords = {
      'she', 'likes', 'her', 'the', 'and', 'for', 'was', 'with', 'about', 'some',
      'this', 'that', 'hates', 'loves', 'wants', 'would', 'movie', 'their'
    };

    for (var m in memories) {
      final cleanText = ParsedMemory.parse(m.content).cleanContent.toLowerCase();
      final words = cleanText.split(RegExp(r'\s+'));
      for (var w in words) {
        final cleanWord = w.replaceAll(RegExp(r'[^\w]'), '');
        if (cleanWord.length > 3 && !stopWords.contains(cleanWord)) {
          wordCounts[cleanWord] = (wordCounts[cleanWord] ?? 0) + 1;
        }
      }
    }

    String? topWord;
    int maxCount = 0;
    wordCounts.forEach((word, count) {
      if (count >= 3 && count > maxCount) {
        maxCount = count;
        topWord = word;
      }
    });

    if (topWord != null && mounted && _detectedFrequentKeyword != topWord) {
      setState(() {
        _detectedFrequentKeyword = topWord;
        _frequentKeywordCount = maxCount;
      });
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  void _toggleRoutine(int index) {
    setState(() {
      _routines[index].isCompleted = !_routines[index].isCompleted;
    });
    _saveRoutinesDailyCompletions();
  }

  void _addCustomRoutine(String emoji, String label, String time) {
    final r = HeRoutine(
      id: const Uuid().v4(),
      emoji: emoji.isEmpty ? '☀️' : emoji,
      label: label,
      time: time,
    );
    setState(() {
      _routines.add(r);
    });
    _saveRoutines();
  }

  void _addPersonalGoal(String title) {
    final g = HeGoal(
      id: const Uuid().v4(),
      title: title,
      progress: 0.0,
    );
    setState(() {
      _goals.add(g);
    });
    _saveGoals();
  }

  void _updateGoalProgress(int index, double progress) {
    setState(() {
      _goals[index].progress = progress;
    });
    _saveGoals();
  }

  void _deleteGoal(int index) {
    setState(() {
      _goals.removeAt(index);
    });
    _saveGoals();
  }

  // ── Quick Capture memory saving ───────────────────────────────────────────
  Future<void> _onQuickCapture() async {
    final text = _captureController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isCapturing = true);

    try {
      final notifier = ref.read(partnerCareProvider.notifier);
      // AI Auto-categorization using partnerCareProvider
      final category = await notifier.autoCategorizeMemo(text);
      
      // Save memory to partner care table using partnerCareProvider
      await notifier.addMemory(text, category);

      _captureController.clear();
      setState(() {
        _selectedImportance = 'casual';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved 💕 (AI Category: $category)',
              style: GoogleFonts.dmSans(fontStyle: FontStyle.normal),
            ),
            backgroundColor: const Color(0xFFE8607A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // Fallback
      final coupleState = ref.read(coupleProvider).valueOrNull;
      final myId = coupleState?.currentUser?.id;
      if (myId != null) {
        try {
          await ref.read(partnerCareProvider.notifier).addMemory(text, 'general');
          _captureController.clear();
        } catch (_) {}
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _onNavTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        break;
      case 1:
        context.go('/us-space');
        break;
      case 2:
        context.go('/she-space');
        break;
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final coupleState = ref.watch(coupleProvider).valueOrNull;
    final themeState = ref.watch(themeProvider);
    final tc = themeState.colors;

    final myId = coupleState?.currentUser?.id;
    final myName = coupleState?.currentUser?.name.split(' ').first ?? 'Kavin';
    final partner = coupleState?.partner;
    final partnerName = partner?.name.split(' ').first ?? 'Her';
    final partnerAvatar = partner?.avatarUrl;

    // Fetch food logs for summary
    final foodLogs = ref.watch(foodProvider).valueOrNull ?? [];
    final todayLogs = foodLogs.where((l) {
      final today = DateTime.now();
      return l.userId == myId &&
          l.loggedAt.year == today.year &&
          l.loggedAt.month == today.month &&
          l.loggedAt.day == today.day;
    }).toList();
    final todayCalories = todayLogs.fold<int>(0, (sum, item) => sum + (item.calories ?? 0));

    // Fetch reminders for Section 1 Today Reminders Preview
    final allReminders = ref.watch(remindersProvider).valueOrNull ?? [];
    final todayReminders = allReminders.where((r) {
      final now = DateTime.now();
      return r.remindTo == myId &&
          r.isActive &&
          r.remindAt.year == now.year &&
          r.remindAt.month == now.month &&
          r.remindAt.day == now.day;
    }).toList();

    // Fetch memories for Section 2 About Her Memory list & insights
    final memories = ref.watch(memoryProvider).valueOrNull ?? [];
    final partnerCareMemories = memories.where((m) => m.isPartnerCare && m.space == 'he').toList();

    // Run mention frequency keyword scan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && partnerCareMemories.isNotEmpty) {
        _analyzeMentionFrequencies(partnerCareMemories);
      }
    });

    // Fetch wishlist items for Section 3 Wishlist preview
    final wishlist = ref.watch(wishlistProvider).valueOrNull ?? [];
    final myWishlistItems = wishlist.where((w) => w.addedBy == myId && !w.isDone && !w.isHidden).toList();

    return Scaffold(
      backgroundColor: tc.backgroundColor,
      bottomNavigationBar: BottomNav(
        currentIndex: 0,
        onTap: (i) => _onNavTap(context, i),
      ),
      body: SafeArea(
        child: _loadingLocal
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFE8607A)),
              )
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── Space Header ───────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: SpaceHeader(
                      emoji: '♂',
                      title: 'He Space',
                      subtitle: '${_getGreeting()}, $myName',
                      gradientColors: AppColors.heGradient,
                      avatarWidget: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xFFE8607A),
                              backgroundImage: partnerAvatar != null && partnerAvatar.isNotEmpty
                                  ? NetworkImage(partnerAvatar)
                                  : null,
                              child: partnerAvatar == null || partnerAvatar.isEmpty
                                  ? const Text('♀', style: TextStyle(fontSize: 10, color: Colors.white))
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Thinking of $partnerName',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontStyle: FontStyle.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailingWidget: GestureDetector(
                        onTap: () => context.go('/settings'),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: const Icon(Icons.settings_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // ── SECTION 1: TODAY ─────────────────────────────────────────
                        _buildSectionTitle('Today', 'Daily emotional grounding'),
                        const SizedBox(height: 12),
                        _buildTodayCheckInCard(todayReminders),
                        const SizedBox(height: 32),

                        // ── SECTION 2: ABOUT HER (Emotional core) ────────────────────
                        _buildSectionTitle('About $partnerName', 'Things I remember, observe and plan'),
                        const SizedBox(height: 12),
                        _buildAboutHerSection(partnerCareMemories),
                        const SizedBox(height: 32),

                        // ── SECTION 3: MY LIFE (lifestyle systems) ───────────────────
                        _buildSectionTitle('My Life', 'Routines, goals, and lifestyle tracking'),
                        const SizedBox(height: 12),
                        _buildMyLifeSection(todayCalories, todayLogs, myWishlistItems),
                        const SizedBox(height: 32),

                        // ── SECTION 4: PRIVATE MIND (safe reflections) ───────────────
                        _buildSectionTitle('Private Mind', 'Locked thoughts and reflections history'),
                        const SizedBox(height: 12),
                        _buildPrivateMindSection(),
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Section Title builder ──────────────────────────────────────────────────
  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontStyle: FontStyle.normal,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.4),
            fontStyle: FontStyle.normal,
          ),
        ),
      ],
    );
  }

  // ── SECTION 1: TODAY widgets ────────────────────────────────────────────────
  Widget _buildTodayCheckInCard(List<ReminderModel> reminders) {
    final moods = ['😊', '😔', '😤', '😴', '🥰'];

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prompt & mood
          Text(
            'How are you feeling today?',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
              fontStyle: FontStyle.normal,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: moods.map((m) {
              final active = _todayMood == m;
              return GestureDetector(
                onTap: () {
                  setState(() => _todayMood = m);
                  _saveTodayCard(_todayMood, _todayEnergy, _todayNoteController.text);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFE8607A).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: active ? const Color(0xFFE8607A) : Colors.white.withValues(alpha: 0.08),
                      width: active ? 1.5 : 1,
                    ),
                  ),
                  child: Text(m, style: const TextStyle(fontSize: 22)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Energy slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Energy Level',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white60,
                  fontStyle: FontStyle.normal,
                ),
              ),
              Text(
                '${(_todayEnergy * 100).toInt()}%',
                style: GoogleFonts.dmMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFE8607A),
                  fontStyle: FontStyle.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFFE8607A),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
              thumbColor: const Color(0xFFE8607A),
              overlayColor: const Color(0xFFE8607A).withValues(alpha: 0.1),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              trackHeight: 4,
            ),
            child: Slider(
              value: _todayEnergy,
              onChanged: (val) {
                setState(() => _todayEnergy = val);
                _saveTodayCard(_todayMood, _todayEnergy, _todayNoteController.text);
              },
            ),
          ),
          const SizedBox(height: 20),

          // Today's Reminders Preview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🔔 Today\'s Reminders',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  fontStyle: FontStyle.normal,
                ),
              ),
              GestureDetector(
                onTap: () => context.go('/he-space/planner'),
                child: Text(
                  'See all',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: const Color(0xFFE8607A),
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.normal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (reminders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'No remaining reminders for today. Peaceful day! 🌸',
                style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white30, fontStyle: FontStyle.normal),
              ),
            )
          else
            Column(
              children: reminders.take(3).map((r) {
                final timeStr = DateFormat('h:mm a').format(r.remindAt);
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          ref.read(remindersProvider.notifier).toggleReminder(r.id, false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Completed: ${r.title} 🎉', style: GoogleFonts.dmSans(fontStyle: FontStyle.normal)),
                              backgroundColor: const Color(0xFFE8607A),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: const Icon(Icons.circle_outlined, size: 16, color: Color(0xFFE8607A)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          r.title,
                          style: GoogleFonts.dmSans(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontStyle: FontStyle.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: GoogleFonts.dmMono(
                          fontSize: 10,
                          color: Colors.white30,
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 20),

          // Daily reflection input
          Text(
            'Daily reflection (stored separately)',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white60,
              fontStyle: FontStyle.normal,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reflectionController,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: Colors.white,
              fontStyle: FontStyle.normal,
            ),
            decoration: InputDecoration(
              hintText: 'Today felt peaceful... / miss her...',
              hintStyle: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.22),
                fontSize: 12.5,
                fontStyle: FontStyle.normal,
              ),
              prefixIcon: const Icon(Icons.bubble_chart_outlined, size: 16, color: Colors.white30),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.03),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('👁️', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  DropdownButton<String>(
                    dropdownColor: const Color(0xFF160A0D),
                    value: _reflectionVisibility,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white30, size: 16),
                    style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold, fontStyle: FontStyle.normal),
                    items: const [
                      DropdownMenuItem(value: 'private', child: Text('Private')),
                      DropdownMenuItem(value: 'partner_visible', child: Text('For Her')),
                      DropdownMenuItem(value: 'shared', child: Text('Shared')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _reflectionVisibility = v);
                      }
                    },
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _addReflection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8607A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  'Reflect 💭',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.normal,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── SECTION 2: ABOUT HER widgets ────────────────────────────────────────────
  Widget _buildAboutHerSection(List<MemoryModel> memories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Keyword Insight Banner if repeated words are detected
        if (_detectedFrequentKeyword != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFE8607A).withValues(alpha: 0.12),
                  const Color(0xFF9B2647).withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8607A).withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI INSIGHT: "$_detectedFrequentKeyword" has been recorded $_frequentKeywordCount times recently. This seems deeply important to her!',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFFB3C6),
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Quick capture memory card
        _buildAboutHerCaptureCard(),
        const SizedBox(height: 14),

        // Memories List Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Remembered details about her',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white60,
                fontStyle: FontStyle.normal,
              ),
            ),
            GestureDetector(
              onTap: () => context.go('/he-space/partner-care'),
              child: Text(
                'Manage',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: const Color(0xFFE8607A),
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (memories.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No recorded memories about her yet. Start noticing details! 💕',
                style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white24, fontStyle: FontStyle.normal),
              ),
            ),
          )
        else
          Column(
            children: memories.take(4).map((m) {
              final parsed = ParsedMemory.parse(m.content);
              
              Color borderCol = Colors.white.withValues(alpha: 0.06);
              double borderWidth = 1;
              List<BoxShadow> shadows = [];
              Widget? starBadge;

              if (parsed.importance == 'important') {
                borderCol = const Color(0xFFC97B93).withValues(alpha: 0.35);
                borderWidth = 1.5;
              } else if (parsed.importance == 'deeply_important') {
                borderCol = const Color(0xFFE8607A).withValues(alpha: 0.5);
                borderWidth = 2;
                shadows = [
                  BoxShadow(
                    color: const Color(0xFFE8607A).withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ];
                starBadge = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8607A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE8607A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 10, color: Color(0xFFE8607A)),
                      const SizedBox(width: 2),
                      Text(
                        'Deeply Important',
                        style: GoogleFonts.dmSans(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white, fontStyle: FontStyle.normal),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol, width: borderWidth),
                  boxShadow: shadows,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          MemoryModel.categoryEmoji(m.category),
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                parsed.cleanContent,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13.5,
                                  color: Colors.white,
                                  fontWeight: parsed.importance == 'deeply_important' ? FontWeight.w600 : FontWeight.w400,
                                  fontStyle: FontStyle.normal,
                                ).copyWith(color: Colors.white70),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    DateFormat('d MMM yyyy').format(m.createdAt),
                                    style: GoogleFonts.dmMono(fontSize: 9.5, color: Colors.white24, fontStyle: FontStyle.normal),
                                  ),
                                  const SizedBox(width: 8),
                                  VisibilityBadge(visibility: m.visibility, compact: true),
                                  if (starBadge != null) ...[
                                    const SizedBox(width: 8),
                                    starBadge,
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildAboutHerCaptureCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF160A0E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8607A).withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _captureController,
            style: GoogleFonts.dmSans(color: Colors.white, fontStyle: FontStyle.normal),
            decoration: InputDecoration(
              hintText: 'Save something about her...',
              hintStyle: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.22),
                fontStyle: FontStyle.normal,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.02),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          
          // Importance Selector
          Row(
            children: [
              Text(
                'Importance: ',
                style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white30, fontWeight: FontWeight.bold, fontStyle: FontStyle.normal),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildChip('casual', 'Casual ☕', _selectedImportance == 'casual', (v) {
                        setState(() => _selectedImportance = 'casual');
                      }),
                      const SizedBox(width: 6),
                      _buildChip('important', 'Important ⭐', _selectedImportance == 'important', (v) {
                        setState(() => _selectedImportance = 'important');
                      }),
                      const SizedBox(width: 6),
                      _buildChip('deeply_important', 'Deeply Important 💖', _selectedImportance == 'deeply_important', (v) {
                        setState(() => _selectedImportance = 'deeply_important');
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Visibility selector
          Row(
            children: [
              Text(
                'Visibility: ',
                style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white30, fontWeight: FontWeight.bold, fontStyle: FontStyle.normal),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildChip('private', 'Private 🔒', _selectedVisibility == 'private', (v) {
                        setState(() => _selectedVisibility = 'private');
                      }),
                      const SizedBox(width: 6),
                      _buildChip('partner_visible', 'For Her 👁️', _selectedVisibility == 'partner_visible', (v) {
                        setState(() => _selectedVisibility = 'partner_visible');
                      }),
                      const SizedBox(width: 6),
                      _buildChip('shared', 'Shared 💑', _selectedVisibility == 'shared', (v) {
                        setState(() => _selectedVisibility = 'shared');
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _isCapturing
                  ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(color: Color(0xFFE8607A), strokeWidth: 2),
                    )
                  : GestureDetector(
                      onTap: _onQuickCapture,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFE8607A), Color(0xFF9B2647)]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String key, String label, bool active, ValueChanged<bool> onTap) {
    return GestureDetector(
      onTap: () => onTap(true),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE8607A).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? const Color(0xFFE8607A) : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 10.5,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? const Color(0xFFE8607A) : Colors.white54,
            fontStyle: FontStyle.normal,
          ),
        ),
      ),
    );
  }

  // ── SECTION 3: MY LIFE widgets ──────────────────────────────────────────────
  Widget _buildMyLifeSection(int calories, List<dynamic> foodLogs, List<WishlistModel> wishlistItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Routines Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Daily Routines',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white60,
                fontStyle: FontStyle.normal,
              ),
            ),
            TextButton.icon(
              onPressed: _showAddRoutineDialog,
              icon: const Icon(Icons.add_rounded, size: 14, color: Color(0xFFE8607A)),
              label: Text(
                'Add',
                style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFE8607A), fontStyle: FontStyle.normal),
              ),
            ),
          ],
        ),
        _buildRoutinesScroll(),
        const SizedBox(height: 18),

        // Personal Goals Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Short-Term Goals',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white60,
                fontStyle: FontStyle.normal,
              ),
            ),
            TextButton.icon(
              onPressed: _showAddGoalDialog,
              icon: const Icon(Icons.add_rounded, size: 14, color: Color(0xFFE8607A)),
              label: Text(
                'Add',
                style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFE8607A), fontStyle: FontStyle.normal),
              ),
            ),
          ],
        ),
        _buildGoalsSection(),
        const SizedBox(height: 18),

        // Ambitions Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Long-Term Ambitions 🌟',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white60,
                fontStyle: FontStyle.normal,
              ),
            ),
            TextButton.icon(
              onPressed: _showAddAmbitionDialog,
              icon: const Icon(Icons.add_rounded, size: 14, color: Color(0xFFE8607A)),
              label: Text(
                'Add',
                style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFE8607A), fontStyle: FontStyle.normal),
              ),
            ),
          ],
        ),
        _buildAmbitionsSection(),
        const SizedBox(height: 18),

        // Food Log Preview
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Food Logger',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white60,
                fontStyle: FontStyle.normal,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/he-space/food'),
              child: Text(
                'Logs 🍛',
                style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFE8607A), fontStyle: FontStyle.normal),
              ),
            ),
          ],
        ),
        _buildFoodPreviewCard(calories, foodLogs),
        const SizedBox(height: 18),

        // Wishlist preview
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Wishlist Preview',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white60,
                fontStyle: FontStyle.normal,
              ),
            ),
            GestureDetector(
              onTap: () => context.go('/us-space/wishlist'),
              child: Text(
                'See all',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: const Color(0xFFE8607A),
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildWishlistSection(wishlistItems),
      ],
    );
  }

  Widget _buildRoutinesScroll() {
    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _routines.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final r = _routines[i];
          return GestureDetector(
            onTap: () => _toggleRoutine(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 136,
              decoration: BoxDecoration(
                color: r.isCompleted
                    ? const Color(0xFFE8607A).withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: r.isCompleted
                      ? const Color(0xFFE8607A)
                      : Colors.white.withValues(alpha: 0.08),
                  width: r.isCompleted ? 1.5 : 1,
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(r.emoji, style: const TextStyle(fontSize: 20)),
                      Icon(
                        r.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: r.isCompleted ? const Color(0xFFE8607A) : Colors.white24,
                        size: 16,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        r.label,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: r.isCompleted ? const Color(0xFFE8607A) : Colors.white70,
                          fontStyle: FontStyle.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        r.time,
                        style: GoogleFonts.dmMono(
                          fontSize: 10,
                          color: Colors.white30,
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGoalsSection() {
    if (_goals.isEmpty) {
      return Center(
        child: Text(
          'No goals set yet! tap add 🎯',
          style: GoogleFonts.dmSans(color: Colors.white24, fontSize: 12, fontStyle: FontStyle.normal),
        ),
      );
    }

    return Column(
      children: List.generate(_goals.length, (i) {
        final g = _goals[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.title,
                      style: GoogleFonts.dmSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: g.progress,
                              minHeight: 5,
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE8607A)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(g.progress * 100).toInt()}%',
                          style: GoogleFonts.dmMono(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFE8607A),
                            fontStyle: FontStyle.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white30, size: 18),
                color: const Color(0xFF160A0D),
                onSelected: (val) {
                  if (val == 'progress') {
                    _showUpdateGoalDialog(i);
                  } else if (val == 'delete') {
                    _deleteGoal(i);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'progress',
                    child: Text('Update Progress', style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete Goal', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildAmbitionsSection() {
    if (_ambitions.isEmpty) {
      return Center(
        child: Text(
          'No ambitions written down yet. Think big! 🌠',
          style: GoogleFonts.dmSans(color: Colors.white24, fontSize: 12, fontStyle: FontStyle.normal),
        ),
      );
    }

    return Column(
      children: List.generate(_ambitions.length, (i) {
        final a = _ambitions[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.05),
                const Color(0xFF9B2647).withValues(alpha: 0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8607A).withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  a.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                    fontStyle: FontStyle.normal,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _deleteAmbition(i),
                icon: const Icon(Icons.close, size: 14, color: Colors.white24),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildFoodPreviewCard(int totalCalories, List<dynamic> logs) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🥗', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    'Logged Energy',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8607A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$totalCalories kcal',
                  style: GoogleFonts.dmMono(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFE8607A),
                    fontStyle: FontStyle.normal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (logs.isEmpty)
            Text(
              'No food logged today. fuel up! 🔋',
              style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white24, fontStyle: FontStyle.normal),
            )
          else
            Column(
              children: logs.take(2).map((l) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${l.mealType.toUpperCase()} - ${l.description}',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: Colors.white54,
                            fontStyle: FontStyle.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${l.calories} kcal',
                        style: GoogleFonts.dmMono(
                          fontSize: 11,
                          color: Colors.white30,
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildWishlistSection(List<WishlistModel> items) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Center(
          child: Text(
            'Wishlist is empty. Tap top right to edit! 🛍️',
            style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white24, fontStyle: FontStyle.normal),
          ),
        ),
      );
    }

    return SizedBox(
      height: 98,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final item = items[i];
          final hasPrice = item.price != null && item.price! > 0;
          return Container(
            width: 148,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontStyle: FontStyle.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.type == 'buy' ? '🛍️ Purchase' : '✨ Vibe',
                      style: GoogleFonts.dmSans(fontSize: 9, color: Colors.white30, fontStyle: FontStyle.normal),
                    ),
                    if (hasPrice)
                      Text(
                        '₹${item.price!.toInt()}',
                        style: GoogleFonts.dmMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE8607A),
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── SECTION 4: PRIVATE MIND widgets ──────────────────────────────────────────
  Widget _buildPrivateMindSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Private Notes Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '🔒 Device-Only Private Notes',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white60,
                fontStyle: FontStyle.normal,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/he-space/notes'),
              child: Text(
                'Notes screen ➔',
                style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFE8607A), fontStyle: FontStyle.normal),
              ),
            ),
          ],
        ),
        _buildNotesPreviewSection(),
        const SizedBox(height: 18),

        // Reflections History Header
        Text(
          'Daily Reflections History',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white60,
            fontStyle: FontStyle.normal,
          ),
        ),
        const SizedBox(height: 8),
        _buildReflectionsHistorySection(),
      ],
    );
  }

  Widget _buildNotesPreviewSection() {
    if (_privateNotesPreview.isEmpty) {
      return Center(
        child: Text(
          'No private notes. Lock thoughts offline 🔐',
          style: GoogleFonts.dmSans(color: Colors.white24, fontSize: 12, fontStyle: FontStyle.normal),
        ),
      );
    }

    return Column(
      children: _privateNotesPreview.take(3).map((n) {
        final title = n['title'] as String? ?? 'Untitled Note';
        final content = n['content'] as String? ?? '';
        final date = DateTime.parse(n['createdAt'] as String);
        final dateStr = DateFormat('d MMM').format(date);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF10070A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📝', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                    Text(
                      content,
                      style: GoogleFonts.dmSans(
                        fontSize: 11.5,
                        color: Colors.white38,
                        fontStyle: FontStyle.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateStr,
                style: GoogleFonts.dmMono(
                  fontSize: 9.5,
                  color: Colors.white24,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReflectionsHistorySection() {
    if (_reflections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No reflection entries written yet.',
            style: GoogleFonts.dmSans(color: Colors.white24, fontSize: 12, fontStyle: FontStyle.normal),
          ),
        ),
      );
    }

    return Column(
      children: _reflections.take(3).map((r) {
        final dateStr = DateFormat('d MMM, h:mm a').format(r.createdAt);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0407),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8607A).withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(r.mood, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        dateStr,
                        style: GoogleFonts.dmMono(fontSize: 10, color: Colors.white30, fontStyle: FontStyle.normal),
                      ),
                    ],
                  ),
                  VisibilityBadge(visibility: r.visibility, compact: true),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                r.content,
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  color: Colors.white70,
                  fontStyle: FontStyle.normal,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Dialogs & Popups ───────────────────────────────────────────────────────
  void _showAddRoutineDialog() {
    final emojiCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    final timeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF160A0D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Daily Routine ☀️',
          style: GoogleFonts.playfairDisplay(color: Colors.white, fontWeight: FontWeight.bold, fontStyle: FontStyle.normal),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emojiCtrl,
              decoration: const InputDecoration(hintText: 'Emoji (e.g. ☀️)', hintStyle: TextStyle(color: Colors.white24)),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(hintText: 'Routine Label (e.g. Read books)', hintStyle: TextStyle(color: Colors.white24)),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: timeCtrl,
              decoration: const InputDecoration(hintText: 'Time (e.g. 08:30)', hintStyle: TextStyle(color: Colors.white24)),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final label = labelCtrl.text.trim();
              if (label.isNotEmpty) {
                _addCustomRoutine(emojiCtrl.text.trim(), label, timeCtrl.text.trim());
              }
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8607A)),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddGoalDialog() {
    final titleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF160A0D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'New Personal Goal 🎯',
          style: GoogleFonts.playfairDisplay(color: Colors.white, fontWeight: FontWeight.bold, fontStyle: FontStyle.normal),
        ),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(hintText: 'Goal title (e.g. Run 5km)', hintStyle: TextStyle(color: Colors.white24)),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleCtrl.text.trim();
              if (title.isNotEmpty) {
                _addPersonalGoal(title);
              }
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8607A)),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddAmbitionDialog() {
    final titleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF160A0D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'New Life Ambition 🌠',
          style: GoogleFonts.playfairDisplay(color: Colors.white, fontWeight: FontWeight.bold, fontStyle: FontStyle.normal),
        ),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(hintText: 'Ambition (e.g. Build my dream game)', hintStyle: TextStyle(color: Colors.white24)),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleCtrl.text.trim();
              if (title.isNotEmpty) {
                _addAmbition(title);
              }
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8607A)),
            child: const Text('Inspire ⭐', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showUpdateGoalDialog(int index) {
    double tempVal = _goals[index].progress;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF160A0D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Goal Progress 🎯',
            style: GoogleFonts.playfairDisplay(color: Colors.white, fontWeight: FontWeight.bold, fontStyle: FontStyle.normal),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(tempVal * 100).toInt()}% Completed',
                style: GoogleFonts.dmSans(color: const Color(0xFFE8607A), fontWeight: FontWeight.bold, fontStyle: FontStyle.normal),
              ),
              const SizedBox(height: 10),
              Slider(
                value: tempVal,
                onChanged: (val) {
                  setDlgState(() => tempVal = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                _updateGoalProgress(index, tempVal);
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8607A)),
              child: const Text('Update', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
