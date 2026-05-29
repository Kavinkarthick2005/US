import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'couple_provider.dart';

class LocationState {
  final bool isSharing;
  final DateTime? expiresAt;
  final String activeMessage;
  final String shareType;
  final double? destinationLat;
  final double? destinationLng;

  final bool partnerSharing;
  final double? partnerLat;
  final double? partnerLng;
  final String partnerMessage;
  final String partnerShareType;
  final int? partnerEtaMinutes;
  final DateTime? partnerExpiresAt;
  final bool partnerArrived; // true if is_active=false but arrival_acknowledged=false

  LocationState({
    this.isSharing = false,
    this.expiresAt,
    this.activeMessage = '',
    this.shareType = 'custom',
    this.destinationLat,
    this.destinationLng,
    this.partnerSharing = false,
    this.partnerLat,
    this.partnerLng,
    this.partnerMessage = '',
    this.partnerShareType = 'custom',
    this.partnerEtaMinutes,
    this.partnerExpiresAt,
    this.partnerArrived = false,
  });

  LocationState copyWith({
    bool? isSharing,
    DateTime? expiresAt,
    String? activeMessage,
    String? shareType,
    double? destinationLat,
    double? destinationLng,
    bool? partnerSharing,
    double? partnerLat,
    double? partnerLng,
    String? partnerMessage,
    String? partnerShareType,
    int? partnerEtaMinutes,
    DateTime? partnerExpiresAt,
    bool? partnerArrived,
  }) {
    return LocationState(
      isSharing: isSharing ?? this.isSharing,
      expiresAt: expiresAt ?? this.expiresAt,
      activeMessage: activeMessage ?? this.activeMessage,
      shareType: shareType ?? this.shareType,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      partnerSharing: partnerSharing ?? this.partnerSharing,
      partnerLat: partnerLat ?? this.partnerLat,
      partnerLng: partnerLng ?? this.partnerLng,
      partnerMessage: partnerMessage ?? this.partnerMessage,
      partnerShareType: partnerShareType ?? this.partnerShareType,
      partnerEtaMinutes: partnerEtaMinutes ?? this.partnerEtaMinutes,
      partnerExpiresAt: partnerExpiresAt ?? this.partnerExpiresAt,
      partnerArrived: partnerArrived ?? this.partnerArrived,
    );
  }
}

class LocationNotifier extends StateNotifier<LocationState> {
  final Ref ref;
  StreamSubscription<Position>? _positionStream;
  RealtimeChannel? _partnerChannel;
  Timer? _expiryTimer;
  String? _myShareId;
  String? _partnerShareId;

