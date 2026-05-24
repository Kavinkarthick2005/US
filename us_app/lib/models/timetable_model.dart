import 'package:flutter/material.dart';

class TimetableModel {
  final String id;
  final String userId;
  final int    dayOfWeek; // 0=Mon … 6=Sun
  final int    startHour;
  final int    startMin;
  final int    endHour;
  final int    endMin;
  final String label;
  final bool   isFree;

  TimetableModel({
    required this.id,
    required this.userId,
    required this.dayOfWeek,
    required this.startHour,
    required this.startMin,
    required this.endHour,
    required this.endMin,
    required this.label,
    required this.isFree,
  });

  TimeOfDay get startTimeOfDay =>
      TimeOfDay(hour: startHour, minute: startMin);

  TimeOfDay get endTimeOfDay =>
      TimeOfDay(hour: endHour, minute: endMin);

  factory TimetableModel.fromJson(Map<String, dynamic> j) => TimetableModel(
        id:        j['id'] as String,
        userId:    j['user_id'] as String,
        dayOfWeek: j['day_of_week'] as int,
        startHour: j['start_hour'] as int,
        startMin:  j['start_min'] as int,
        endHour:   j['end_hour'] as int,
        endMin:    j['end_min'] as int,
        label:     j['label'] as String,
        isFree:    j['is_free'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id':          id,
        'user_id':     userId,
        'day_of_week': dayOfWeek,
        'start_hour':  startHour,
        'start_min':   startMin,
        'end_hour':    endHour,
        'end_min':     endMin,
        'label':       label,
        'is_free':     isFree,
      };
}
