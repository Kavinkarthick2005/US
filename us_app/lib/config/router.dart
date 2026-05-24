import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/couple_link_screen.dart';
import '../screens/home/home_screen.dart';
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
import '../screens/settings/settings_screen.dart';
import '../screens/notes/notes_screen.dart';

SupabaseClient get _sb => Supabase.instance.client;

/// Notifies GoRouter to re-evaluate redirects whenever Supabase auth changes.
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

CustomTransitionPage<void> _fade(
    GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
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

    if (location == '/login') {
      return '/home';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      pageBuilder: (context, state) => _fade(state, const SplashScreen()),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      pageBuilder: (context, state) => _fade(state, const LoginScreen()),
    ),
    GoRoute(
      path: '/link-partner',
      name: 'link-partner',
      pageBuilder: (context, state) =>
          _fade(state, const CoupleLinkScreen()),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      pageBuilder: (context, state) => _fade(state, const HomeScreen()),
    ),
    GoRoute(
      path: '/memory',
      name: 'memory',
      pageBuilder: (context, state) => _fade(state, const MemoryScreen()),
      routes: [
        GoRoute(
          path: 'add',
          name: 'memory-add',
          pageBuilder: (context, state) =>
              _fade(state, const AddMemoryScreen()),
        ),
      ],
    ),
    GoRoute(
      path: '/food',
      name: 'food',
      pageBuilder: (context, state) => _fade(state, const FoodLogScreen()),
      routes: [
        GoRoute(
          path: 'add',
          name: 'food-add',
          pageBuilder: (context, state) => _fade(
            state,
            AddFoodScreen(
              initialMealType: state.uri.queryParameters['meal'],
            ),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/finance',
      name: 'finance',
      pageBuilder: (context, state) =>
          _fade(state, const FinanceScreen()),
      routes: [
        GoRoute(
          path: 'add',
          name: 'finance-add',
          pageBuilder: (context, state) =>
              _fade(state, const AddExpenseScreen()),
        ),
      ],
    ),
    GoRoute(
      path: '/wishlist',
      name: 'wishlist',
      pageBuilder: (context, state) =>
          _fade(state, const WishlistScreen()),
    ),
    GoRoute(
      path: '/planner',
      name: 'planner',
      pageBuilder: (context, state) =>
          _fade(state, const PlannerScreen()),
      routes: [
        GoRoute(
          path: 'period',
          name: 'period',
          pageBuilder: (context, state) =>
              _fade(state, const PeriodScreen()),
        ),
      ],
    ),
    GoRoute(
      path: '/ai-chat',
      name: 'ai-chat',
      pageBuilder: (context, state) =>
          _fade(state, const AiChatScreen()),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      pageBuilder: (context, state) =>
          _fade(state, const SettingsScreen()),
    ),
    GoRoute(
      path: '/notes',
      name: 'notes',
      pageBuilder: (context, state) =>
          _fade(state, const NotesScreen()),
    ),
  ],
);
