import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/ai/ai_chat_screen.dart';
import '../screens/auth/couple_link_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/finance/add_expense_screen.dart';
import '../screens/finance/finance_screen.dart';
import '../screens/finance/wishlist_screen.dart';
import '../screens/food/add_food_screen.dart';
import '../screens/food/food_log_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/memory/add_memory_screen.dart';
import '../screens/memory/memory_screen.dart';
import '../screens/planner/planner_screen.dart';
import '../screens/settings/settings_screen.dart';

/// Returns the partner ID stored in the user's metadata, or null if not linked.
String? _getPartnerId() {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;
  return user.userMetadata?['partner_id'] as String?;
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  debugLogDiagnostics: false,
  redirect: (BuildContext context, GoRouterState state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isAuthenticated = session != null;
    final location = state.matchedLocation;

    // Always allow splash through — it drives navigation after init
    if (location == '/splash') return null;

    // Not authenticated → force login
    if (!isAuthenticated) {
      if (location == '/login') return null;
      return '/login';
    }

    // Authenticated but no partner linked → force link-partner
    final partnerId = _getPartnerId();
    if (partnerId == null || partnerId.isEmpty) {
      if (location == '/link-partner') return null;
      return '/link-partner';
    }

    // Authenticated + partner linked: boot screen back to home
    if (location == '/login' || location == '/link-partner') {
      return '/home';
    }

    return null; // no redirect needed
  },
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/link-partner',
      name: 'link-partner',
      builder: (context, state) => const CoupleLinkScreen(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/memory',
      name: 'memory',
      builder: (context, state) => const MemoryScreen(),
      routes: [
        GoRoute(
          path: 'add',
          name: 'memory-add',
          builder: (context, state) => const AddMemoryScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/food',
      name: 'food',
      builder: (context, state) => const FoodLogScreen(),
      routes: [
        GoRoute(
          path: 'add',
          name: 'food-add',
          builder: (context, state) => const AddFoodScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/finance',
      name: 'finance',
      builder: (context, state) => const FinanceScreen(),
      routes: [
        GoRoute(
          path: 'add',
          name: 'finance-add',
          builder: (context, state) => const AddExpenseScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/wishlist',
      name: 'wishlist',
      builder: (context, state) => const WishlistScreen(),
    ),
    GoRoute(
      path: '/planner',
      name: 'planner',
      builder: (context, state) => const PlannerScreen(),
    ),
    GoRoute(
      path: '/ai-chat',
      name: 'ai-chat',
      builder: (context, state) => const AiChatScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text(
        'Page not found: ${state.uri}',
        style: const TextStyle(fontSize: 16),
      ),
    ),
  ),
);
