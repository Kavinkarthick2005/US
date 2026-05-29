import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Auth
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/couple_link_screen.dart';
import '../screens/auth/onboarding_screen.dart';

// Us Space (Hub — default landing)
import '../screens/us_space/us_space_screen.dart';
import '../screens/us_space/drops_screen.dart';
import '../screens/us_space/add_drop_screen.dart';
import '../screens/us_space/timeline_screen.dart';
import '../screens/us_space/monthly_recap_screen.dart';
import '../screens/us_space/open_when_screen.dart';
import '../screens/us_space/add_letter_screen.dart';
import '../screens/us_space/gift_search_screen.dart';
import '../screens/us_space/shared_memories_screen.dart';

// He Space
import '../screens/he_space/he_space_screen.dart';
import '../screens/he_space/partner_care_screen.dart';
import '../screens/he_space/surprise_planner_screen.dart';
import '../screens/he_space/notes_screen.dart';

// She Space
import '../screens/she_space/she_space_screen.dart';
import '../screens/she_space/journal_screen.dart';
import '../screens/she_space/self_care_screen.dart';

// Feature screens
import '../screens/memory/memory_screen.dart';
import '../screens/memory/add_memory_screen.dart';
import '../screens/food/food_log_screen.dart';
import '../screens/food/add_food_screen.dart';
import '../screens/finance/finance_screen.dart';
import '../screens/finance/add_expense_screen.dart';
import '../screens/finance/wishlist_screen.dart';
import '../screens/planner/planner_screen.dart';
import '../screens/planner/period_screen.dart';
import '../screens/ai/ai_chat_screen.dart';
import '../screens/notes/notes_screen.dart';
import '../screens/settings/settings_screen.dart';

SupabaseClient get _sb => Supabase.instance.client;

