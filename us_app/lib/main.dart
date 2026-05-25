import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/env.dart';
import 'config/router.dart';
import 'core/fcm_service.dart';
import 'providers/theme_provider.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase + notifications only on mobile (no web Firebase project configured)
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
      tz.initializeTimeZones();
      // Do not await FCMService.init() here because requesting permissions before runApp
      // can cause an instant crash in release mode on Android 13+
      FCMService.init().catchError((e) => debugPrint("FCM Error: $e"));
    } catch (e) {
      debugPrint("Firebase init error: $e");
    }
  }

  // Init Supabase
  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint("Supabase init error: $e");
  }

  runApp(const ProviderScope(child: UsApp()));
}

class UsApp extends ConsumerWidget {
  const UsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final themeData = ref.watch(themeProvider.notifier).themeData;

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, child) => MaterialApp.router(
        title: 'Us',
        debugShowCheckedModeBanner: false,
        theme: themeData,
        themeMode: themeState.isDark ? ThemeMode.dark : ThemeMode.light,
        routerConfig: appRouter,
      ),
    );
  }
}
