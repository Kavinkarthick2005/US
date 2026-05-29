import 'dart:developer';

/// A lightweight mock analytics service to log user events.
/// Replace with FirebaseAnalytics or similar for production tracking.
class AnalyticsService {
  static void logEvent(String name, {Map<String, dynamic>? parameters}) {
    // In production, this would send data to Firebase or Mixpanel.
    log('📊 Analytics Event: $name | params: $parameters');
  }

  static void logThemeUnlocked(String themeName) {
    logEvent('theme_unlocked', parameters: {'theme': themeName});
  }

  static void logDropCreated() {
    logEvent('drop_created');
  }

  static void logMemorySaved(String category) {
    logEvent('memory_saved', parameters: {'category': category});
  }
  
  static void logGiftSearched() {
    logEvent('gift_search');
  }
  
  static void logPeriodLogged() {
    logEvent('period_logged');
  }
}
