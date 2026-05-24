import 'package:supabase_flutter/supabase_flutter.dart';

/// Global Supabase client — import this file anywhere you need DB/auth access.
final SupabaseClient supabase = Supabase.instance.client;

/// Convenience getter: returns the authenticated user's UUID or null.
String? get currentUserId => supabase.auth.currentUser?.id;
