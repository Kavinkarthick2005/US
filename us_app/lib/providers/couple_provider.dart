import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class UserModel {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final String? coupleCode;
  final String? partnerId;
  final String? coupleId;
  final String? fcmToken;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl,
    this.coupleCode,
    this.partnerId,
    this.coupleId,
    this.fcmToken,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      coupleCode: json['couple_code'] as String?,
      partnerId: json['partner_id'] as String?,
      coupleId: json['couple_id'] as String?,
      fcmToken: json['fcm_token'] as String?,
    );
  }
}

class CoupleState {
  final UserModel? currentUser;
  final UserModel? partner;

  CoupleState({this.currentUser, this.partner});

  bool get isLinked => currentUser?.partnerId != null && partner != null;
  String? get coupleId => currentUser?.coupleId;
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

class CoupleNotifier extends AsyncNotifier<CoupleState> {
  final _supabase = Supabase.instance.client;
  StreamSubscription? _profileSubscription;

  @override
  FutureOr<CoupleState> build() async {
    // Initial fetch
    final user = _supabase.auth.currentUser;
    if (user == null) return CoupleState();

    // Listen to profile changes in real-time
    _subscribeToProfile(user.id);

    final currentUser = await _fetchUser(user.id);
    UserModel? partner;
    if (currentUser?.partnerId != null) {
      partner = await _fetchUser(currentUser!.partnerId!);
    }

    return CoupleState(currentUser: currentUser, partner: partner);
  }

  void _subscribeToProfile(String userId) {
    _profileSubscription?.cancel();
    _profileSubscription = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((data) async {
          if (data.isNotEmpty) {
            final updatedUser = UserModel.fromJson(data.first);
            UserModel? updatedPartner;
            if (updatedUser.partnerId != null) {
              updatedPartner = await _fetchUser(updatedUser.partnerId!);
            }
            state = AsyncData(CoupleState(
              currentUser: updatedUser,
              partner: updatedPartner,
            ));
          }
        });
  }

  Future<UserModel?> _fetchUser(String id) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (data == null) return null;
      return UserModel.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  Future<void> linkPartner(String code) async {
    state = const AsyncLoading();
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) throw Exception('Not authenticated');

      // 1. Query user with this code
      final partnerData = await _supabase
          .from('profiles')
          .select()
          .eq('couple_code', code.toUpperCase())
          .maybeSingle();

      if (partnerData == null) {
        throw Exception('Code not found');
      }

      final partnerUser = UserModel.fromJson(partnerData);
      
      if (partnerUser.id == myId) {
        throw Exception('You cannot link with yourself');
      }

      if (partnerUser.partnerId != null) {
        throw Exception('This user is already linked to someone else');
      }

      final coupleId = const Uuid().v4();

      // 2. Update both users
      await _supabase.from('profiles').update({'partner_id': partnerUser.id, 'couple_id': coupleId}).eq('id', myId);
      await _supabase.from('profiles').update({'partner_id': myId, 'couple_id': coupleId}).eq('id', partnerUser.id);

      // 3. Auto-create default reminders for her
      await _createDefaultReminders(myId, partnerUser.id);

      // 4. Refresh state
      ref.invalidateSelf();
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> unlinkPartner() async {
    state = const AsyncLoading();
    try {
      final myId = _supabase.auth.currentUser?.id;
      final currentPartnerId = state.value?.currentUser?.partnerId;

      if (myId != null) {
        await _supabase.from('profiles').update({'partner_id': null}).eq('id', myId);
      }
      if (currentPartnerId != null) {
        await _supabase.from('profiles').update({'partner_id': null}).eq('id', currentPartnerId);
      }
      
      ref.invalidateSelf();
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> _createDefaultReminders(String myId, String partnerId) async {
    final now = DateTime.now();
    
    // Helper to get today's date at specific hour/minute
    DateTime atTime(int hour, int minute) {
      return DateTime(now.year, now.month, now.day, hour, minute);
    }

    final defaultReminders = [
      {
        'user_id': myId,
        'remind_to': partnerId,
        'title': 'Remind her: eat lunch 🍱',
        'remind_at': atTime(12, 30).toUtc().toIso8601String(),
        'repeat_type': 'daily',
        'category': 'food',
        'is_active': true,
      },
      {
        'user_id': myId,
        'remind_to': partnerId,
        'title': 'Remind her: eat dinner 🍽',
        'remind_at': atTime(19, 30).toUtc().toIso8601String(),
        'repeat_type': 'daily',
        'category': 'food',
        'is_active': true,
      },
      {
        'user_id': myId,
        'remind_to': partnerId,
        'title': 'Drink water 💧',
        'remind_at': atTime(10, 0).toUtc().toIso8601String(),
        'repeat_type': 'daily',
        'category': 'hydration',
        'is_active': true,
      },
      {
        'user_id': myId,
        'remind_to': partnerId,
        'title': 'Drink water 💧',
        'remind_at': atTime(15, 0).toUtc().toIso8601String(),
        'repeat_type': 'daily',
        'category': 'hydration',
        'is_active': true,
      },
    ];

    try {
      await _supabase.from('reminders').insert(defaultReminders);
    } catch (e) {
      // It's ok if this fails, we just won't have default reminders
    }
  }
}

final coupleProvider = AsyncNotifierProvider<CoupleNotifier, CoupleState>(() {
  return CoupleNotifier();
});
