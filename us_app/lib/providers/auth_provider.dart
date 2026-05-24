import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Convenience getter
// ─────────────────────────────────────────────────────────────────────────────
SupabaseClient get _sb => Supabase.instance.client;

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

/// Exposes the current [User?] as an [AsyncValue].
/// - [AsyncData(null)]  → signed out
/// - [AsyncData(user)]  → authenticated
/// - [AsyncLoading]     → in-flight sign-in or initial check
/// - [AsyncError]       → something went wrong
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  AuthNotifier() : super(const AsyncLoading()) {
    _init();
  }

  // Keep subscription alive for the lifetime of this notifier.
  late final Stream<AuthState> _authStream;

  void _init() {
    final current = _sb.auth.currentUser;
    state = AsyncData(current);
    if (current != null) {
      _upsertProfile(current);
    }

    _authStream = _sb.auth.onAuthStateChange;
    _authStream.listen(
      (event) {
        state = AsyncData(event.session?.user);
        if (event.event == AuthChangeEvent.signedIn &&
            event.session?.user != null) {
          _upsertProfile(event.session!.user);
        }
      },
      onError: (Object e, StackTrace st) {
        state = AsyncError(e, st);
      },
    );
  }

  // ── Public actions ──────────────────────────────────────────────────────

  /// Launches Supabase Google OAuth flow.
  /// After a successful sign-in it upserts the `profiles` row and ensures
  /// a `couple_code` exists for the user.
  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    try {
      await _sb.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? Uri.base.origin
            : 'io.supabase.usapp://login-callback',
      );
      // For web: browser navigates away for OAuth; _init() listener handles
      // profile upsert and state update when the page returns.
      // For mobile: external browser opens; same listener handles the callback.
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Signs the current user out.
  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await _sb.auth.signOut();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  /// Upserts a `profiles` row for [user].
  /// - Uses `onConflict: 'id'` so a second sign-in never overwrites existing data.
  /// - Generates a random 6-char alphanumeric `couple_code` only on insert.
  Future<void> _upsertProfile(User user) async {
    final meta = user.userMetadata ?? {};
    final name = (meta['full_name'] as String?) ??
        (meta['name'] as String?) ??
        user.email?.split('@').first ??
        'Unknown';

    // Check if profile already has a couple_code — never overwrite it or
    // partner linking breaks on every re-login.
    final existing = await _sb
        .from('profiles')
        .select('couple_code')
        .eq('id', user.id)
        .maybeSingle();

    await _sb.from('profiles').upsert(
      {
        'id': user.id,
        'email': user.email,
        'name': name,
        'avatar_url': meta['avatar_url'] as String?,
        if (existing == null) 'couple_code': _generateCoupleCode(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'id',
      ignoreDuplicates: false,
    );
  }

  /// Generates a random 6-character uppercase alphanumeric code.
  String _generateCoupleCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Computed properties ─────────────────────────────────────────────────

  bool get isAuthenticated => state.valueOrNull != null;

  bool get isLoading => state is AsyncLoading;

  User? get currentUser => state.valueOrNull;
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

/// The primary auth provider — use this everywhere in the app.
final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier();
});

/// Convenience derived providers for common checks.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).valueOrNull != null;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).valueOrNull;
});