  LocationNotifier(this.ref) : super(LocationState()) {
    _initPartnerListener();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _partnerChannel?.unsubscribe();
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _initPartnerListener() async {
    final couple = ref.read(coupleProvider).valueOrNull;
    final myId = couple?.currentUser?.id;
    if (myId == null) return;

    // Fetch initial active share for me
    _fetchPartnerLocation();

    // Subscribe to changes where I am the shared_with user
    _partnerChannel = Supabase.instance.client
        .channel('public:location_shares')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'location_shares',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shared_with',
            value: myId,
          ),
          callback: (payload) {
            _fetchPartnerLocation();
          },
        )
        .subscribe();
  }

  Future<void> _fetchPartnerLocation() async {
    final couple = ref.read(coupleProvider).valueOrNull;
    final myId = couple?.currentUser?.id;
    if (myId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('location_shares')
          .select()
          .eq('shared_with', myId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        final isActive = response['is_active'] as bool;
        final acknowledged = response['arrival_acknowledged'] as bool? ?? true;
        final expiresAt = DateTime.parse(response['expires_at']).toLocal();

        if (isActive && expiresAt.isAfter(DateTime.now())) {
          _partnerShareId = response['id'];
          state = state.copyWith(
            partnerSharing: true,
            partnerArrived: false,
            partnerLat: response['last_lat'] != null ? (response['last_lat'] as num).toDouble() : null,
            partnerLng: response['last_lng'] != null ? (response['last_lng'] as num).toDouble() : null,
            partnerMessage: response['message'] as String? ?? 'On my way 💕',
            partnerShareType: response['share_type'] as String? ?? 'custom',
            partnerEtaMinutes: response['eta_minutes'] as int?,
            partnerExpiresAt: expiresAt,
          );
        } else if (!isActive && !acknowledged) {
          // Partner arrived but not yet acknowledged
          _partnerShareId = response['id'];
          state = state.copyWith(
            partnerSharing: false,
            partnerArrived: true,
            partnerMessage: response['message'] as String? ?? 'On my way 💕',
          );
        } else {
          // Shared ended and acknowledged
          state = state.copyWith(partnerSharing: false, partnerArrived: false);
        }
      } else {
        state = state.copyWith(partnerSharing: false, partnerArrived: false);
      }
    } catch (_) {}
  }

  Future<void> acknowledgeArrival() async {
    if (_partnerShareId != null) {
      try {
        await Supabase.instance.client
            .from('location_shares')
            .update({'arrival_acknowledged': true})
            .eq('id', _partnerShareId!);
        state = state.copyWith(partnerArrived: false);
      } catch (_) {}
    }
  }

  Future<void> startSharing({
    required int durationMinutes,
    required String message,
    required String shareType,
    double? destLat,
    double? destLng,
  }) async {
    final couple = ref.read(coupleProvider).valueOrNull;
    final myId = couple?.currentUser?.id;
    final partnerId = couple?.partner?.id;
    if (myId == null || partnerId == null) return;

    // Check permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return; // Request user to enable services

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    // Get current location
    Position currentPos = await Geolocator.getCurrentPosition();

    // Calculate initial ETA if destination exists
    int? initialEta;
    if (destLat != null && destLng != null) {
      initialEta = _calculateEtaMinutes(currentPos.latitude, currentPos.longitude, destLat, destLng);
    }

    final expiresAt = DateTime.now().add(Duration(minutes: durationMinutes));

    // Insert into Supabase
    try {
      final response = await Supabase.instance.client.from('location_shares').insert({
        'shared_by': myId,
        'shared_with': partnerId,
        'last_lat': currentPos.latitude,
        'last_lng': currentPos.longitude,
        'destination_lat': destLat,
        'destination_lng': destLng,
        'message': message,
        'share_type': shareType,
        'eta_minutes': initialEta,
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'is_active': true,
        'arrival_acknowledged': false,
      }).select().single();

      _myShareId = response['id'];

      state = state.copyWith(
        isSharing: true,
        expiresAt: expiresAt,
        activeMessage: message,
        shareType: shareType,
        destinationLat: destLat,
        destinationLng: destLng,
      );

      _startPositionStream();
      _startExpiryTimer();

      // TODO: Send FCM Notification (implemented via Edge Functions or local notification plugin)
    } catch (_) {}
  }

  void _startPositionStream() {
    _positionStream?.cancel();
    // Update every 100 meters
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      ),
    ).listen((Position position) async {
      if (_myShareId == null) return;

      int? newEta;
      if (state.destinationLat != null && state.destinationLng != null) {
        double distMeters = Geolocator.distanceBetween(
          position.latitude, position.longitude,
          state.destinationLat!, state.destinationLng!,
        );

        if (distMeters < 200) {
          // Arrived!
          await stopSharing(arrived: true);
          return;
        }

        newEta = _calculateEtaMinutes(
          position.latitude, position.longitude,
          state.destinationLat!, state.destinationLng!,
        );
      }

      try {
        await Supabase.instance.client.from('location_shares').update({
          'last_lat': position.latitude,
          'last_lng': position.longitude,
          'eta_minutes': newEta,
        }).eq('id', _myShareId!);
      } catch (_) {}
    });
  }

  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (state.expiresAt != null && DateTime.now().isAfter(state.expiresAt!)) {
        stopSharing();
      }
    });
  }

  Future<void> stopSharing({bool arrived = false}) async {
    _positionStream?.cancel();
    _expiryTimer?.cancel();

    if (_myShareId != null) {
      try {
        await Supabase.instance.client.from('location_shares').update({
          'is_active': false,
          'arrival_acknowledged': arrived ? false : true, // If arrived, wait for partner to acknowledge
        }).eq('id', _myShareId!);
      } catch (_) {}
    }

    _myShareId = null;
    state = state.copyWith(
      isSharing: false,
      expiresAt: null,
      destinationLat: null,
      destinationLng: null,
    );
  }

  int _calculateEtaMinutes(double lat1, double lon1, double lat2, double lon2) {
    double dist = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    // Assume 40 km/h = ~666 meters per minute
    int minutes = (dist / 666).round();
    return minutes < 1 ? 1 : minutes; // Minimum 1 minute
  }
}

final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier(ref);
});