/// Notifies GoRouter to re-evaluate redirects on auth state changes.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    _sub = _sb.auth.onAuthStateChange.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Slide-up + fade transition used for all V2 routes.
CustomTransitionPage<void> _slideUp(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Horizontal slide for space switching
CustomTransitionPage<void> _slideHorizontal(GoRouterState state, Widget child, double dx) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: Offset(dx, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  refreshListenable: _AuthChangeNotifier(),
  redirect: (BuildContext context, GoRouterState state) async {
    final location = state.matchedLocation;

    if (location == '/splash') return null;

    final user = _sb.auth.currentUser;

    if (user == null) {
      return location == '/login' ? null : '/login';
    }

    // Logged-in user trying to visit login → send to hub
    if (location == '/login') return '/us-space';

    return null;
  },
  routes: [
    // ── Auth ──────────────────────────────────────────────────────────────
    GoRoute(
      path: '/splash',
      name: 'splash',
      pageBuilder: (c, s) => _slideUp(s, const SplashScreen()),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      pageBuilder: (c, s) => _slideUp(s, const LoginScreen()),
    ),
    GoRoute(
      path: '/link-partner',
      name: 'link-partner',
      pageBuilder: (c, s) => _slideUp(s, const CoupleLinkScreen()),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      pageBuilder: (c, s) => _slideUp(s, const OnboardingScreen()),
    ),

    // ── Us Space (Hub / default landing) ─────────────────────────────────
    GoRoute(
      path: '/us-space',
      name: 'us-space',
      pageBuilder: (c, s) => _slideUp(s, const UsSpaceScreen()),
      routes: [
        GoRoute(
          path: 'drops',
          name: 'drops',
          pageBuilder: (c, s) => _slideUp(s, const DropsScreen()),
          routes: [
            GoRoute(
              path: 'add',
              name: 'drops-add',
              pageBuilder: (c, s) => _slideUp(s, const AddDropScreen()),
            ),
          ],
        ),
        GoRoute(
          path: 'timeline',
          name: 'timeline',
          pageBuilder: (c, s) => _slideUp(s, const TimelineScreen()),
        ),
        GoRoute(
          path: 'recap',
          name: 'recap',
          pageBuilder: (c, s) {
            final now = DateTime.now();
            final month = int.tryParse(s.uri.queryParameters['month'] ?? '') ?? now.month;
            final year = int.tryParse(s.uri.queryParameters['year'] ?? '') ?? now.year;
            return _slideUp(s, MonthlyRecapScreen(month: month, year: year));
          },
        ),
        GoRoute(
          path: 'open-when',
          name: 'open-when',
          pageBuilder: (c, s) => _slideUp(s, const OpenWhenScreen()),
          routes: [
            GoRoute(
              path: 'add',
              name: 'open-when-add',
              pageBuilder: (c, s) => _slideUp(s, const AddLetterScreen()),
            ),
          ],
        ),
        GoRoute(
          path: 'gift-search',
          name: 'gift-search',
          pageBuilder: (c, s) => _slideUp(s, const GiftSearchScreen()),
        ),
        GoRoute(
          path: 'memories',
          name: 'us-memories',
          pageBuilder: (c, s) => _slideUp(s, const SharedMemoriesScreen()),
        ),
        // Finance (shared between spaces but belongs to Us)
        GoRoute(
          path: 'finance',
          name: 'finance',
          pageBuilder: (c, s) => _slideUp(s, const FinanceScreen()),
          routes: [
            GoRoute(
              path: 'add',
              name: 'finance-add',
              pageBuilder: (c, s) => _slideUp(s, const AddExpenseScreen()),
            ),
          ],
        ),
        GoRoute(
          path: 'wishlist',
          name: 'wishlist',
          pageBuilder: (c, s) => _slideUp(s, const WishlistScreen()),
        ),
        GoRoute(
          path: 'ai-chat',
          name: 'ai-chat',
          pageBuilder: (c, s) => _slideUp(s, const AiChatScreen()),
        ),
      ],
    ),

    // ── He Space ──────────────────────────────────────────────────────────
    GoRoute(
      path: '/he-space',
      name: 'he-space',
      pageBuilder: (c, s) => _slideHorizontal(s, const HeSpaceScreen(), -1.0),
      routes: [
        GoRoute(
          path: 'partner-care',
          name: 'partner-care',
          pageBuilder: (c, s) => _slideUp(s, const PartnerCareScreen()),
          routes: [
            GoRoute(
              path: 'add',
              name: 'memory-add',
              pageBuilder: (c, s) => _slideUp(s, const AddMemoryScreen()),
            ),
          ],
        ),
        GoRoute(
          path: 'surprise',
          name: 'surprise',
          pageBuilder: (c, s) => _slideUp(s, const SurprisePlannerScreen()),
        ),
        GoRoute(
          path: 'notes',
          name: 'he-notes',
          pageBuilder: (c, s) => _slideUp(s, const HeNotesScreen()),
        ),
        GoRoute(
          path: 'food',
          name: 'food',
          pageBuilder: (c, s) => _slideUp(s, const FoodLogScreen()),
          routes: [
            GoRoute(
              path: 'add',
              name: 'food-add',
              pageBuilder: (c, s) => _slideUp(
                s,
                AddFoodScreen(
                  initialMealType: s.uri.queryParameters['meal'],
                ),
              ),
            ),
          ],
        ),
        GoRoute(
          path: 'memories',
          name: 'memories',
          pageBuilder: (c, s) => _slideUp(s, const MemoryScreen()),
        ),
        GoRoute(
          path: 'planner',
          name: 'planner',
          pageBuilder: (c, s) => _slideUp(s, const PlannerScreen()),
        ),
      ],
    ),

    // ── She Space ─────────────────────────────────────────────────────────
    GoRoute(
      path: '/she-space',
      name: 'she-space',
      pageBuilder: (c, s) => _slideHorizontal(s, const SheSpaceScreen(), 1.0),
      routes: [
        GoRoute(
          path: 'journal',
          name: 'journal',
          pageBuilder: (c, s) => _slideUp(s, const JournalScreen()),
        ),
        GoRoute(
          path: 'self-care',
          name: 'self-care',
          pageBuilder: (c, s) => _slideUp(s, const SelfCareScreen()),
        ),
        GoRoute(
          path: 'period',
          name: 'period',
          pageBuilder: (c, s) => _slideUp(s, const PeriodScreen()),
        ),
        GoRoute(
          path: 'notes',
          name: 'notes',
          pageBuilder: (c, s) => _slideUp(s, const NotesScreen()),
        ),
        GoRoute(
          path: 'reminders',
          name: 'reminders',
          pageBuilder: (c, s) => _slideUp(s, const PlannerScreen()),
        ),
      ],
    ),

    // ── Settings (global — accessible from header) ────────────────────────
    GoRoute(
      path: '/settings',
      name: 'settings',
      pageBuilder: (c, s) => _slideUp(s, const SettingsScreen()),
    ),

    // ── Legacy redirects (keep V1 deep links working) ─────────────────────
    GoRoute(
      path: '/home',
      redirect: (_, __) => '/us-space',
    ),
    GoRoute(
      path: '/memory',
      redirect: (_, __) => '/he-space/partner-care',
    ),
    GoRoute(
      path: '/finance',
      redirect: (_, __) => '/us-space/finance',
    ),
    GoRoute(
      path: '/food',
      redirect: (_, __) => '/he-space/food',
    ),
    GoRoute(
      path: '/planner',
      redirect: (_, __) => '/she-space/reminders',
    ),
    GoRoute(
      path: '/notes',
      redirect: (_, __) => '/she-space/notes',
    ),
    GoRoute(
      path: '/ai-chat',
      redirect: (_, __) => '/us-space/ai-chat',
    ),
    GoRoute(
      path: '/wishlist',
      redirect: (_, __) => '/us-space/wishlist',
    ),
  ],
);
