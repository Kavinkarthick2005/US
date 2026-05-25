import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/fcm_service.dart';
import '../models/reminder_model.dart';
import 'couple_provider.dart';

class RemindersNotifier extends AsyncNotifier<List<ReminderModel>> {
  final _supabase = Supabase.instance.client;

  @override
  Future<List<ReminderModel>> build() async {
    return _fetchReminders();
  }

  Future<List<ReminderModel>> _fetchReminders() async {
    final coupleState = ref.read(coupleProvider).valueOrNull;
    final myId = coupleState?.currentUser?.id;

    if (myId == null) return [];

    try {
      final data = await _supabase
          .from('reminders')
          .select()
          .or('user_id.eq.$myId,remind_to.eq.$myId')
          .order('remind_at', ascending: true);

      return (data as List)
          .map((json) => ReminderModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addReminder(ReminderModel r) async {
    try {
      // Insert to Supabase
      await _supabase.from('reminders').insert(r.toJson());
      
      // Schedule Local Notification
      _scheduleLocalNotification(r);
      
      if (state.hasValue) {
        state = AsyncData([...state.value!, r]);
      } else {
        ref.invalidateSelf();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleReminder(String id, bool isActive) async {
    try {
      await _supabase.from('reminders').update({'is_active': isActive}).eq('id', id);
      
      if (state.hasValue) {
        final updated = state.value!.map((r) {
          if (r.id == id) {
            final newR = ReminderModel(
              id: r.id,
              userId: r.userId,
              remindTo: r.remindTo,
              title: r.title,
              remindAt: r.remindAt,
              repeatType: r.repeatType,
              category: r.category,
              isActive: isActive,
              createdAt: r.createdAt,
            );
            if (isActive) _scheduleLocalNotification(newR);
            return newR;
          }
          return r;
        }).toList();
        state = AsyncData(updated);
      } else {
        ref.invalidateSelf();
      }

      if (!isActive) {
        await FCMService.localNotifications.cancel(id: id.hashCode);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteReminder(String id) async {
    try {
      await _supabase.from('reminders').delete().eq('id', id);
      await FCMService.localNotifications.cancel(id: id.hashCode);
      if (state.hasValue) {
        state = AsyncData(state.value!.where((r) => r.id != id).toList());
      } else {
        ref.invalidateSelf();
      }
    } catch (e) {
      rethrow;
    }
  }

  void _scheduleLocalNotification(ReminderModel r) async {
    if (kIsWeb) return;
    if (!r.isActive) return;

    final myId = _supabase.auth.currentUser?.id;
    if (r.remindTo != myId) return; // Only schedule locally if it's meant for me

    var scheduledDate = tz.TZDateTime.from(r.remindAt, tz.local);
    
    DateTimeComponents? matchComponents;
    if (r.repeatType == ReminderModel.repeatDaily) {
      matchComponents = DateTimeComponents.time;
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
    } else if (r.repeatType == ReminderModel.repeatWeekly) {
      matchComponents = DateTimeComponents.dayOfWeekAndTime;
      while (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        scheduledDate = scheduledDate.add(const Duration(days: 7));
      }
    } else if (r.repeatType == ReminderModel.repeatMonthly) {
      matchComponents = DateTimeComponents.dayOfMonthAndTime;
      while (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        scheduledDate = tz.TZDateTime(tz.local, scheduledDate.year, scheduledDate.month + 1, scheduledDate.day, scheduledDate.hour, scheduledDate.minute);
      }
    } else {
      // None
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;
    }

    try {
      await FCMService.localNotifications.zonedSchedule(
        id: r.id.hashCode,
        title: r.title,
        body: 'Time for your reminder 💕',
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('us_app_channel', 'Us App Notifications'),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: matchComponents,
      );
    } catch (e) {
      // Ignore scheduling errors on some devices
    }
  }

  List<ReminderModel> get todaysReminders {
    final now = DateTime.now();
    return (state.valueOrNull ?? []).where((r) {
      return r.remindAt.year == now.year &&
          r.remindAt.month == now.month &&
          r.remindAt.day == now.day;
    }).toList();
  }

  List<ReminderModel> get upcomingReminders {
    final now = DateTime.now();
    final nextWeek = now.add(const Duration(days: 7));
    return (state.valueOrNull ?? []).where((r) {
      return r.remindAt.isAfter(now) && r.remindAt.isBefore(nextWeek);
    }).toList();
  }
  
  List<ReminderModel> get laterReminders {
    final nextWeek = DateTime.now().add(const Duration(days: 7));
    return (state.valueOrNull ?? []).where((r) {
      return r.remindAt.isAfter(nextWeek) || r.repeatType != ReminderModel.repeatNone;
    }).toList();
  }
}

final remindersProvider = AsyncNotifierProvider<RemindersNotifier, List<ReminderModel>>(() {
  return RemindersNotifier();
});
