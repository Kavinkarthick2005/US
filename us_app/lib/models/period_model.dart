class PeriodCycleModel {
  final String id;
  final String userId;
  final DateTime startDate;
  final DateTime? endDate;
  final int cycleLength;
  final DateTime createdAt;

  PeriodCycleModel({
    required this.id,
    required this.userId,
    required this.startDate,
    this.endDate,
    required this.cycleLength,
    required this.createdAt,
  });

  factory PeriodCycleModel.fromJson(Map<String, dynamic> json) => PeriodCycleModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        startDate: DateTime.parse(json['start_date'] as String).toLocal(),
        endDate: json['end_date'] != null
            ? DateTime.parse(json['end_date'] as String).toLocal()
            : null,
        cycleLength: (json['cycle_length'] as num?)?.toInt() ?? 28,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}
