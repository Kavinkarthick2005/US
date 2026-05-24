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
    await Firebase.initializeApp();
    tz.initializeTimeZones();
    await FCMService.init();
  }

  // Init Supabase
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

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
