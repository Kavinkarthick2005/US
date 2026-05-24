import 'package:supabase_flutter/supabase_flutter.dart';

/// Global Supabase client instance — import this everywhere instead of
/// calling Supabase.instance.client directly.
final supabase = Supabase.instance.client;

/// Convenience getter: returns the currently authenticated user's UUID,
/// or null when no session is active.
String? get currentUserId => supabase.auth.currentUser?.id;
